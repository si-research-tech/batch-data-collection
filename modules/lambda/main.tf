variable "project" {}
variable "lambda" {}
variable "api_gateway_id" {}

data "aws_iam_role" "lambda_execution_role" {
  name  = "lambda_execution_role"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.root}/source/${var.lambda.name}"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_lambda_function" "function" {
  filename          = "${path.module}/lambda_function_payload.zip"
  function_name     = var.lambda.name
  role              = data.aws_iam_role.lambda_execution_role.arn
  handler           = var.lambda.entrypoint
  runtime           = var.lambda.runtime
  source_code_hash  = data.archive_file.lambda.output_base64sha256

  environment {
    variables = var.lambda.variables
  }
}