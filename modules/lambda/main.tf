variable "project" {}
variable "lambda" {}
variable "api_gateway_id" {}

###############################################################################
# Lambda Execution Role                                                BEGIN  #
#                                                                             #
#  Role assumed by lambda functions created by this module                    #
###############################################################################

data "aws_iam_policy_document" "lambda-assumption" {
  statement {
    sid     = "LambdaExecutionAssumptioonPolicy"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda-job" {
  name        = "${var.project}_lambda-execution"
  path        = "/${var.project}/lambda/"
  description = "IAM execution role for AWS Lambda"

  assume_role_policy    = data.aws_iam_policy_document.lambda-assumption.json
  force_detach_policies = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "lambda-execution" {
  role       = aws_iam_role.lambda-job.name
  policy_arn = aws_iam_policy.project-interop.arn
}
###############################################################################
# Lambda Execution Role                                                 END  #
###############################################################################

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.root}/source/${var.lambda.name}"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_lambda_function" "function" {
  filename          = "${path.module}/lambda_function_payload.zip"
  function_name     = var.lambda.name
  role              = aws_iam_role.lambda_execution_role.arn
  handler           = var.lambda.entrypoint
  runtime           = var.lambda.runtime
  source_code_hash  = data.archive_file.lambda.output_base64sha256

  environment {
    variables = var.lambda.variables
  }
}
