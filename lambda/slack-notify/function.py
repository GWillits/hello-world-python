#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import logging
import os

from urllib.error import HTTPError, URLError
from urllib.request import urlopen, Request

import boto3


# Typing
class Json(dict):
    pass


class Sns(dict):
    pass


class SlackMessage(dict):
    pass


_SSM_CLIENT = None


def get_parameter(key):
    global _SSM_CLIENT  # pylint: disable=W0603
    if _SSM_CLIENT is None:
        _SSM_CLIENT = boto3.client("ssm")
    resp = _SSM_CLIENT.get_parameter(Name=key, WithDecryption=True)
    return resp["Parameter"]["Value"]


logger = logging.getLogger()
logger.setLevel(logging.INFO)

_HOOK_URL = None


def get_hook_url() -> str:
    global _HOOK_URL  # pylint: disable=W0603
    if _HOOK_URL is None:
        _HOOK_URL = os.path.join("https://hooks.slack.com/services", get_parameter(os.environ["slack_webhook_token"]))
    return _HOOK_URL


def handler(event: Json, _context):
    logger.info("Event: %s", event)

    for record in event["Records"]:
        sns = record["Sns"]
        slack_message_template = slack_message_skeleton(sns)

        if suppress_alert(sns) or slack_message_template["channel"] is None:
            continue

        slack_message = convert_to_slack_message(sns, slack_message_template)
        logger.info("Slack message: %s", slack_message)
        req = Request(get_hook_url(), json.dumps(slack_message).encode("utf-8"))

        try:
            with urlopen(req) as resp:
                resp.read()
            logger.info("Message posted to %s", slack_message["channel"])
        except HTTPError as error:
            logger.error("Request failed: %d %s", error.code, error.reason)
        except URLError as error:
            logger.error("Server connection failed: %s", error.reason)


def suppress_alert(sns: Sns) -> bool:
    try:
        message = json.loads(sns["Message"])
        if message.get("status") == "resolved":
            if message.get("commonLabels", {}).get("show_resolved", "").lower() in [
                "no",
                "false",
                "0",
            ]:
                return True
    except json.JSONDecodeError:
        pass
    return False


def convert_to_slack_message(sns: Sns, slack_message: SlackMessage) -> SlackMessage:
    try:

        add_slack_subject(slack_message, sns)

        if sns_is_alarm(sns):
            attach_alarm_message(slack_message, sns)
            return slack_message

        if sns_is_alert(sns):
            attach_alertmanager_message(slack_message, sns)
            return slack_message

        if sns_is_codepipeline(sns):
            attach_codepipeline_message(slack_message, sns)
            return slack_message

        attach_message(slack_message, sns)
        return slack_message

    except:  # pylint: disable=bare-except
        logging.exception("Fatal error:")
        return fatal_error_message(sns)


def slack_message_skeleton(sns: Sns) -> SlackMessage:
    slack_message = SlackMessage(
        channel=slack_channel(sns),
        username="AWS SNS via Lambda",
        icon_emoji=os.environ["icon"],
    )
    return slack_message


def slack_channel(sns: Sns) -> str:
    """
    Matches channel in alert log to terraform. If no value defaults to default.
    Args:
        sns (dict): The alert message

    Returns (str): The channel to send the message to

    """
    message = json.loads(sns["Message"]).get("commonLabels", {})
    channels = json.loads(os.environ["slack_alerts_channels"])

    try:
        channel = channels[message.get("channel", "default")]  # type: str
        return channel
    except KeyError:
        logging.exception("Invalid Channel, check channel in alert matches one in terraform vars.")
        raise


def add_slack_subject(slack_message: SlackMessage, sns: Sns):
    if "Subject" in sns and sns["Subject"]:
        slack_message["text"] = f"*{sns['Subject']}*"


def sns_is_alarm(sns: Sns) -> bool:
    try:
        message = json.loads(sns["Message"])
        return "AlarmName" in message
    except json.JSONDecodeError:
        return False


def attach_alarm_message(slack_message: SlackMessage, sns: Sns):

    message = json.loads(sns["Message"])

    alarm = message["AlarmName"]

    if alarm == "ALARM":
        attachment_color = "danger"
    elif alarm == "OK":
        attachment_color = "good"
    else:
        attachment_color = "warning"

    attachment_text = "*AWSAccount:* " + os.environ["account_name"] + "\n"
    attachment_text += "*AlarmName:* " + (message["AlarmName"] or "") + "\n"
    attachment_text += "*Description:* " + (message.get("AlarmDescription") or "") + "\n"
    attachment_text += (
        "*State:* " + (message.get("OldStateValue") or "") + " -> " + (message.get("NewStateValue") or "") + "\n"
    )
    attachment_text += "*Reason:* " + (message.get("NewStateReason") or "") + "\n"
    attachment_text += "*Detected at:* " + (message.get("StateChangeTime") or "") + "\n"

    if "attachments" not in slack_message:
        slack_message["attachments"] = []
    slack_message["attachments"].append({"color": attachment_color, "text": attachment_text})


def sns_is_alert(sns: Sns) -> bool:
    try:
        message = json.loads(sns["Message"])
        is_sns_alert = message.get("receiver") == "sns-forwarder"  # type: bool
        return is_sns_alert
    except json.JSONDecodeError:
        return False


def attach_alertmanager_message(slack_message: SlackMessage, sns: Sns):

    if "text" not in slack_message:
        slack_message["text"] = "Alertmanager via SNS forwarder"

    message = json.loads(sns["Message"])
    status = message.get("status")
    attachments = []
    for alert in message["alerts"]:
        attachment = {}

        severity = alert["labels"].get("severity")
        if status == "resolved" or severity in ["ok"]:
            attachment["color"] = "good"
        elif severity in ["critical", "error"]:
            attachment["color"] = "danger"
        elif severity in ["warning"]:
            attachment["color"] = "warning"
        elif severity in ["info"]:
            attachment["color"] = "#40b0f0"
        else:
            attachment["color"] = "#c0c0c0"

        if "summary" in alert.get("annotations", {}):
            attachment["pretext"] = f"*{alert['annotations']['summary'].title()}*"
        elif "alertname" in alert["labels"]:
            attachment["pretext"] = f"*{alert['labels']['alertname'].title()}*"

        attachment["text"] = ""
        if "status" in message:
            attachment["text"] += f"*Status: {message['status']}*\n"
        attachment["text"] += "*Labels:*\n"
        for name, value in alert["labels"].items():
            attachment["text"] += f"    - {name}: {value}\n"
        for name, value in alert.get("annotations", {}).items():
            attachment["text"] += f"*{name.title()}:* {value}\n"
        attachment["text"] += f"*Detected at:* {alert['startsAt']}\n"

        attachments.append(attachment)

    if "attachments" not in slack_message:
        slack_message["attachments"] = []
    slack_message["attachments"].extend(attachments)


def sns_is_codepipeline(sns: Sns) -> bool:
    try:
        message = json.loads(sns["Message"])
        return bool(message.get("source", "") == "aws.codepipeline")
    except json.JSONDecodeError:
        return False


# https://docs.aws.amazon.com/dtconsole/latest/userguide/concepts.html#detail-type
# pylint: disable=R0914
def attach_codepipeline_message(slack_message: SlackMessage, sns: Sns):

    if "attachments" not in slack_message:
        slack_message["attachments"] = []

    message = json.loads(sns["Message"])

    detail = message.get("detail", {})
    region = message.get("region", "eu-west-2")

    pipeline_name = detail.get("pipeline")
    execution_id = detail.get("execution-id")

    aws_base_url = f"https://{region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/{pipeline_name}"

    lines = [
        # this is a single line, ( just to keep pylint happy )
        f"*pipeline:* <{aws_base_url}/view?region={region}|{pipeline_name}>"
        f" *execution_id:* <{aws_base_url}/executions/{execution_id}/visualization?region=eu-west-2|{execution_id}>",
    ]
    state = detail.get("state")
    action = detail.get("action")
    if not action:
        lines.append(f"*state:* {state}")

    stage = detail.get("stage")
    if stage:
        lines.append(f"*stage:* {stage}")

    if action:
        action_type = detail.get("type", {})
        provider = action_type.get("provider")
        category = action_type.get("category")
        lines.append(f"*action:* {provider} {category} {action}")

    additional = message.get("additionalAttributes", {})
    if additional:
        for key, value in additional.items():
            lines.append(f"*{key}:* {value}")

    attachment_color = "warning"
    if state == "STARTED":
        attachment_color = "good"

    if state == "SUCCEEDED":
        attachment_color = "good"
        slack_message["icon_emoji"] = ":shipitparrot:"

    if state == "FAILED":
        slack_message["icon_emoji"] = ":facepalm:"
        attachment_color = "danger"

    # https://api.slack.com/reference/messaging/attachments
    slack_message["attachments"].append(
        {
            "mrkdwn_in": ["text"],
            "title": f"codepipeline:  {os.environ['account_name']} - {pipeline_name}",
            "title_link": f"{aws_base_url}/view?region={region}",
            "color": attachment_color,
            "text": "\n".join(lines),
        }
    )
    return slack_message


def attach_message(slack_message: SlackMessage, sns: Sns):
    """Last resort: attach a message as is"""
    if "attachments" not in slack_message:
        slack_message["attachments"] = []
    slack_message["attachments"].append(
        {
            "color": "warning",
            "pretext": "*Message format not recognised*",
            "text": sns["Message"],
        }
    )


def fatal_error_message(sns) -> SlackMessage:
    slack_message = SlackMessage(
        channel=slack_channel(sns),
        username="AWS SNS via Lambda",
        icon_emoji=":warning:",
        text="Fatal error while processing alert",
    )
    return slack_message
