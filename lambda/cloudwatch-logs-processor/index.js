/*
For processing data sent to Firehose by Cloudwatch Logs subscription filters.

Cloudwatch Logs sends to Firehose records that look like this:

{
  "messageType": "DATA_MESSAGE",
  "owner": "123456789012",
  "logGroup": "log_group_name",
  "logStream": "log_stream_name",
  "subscriptionFilters": [
    "subscription_filter_name"
  ],
  "logEvents": [
    {
      "id": "01234567890123456789012345678901234567890123456789012345",
      "timestamp": 1510109208016,
      "message": "log message 1"
    },
    {
      "id": "01234567890123456789012345678901234567890123456789012345",
      "timestamp": 1510109208017,
      "message": "log message 2"
    }
    ...
  ]
}

The data is additionally compressed with GZIP.

The code below will:

1) Gunzip the data
2) Parse the json
3) Set the result to ProcessingFailed for any record whose messageType is not DATA_MESSAGE, thus redirecting them to the
   processing error output. Such records do not contain any log events. You can modify the code to set the result to
   Dropped instead to get rid of these records completely.
4) For records whose messageType is DATA_MESSAGE, extract the individual log events from the logEvents field, and pass
   each one to the transformLogEvent method. You can modify the transformLogEvent method to perform custom
   transformations on the log events.
5) Concatenate the result from (4) together and set the result as the data of the record returned to Firehose. Note that
   this step will not add any delimiters. Delimiters should be appended by the logic within the transformLogEvent
   method.
6) Any additional records which exceed 6MB will be re-ingested back into Firehose.
*/
const zlib = require('zlib');
const AWS = require('aws-sdk');

/**
 * logEvent has this format:
 *
 * {
 *   "id": "01234567890123456789012345678901234567890123456789012345",
 *   "timestamp": 1510109208016,
 *   "message": "log message 1"
 * }
 *
 * The result must be returned in a Promise.
 */

const defaultIndex = process.env.DEFAULT_INDEX;
const allowedIndexes = (process.env.ALLOWED_INDEXES || defaultIndex).split(',');
const sourcetype = process.env.SOURCETYPE;

function maybeParseEvent(message) {
    try {
        return {event: JSON.parse(message), st: `${sourcetype}:json`};
    }
    catch (e) { }
    return {event: message, st: `${sourcetype}:raw`};
}

function transformLogEvent(logEvent, logGroup, subscriptionFilters) {
    const {event, st} = maybeParseEvent(logEvent.message);

    let index = null;

    if (subscriptionFilters && subscriptionFilters.length > 0) {
        index = subscriptionFilters[0].split('-');
        index = index[index.length - 1];
        if (!allowedIndexes.includes(index)) {
            index = null;
        }
    }

    index = index || defaultIndex;

    return Promise.resolve(JSON.stringify({
        time: logEvent.timestamp,
        index: index,
        source: logGroup,
        sourcetype: st,
        event: event
    }));
}

function putRecordsToFirehoseStream(streamName, records, client, resolve, reject, attemptsMade, maxAttempts) {
    client.putRecordBatch({
        DeliveryStreamName: streamName,
        Records: records,
    }, (err, data) => {
        const codes = [];
        let failed = [];
        let errMsg = err;

        if (err) {
            failed = records;
        } else {
            for (let i = 0; i < data.RequestResponses.length; i++) {
                const code = data.RequestResponses[i].ErrorCode;
                if (code) {
                    codes.push(code);
                    failed.push(records[i]);
                }
            }
            errMsg = `Individual error codes: ${codes}`;
        }

        if (failed.length > 0) {
            if (attemptsMade + 1 < maxAttempts) {
                console.log('Some records failed while calling PutRecordBatch, retrying. %s', errMsg);
                putRecordsToFirehoseStream(streamName, failed, client, resolve, reject, attemptsMade + 1, maxAttempts);
            } else {
                reject(`Could not put records after ${maxAttempts} attempts. ${errMsg}`);
            }
        } else {
            resolve('');
        }
    });
}

exports.handler = (event, _, callback) => {
    Promise.all(event.records.map(r => {
        const buffer = Buffer.from(r.data, 'base64');

        let decompressed;
        try {
            decompressed = zlib.gunzipSync(buffer);
        } catch (e) {
            return Promise.resolve({
                recordId: r.recordId,
                result: 'ProcessingFailed',
            });
        }

        const data = JSON.parse(decompressed);
        // CONTROL_MESSAGE are sent by CWL to check if the subscription is reachable.
        // They do not contain actual data.
        if (data.messageType === 'CONTROL_MESSAGE') {
            return Promise.resolve({
                recordId: r.recordId,
                result: 'Dropped',
            });
        }

        if (data.messageType === 'DATA_MESSAGE') {
            const promises = data.logEvents.map(
                function(x) {
                    return transformLogEvent(x, data.logGroup, data.subscriptionFilters);
                }
            );
            return Promise.all(promises)
                .then(transformed => {
                    const payload = transformed.reduce((a, v) => a + v, '');
                    const encoded = Buffer.from(payload).toString('base64');
                    return {
                        recordId: r.recordId,
                        result: 'Ok',
                        data: encoded,
                    };
                });
        }

        return Promise.resolve({
            recordId: r.recordId,
            result: 'ProcessingFailed',
        });

    })).then(recs => {
        const streamARN = event.deliveryStreamArn;
        const region = streamARN.split(':')[3];
        const streamName = streamARN.split('/')[1];
        const result = { records: recs };
        let recordsToReingest = [];
        const putRecordBatches = [];
        let totalRecordsToBeReingested = 0;
        const inputDataByRecId = {};
        event.records.forEach(r => inputDataByRecId[r.recordId] = {
            Data: Buffer.from(r.data, 'base64'),
        });

        let projectedSize = recs.filter(rec => rec.result === 'Ok')
            .map(r => r.recordId.length + r.data.length)
            .reduce((a, b) => a + b, 0);
        // 6000000 instead of 6291456 to leave ample headroom for the stuff we didn't account for
        for (let idx = 0; idx < event.records.length && projectedSize > 6000000; idx++) {
            const rec = result.records[idx];
            if (rec.result === 'Ok') {
                totalRecordsToBeReingested++;
                recordsToReingest.push({
                    Data: inputDataByRecId[rec.recordId].Data,
                });
                projectedSize -= rec.data.length;
                delete rec.data;
                result.records[idx].result = 'Dropped';

                // split out the record batches into multiple groups, 500 records at max per group
                if (recordsToReingest.length === 500) {
                    putRecordBatches.push(recordsToReingest);
                    recordsToReingest = [];
                }
            }
        }

        if (recordsToReingest.length > 0) {
            // add the last batch
            putRecordBatches.push(recordsToReingest);
        }

        if (putRecordBatches.length > 0) {
            new Promise((resolve, reject) => {
                let recordsReingestedSoFar = 0;
                for (let idx = 0; idx < putRecordBatches.length; idx++) {
                    const recordBatch = putRecordBatches[idx];
                    const client = new AWS.Firehose({ region: region });
                    putRecordsToFirehoseStream(streamName, recordBatch, client, resolve, reject, 0, 20);
                    recordsReingestedSoFar += recordBatch.length;
                    console.log('Reingested %s/%s records out of %s in to %s stream', recordsReingestedSoFar, totalRecordsToBeReingested, event.records.length, streamName);
                }
            }).then(
                () => {
                    console.log('Reingested all %s records out of %s in to %s stream', totalRecordsToBeReingested, event.records.length, streamName);
                    callback(null, result);
                },
                failed => {
                    console.log('Failed to reingest records. %s', failed);
                    callback(failed, null);
                });
        } else {
            console.log('No records needed to be reingested.');
            callback(null, result);
        }
    }).catch(ex => {
        console.log('Error: ', ex);
        callback(ex, null);
    });
};