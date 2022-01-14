terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {

  profile = "default"
  region  = "eu-west-2"
  assume_role {
    # The role ARN within Account B to AssumeRole into. Created in step 1.
    role_arn = "arn:aws:iam::252613286755:role/devopsgw"
  }
}

data "aws_ssm_parameter" "snyk_key" {
  name = "snyk_key"
}

data "aws_ssm_parameter" "snyk_client_id" {
  name = "snyk_client_id"
}

resource "aws_codestarconnections_connection" "github" {
  name          = "github"
  provider_type = "GitHub"

  lifecycle {
    ignore_changes = [
      connection_status
    ]
  }
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "test-bucket-gw-test-york"
  acl    = "private"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "test-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "codepipeline.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
    }
    EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObjectAcl",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codestar-connections:UseConnection"
      ],
      "Resource": "${aws_codestarconnections_connection.github.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codepipeline" "ci" {
  name     = "tf-test-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      run_order        = 1
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        "Branch"               = "master"
        "Owner"                = "GWillits"
        "PollForSourceChanges" = "true"
        "Repo"                 = "hello-world-python"
        "OAuthToken"           = "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"
      }
    }
  }
  stage {
    name = "scan"

    action {
      name             = "snyk-scan"
      category         = "Invoke"
      owner            = "ThirdParty"
      provider         = "Snyk"
      namespace        = "scan"
      input_artifacts  = ["source_output"]
      output_artifacts = ["snyk_account"]
      version          = "1"
      run_order        = 1
      configuration = {
        ClientId    = data.aws_ssm_parameter.snyk_client_id.value
        ClientToken = data.aws_ssm_parameter.snyk_key.value
      }
    }

  }
}

