# do it all from here??
provider "aws" {
  region     = "${var.region}"
  token      = "${var.role_token}"
  access_key = "${var.role_access_key}"
  secret_key = "${var.role_secret_key}"
}

terraform {
  backend "s3" {
    # Configure backend_config file to change - run init as terraform init --backend-config backend_config
  }
}

data "template_file" "swagger" {
  template = "${file("swagger.yaml.tpl")}"

  vars {
    aws_account = "${local.aws_account}"
    region      = "${var.region}"
    host        = "${var.host}"
  }
}

data "aws_caller_identity" "current" {}

# Slightly shorter version of the AWS account number since we use it frequently
locals {
  aws_account = "${data.aws_caller_identity.current.account_id}"
}

resource "aws_api_gateway_rest_api" "faas_api" {
  name        = "FaaS API"
  description = "API for interacting with Outcome Health's serverless architecture (FaaS)"
  body        = "${data.template_file.swagger.rendered}"
}

resource "aws_api_gateway_usage_plan" "geotargeted-assets" {
  depends_on = ["aws_api_gateway_deployment.stage"]
  name       = "geotargeted-assets"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.faas_api.id}"
    stage  = "${var.stage_name}"
  }

  throttle_settings {
    burst_limit = 1000
    rate_limit  = 500
  }
}

resource "aws_api_gateway_api_key" "geotargeted-assets" {
  name = "geotargeted-assets"
}

resource "aws_api_gateway_usage_plan_key" "geotargeted-assets" {
  key_id        = "${aws_api_gateway_api_key.geotargeted-assets.id}"
  key_type      = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.geotargeted-assets.id}"
}

resource "aws_api_gateway_usage_plan" "enginerds" {
  depends_on = ["aws_api_gateway_deployment.stage"]
  name       = "enginerds"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.faas_api.id}"
    stage  = "${var.stage_name}"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}

resource "aws_api_gateway_api_key" "enginerds" {
  name = "enginerds"
}

resource "aws_api_gateway_usage_plan_key" "enginerds" {
  key_id        = "${aws_api_gateway_api_key.enginerds.id}"
  key_type      = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.enginerds.id}"
}

resource "aws_api_gateway_deployment" "stage" {
  rest_api_id = "${aws_api_gateway_rest_api.faas_api.id}"
  stage_name  = "${var.stage_name}"

  variables {
    deployed_at = "${timestamp()}"
    stage       = "${var.stage_name}"
  }

  # Create a new deployment before destroying the last - important for subsequent deploys
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method_settings" "stage_settings" {
  depends_on = ["aws_api_gateway_deployment.stage"]

  rest_api_id = "${aws_api_gateway_rest_api.faas_api.id}"
  stage_name  = "${var.stage_name}"
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_lambda_permission" "image_generator" {
  statement_id  = "APIGateway-AllowExecution-ImageGenerator-${var.stage_name}"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${local.aws_account}:function:ImageGenerator-${var.stage_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${local.aws_account}:${aws_api_gateway_rest_api.faas_api.id}/*/POST/v1/custom_images"
}

resource "aws_lambda_permission" "brand_gatherer_configuration" {
  statement_id  = "APIGateway-AllowExecution-BrandGatherer-fetchBrandConfiguration-${var.stage_name}"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${local.aws_account}:function:BrandGatherer-fetchBrandConfiguration-${var.stage_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${local.aws_account}:${aws_api_gateway_rest_api.faas_api.id}/*/POST/v1/campaign_attributes"
}

resource "aws_lambda_permission" "brand_gatherer_campaign_assets" {
  statement_id  = "APIGateway-AllowExecution-BrandGatherer-upsertCampaignAsset-${var.stage_name}"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${local.aws_account}:function:BrandGatherer-upsertCampaignAsset-${var.stage_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${local.aws_account}:${aws_api_gateway_rest_api.faas_api.id}/*/POST/v1/campaign_assets/upsert"
}

resource "aws_lambda_permission" "brand_gatherer_campaign_attributes" {
  statement_id  = "APIGateway-AllowExecution-BrandGatherer-upsertCampaignAttributes-${var.stage_name}"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${local.aws_account}:function:BrandGatherer-upsertCampaignAttributes-${var.stage_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${local.aws_account}:${aws_api_gateway_rest_api.faas_api.id}/*/POST/v1/campaign_attributes/upsert"
}

resource "aws_lambda_permission" "geo_gatherer_nearest_locations" {
  statement_id  = "APIGateway-AllowExecution-GeoGatherer-fetchNearestLocations-${var.stage_name}"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${local.aws_account}:function:GeoGatherer-fetchNearestLocations-${var.stage_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${local.aws_account}:${aws_api_gateway_rest_api.faas_api.id}/*/POST/v1/nearest_locations"
}

resource "aws_lambda_permission" "geo_broadsign_fetch_account_info" {
  statement_id  = "APIGateway-AllowExecution-GeoBroadsign-fetchAccountInfo-${var.stage_name}"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${local.aws_account}:function:GeoBroadsign-fetchAccountInfo-${var.stage_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${local.aws_account}:${aws_api_gateway_rest_api.faas_api.id}/*/POST/v1/SOMETHING"
}
