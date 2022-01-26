import logging
import boto3

# Typing
class Json(dict):
    pass


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event: Json, _context):
    """This function includes the layer "_layer_boto"

    _layers are included by including a file with that name in the lambda functions folder.

    It can be invoked in localstack with the command:

    aws --endpoint-url=http://localhost:4766 --region=eu-west-2  lambda invoke --function-name="hello_world" /dev/stdout

    """
    logger.info("event passed in: %s", event)

    return boto3.__version__
