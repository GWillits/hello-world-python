# pylint: skip-file
import os
import contextlib
import json
from typing import Dict, Any
from uuid import uuid4

import pytest

from function import Sns, SlackMessage, sns_is_codepipeline, attach_codepipeline_message

_account_id = "123456789012"


@contextlib.contextmanager
def temp_env_vars(**environ):
    old_environ = dict(os.environ)
    os.environ.update(environ)
    try:
        yield
    finally:
        os.environ.clear()
        os.environ.update(old_environ)


@pytest.fixture(scope="module", autouse=True)
def setup():

    with temp_env_vars(**{"slack_webhook_token": "fake", "account_name": "testing-mesh"}):
        yield


def _as_sns(message: Dict[str, Any]) -> Sns:

    return Sns(Message=json.dumps(message))


def _codepipeline_wrapper(detail, pipeline_name: str = "ci", additional_attributes=None):

    return {
        "account": _account_id,
        "detailType": "CodePipeline Pipeline Execution State Change",
        "region": "eu-west-2",
        "source": "aws.codepipeline",
        "time": "2021-12-30T15:37:08Z",
        "notificationRuleArn": f"arn:aws:codestar-notifications:eu-west-2:{_account_id}:notificationrule/{uuid4().hex}",
        "detail": detail,
        "resources": [f"arn:aws:codepipeline:eu-west-2:{_account_id}:{pipeline_name}"],
        "additionalAttributes": additional_attributes or {},
    }


def _base_slack_message():
    return SlackMessage(
        channel="#23442343",
        username="AWS SNS via Lambda",
        icon_emoji=":rick-whoah:",
    )


def test_recognise_codestar_pipeline_started_notification():

    message = _codepipeline_wrapper(
        {
            "pipeline": uuid4().hex,
            "execution-id": str(uuid4()),
            "execution-trigger": {
                "trigger-type": "Webhook",
                "trigger-detail": f"arn:aws:codestar-connections:eu-west-2:{_account_id}:connection/{uuid4()}",
            },
            "state": "STARTED",
            "version": 8.0,
        }
    )
    sns = _as_sns(message)
    assert sns_is_codepipeline(sns)
    slack_message = attach_codepipeline_message(_base_slack_message(), sns)
    assert len(slack_message["attachments"]) == 1
    attachment = slack_message["attachments"][0]
    assert attachment["color"] == "good"
    has_at_here = "@here " in attachment["text"]
    data_lines = attachment["text"].split("\n")
    assert not has_at_here
    pipeline_name = message["detail"]["pipeline"]
    execution_id = message["detail"]["execution-id"]
    aws_base_url = f"https://eu-west-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/{pipeline_name}"
    assert attachment["title_link"] == f"{aws_base_url}/view?region=eu-west-2"
    assert (
        f"*pipeline:* <{aws_base_url}/view?region=eu-west-2|{pipeline_name}> *execution_id:* <{aws_base_url}/executions/{execution_id}/visualization?region=eu-west-2|{execution_id}>"
        in data_lines
    )


def test_codepipeline_manual_approval():

    message = _codepipeline_wrapper(
        {
            "pipeline": uuid4().hex,
            "execution-id": str(uuid4()),
            "stage": "terraform-account",
            "action": "approve-terraform-plan",
            "state": "STARTED",
            "region": "eu-west-2",
            "type": {"owner": "AWS", "provider": "Manual", "category": "Approval", "version": "1"},
            "version": 8.0,
        },
        additional_attributes={"externalEntityLink": "http://example.com", "customData": ""},
    )

    sns = _as_sns(message)
    assert sns_is_codepipeline(sns)
    slack_message = attach_codepipeline_message(_base_slack_message(), sns)
    assert len(slack_message["attachments"]) == 1
    attachment = slack_message["attachments"][0]
    assert attachment["color"] == "good"
    has_at_here = "@here " in attachment["text"]
    data_lines = attachment["text"].split("\n")
    assert not has_at_here
    pipeline_name = message["detail"]["pipeline"]
    execution_id = message["detail"]["execution-id"]
    aws_base_url = f"https://eu-west-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/{pipeline_name}"
    assert attachment["title_link"] == f"{aws_base_url}/view?region=eu-west-2"
    assert (
        f"*pipeline:* <{aws_base_url}/view?region=eu-west-2|{pipeline_name}> *execution_id:* <{aws_base_url}/executions/{execution_id}/visualization?region=eu-west-2|{execution_id}>"
        in data_lines
    )
