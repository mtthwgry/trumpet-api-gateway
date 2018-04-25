# do it all from here??
provider "aws" {
  region     = "${var.region}"
  token      = "${var.role_token}"
  access_key = "${var.role_access_key}"
  secret_key = "${var.role_secret_key}"
}

data "template_file" "swagger" {
  template = "${file("swagger.yaml")}"

  vars {
    aws_account = "${var.aws_account}"
    region      = "${var.region}"
    engineer_name = "${var.engineer_name}"
  }
}

resource "aws_api_gateway_rest_api" "going_faas_api" {
  name        = "${var.engineer_name}'s Going-FaaS API"
  description = "Test API Gateway for Going-Faas demo"
  body        = "${data.template_file.swagger.rendered}"
}

resource "aws_api_gateway_deployment" "stage" {
  rest_api_id = "${aws_api_gateway_rest_api.going_faas_api.id}"
  stage_name  = "${var.stage_name}"

  variables {
    deployed_at = "${timestamp()}"
    stage       = "${var.stage_name}"
  }
}

resource "aws_api_gateway_method_settings" "stage_settings" {
  depends_on = ["aws_api_gateway_deployment.stage"]

  rest_api_id = "${aws_api_gateway_rest_api.going_faas_api.id}"
  stage_name  = "${var.stage_name}"
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_lambda_permission" "trumpet" {
  statement_id  = "APIGateway-AllowExecution-${var.engineer_name}-TrumpetFunction-${var.stage_name}"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${var.aws_account}:function:${var.engineer_name}-TrumpetFunction-${var.stage_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${var.aws_account}:${aws_api_gateway_rest_api.going_faas_api.id}/*/POST/trumpet"
}
