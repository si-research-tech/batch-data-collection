variable project {}
variable components {}

data "aws_region" "current_region" {}
data "aws_caller_identity" "current_identity" {}

###############################################################################
# Project Interop Policy                                               BEGIN  #
#                                                                             #
#  Allow interaction between services in this project                         #
###############################################################################

locals {
  optional_permissions = [
    {
      service = "lambda"
      enabled = var.components.lambda,
      permissions = [
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:InvokeFunction",
        "lambda:InvokeFunctionUrl",
        "lambda:ListFunctions",
        "lambda:ListTags",
        "lambda:TagResource",
        "lambda:UpdateFunctionCode",
      ]
      resources = ["*"]
    },
    {
      service = "rds"
      enabled = var.components.rds,
      permissions = [
        "rds-db:connect"
      ]
      resources = ["arn:aws:rds-db:${data.aws_region.current_region.region}:${data.aws_caller_identity.current_identity.id}:dbuser:*/${var.project}"]
    },
    {
      service = "s3"
      enabled = var.components.s3,
      permissions = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:DeleteBucket",
      ]
      resources = ["*"]
    },
    {
      service     = "sqs"
      enabled     = var.components.sqs,
      permissions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ListQueues",
        "sqs:ListQueueTags",
        "sqs:TagQueue",
        "sqs:DeleteMessage",
      ]
      resources = ["*"]
    },
  ]
}

data "aws_iam_policy_document" "project-interop" {

  statement {
    sid     = "EC2BatchJobExecutionPolicySecretsManager"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EC2BatchJobExecutionPolicyLogs"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EC2BatchJobExecutionPolicyBatch"
    actions = [
      "batch:ListJobs",
      "batch:DescribeJobQueues",
      "batch:DescribeJobs",
      "batch:CancelJob",
      "batch:SubmitJob",
      "batch:TerminateJob"
    ]
    resources = ["*"]
  }
  
  dynamic "statement" {
    for_each = [ for permission in local.optional_permissions : permission if permission.enabled ]
    
    content {
      sid = "ProjectInterop${statement.value.service}"
      actions = statement.value.permissions
      resources = statement.value.resources
    }
  }

}

resource "aws_iam_policy" "project-interop" {
  name   = "${var.project}-project-interop"
  path   = "/${var.project}/"
  policy = data.aws_iam_policy_document.project-interop.json
}
###############################################################################
# Project Interop Policy                                                 END  #
###############################################################################
