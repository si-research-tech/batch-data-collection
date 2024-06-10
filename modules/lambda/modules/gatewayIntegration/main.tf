variable "api_gateway_id" {}
variable "function_definition" {}
variable "invocation_arn" {}

data "aws_apigatewayv2_api" "lambda" {
  api_id = var.api_gateway_id
}

resource "aws_apigatewayv2_integration" "this" {
  api_id              = var.api_gateway_id
  integration_uri     = var.invocation_arn
  integration_type    = "AWS_PROXY"
  integration_method  = "POST"
}

resource "aws_apigatewayv2_route" "lambda_routes" {
  api_id    = var.api_gateway_id
  route_key = "${var.function_definition.endpoint.method} /${var.function_definition.endpoint.route}}"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.function_definition.name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${data.aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}