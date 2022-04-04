locals {
  request_template = {
    Key = {
      id = {
        S = "$input.json('$.url')"
      }
    },
    TableName = aws_dynamodb_table.urls.name
  }
  post_schema = {
    required = ["url"]
    type     = "string"
    pattern  = "^https?://[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{2,6}\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*)"
  }
  base_url = var.custom_domain == "" ? aws_api_gateway_stage.this.invoke_url : "https://${var.custom_domain}"
}

data "aws_iam_policy_document" "api_trust" {
  statement {
    sid     = "APIGatewayTrustPolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_api_gateway_rest_api" "shortener" {
  name        = "ShortenerAPI"
  description = "API for the best URL shortener in the Milky Way and a few parts of Andromeda"
}

resource "aws_api_gateway_resource" "get_url" {
  rest_api_id = aws_api_gateway_rest_api.shortener.id
  parent_id   = aws_api_gateway_rest_api.shortener.root_resource_id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "get_url" {
  rest_api_id   = aws_api_gateway_rest_api.shortener.id
  resource_id   = aws_api_gateway_resource.get_url.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.url" = true
  }
}

resource "aws_api_gateway_method" "post_url" {
  rest_api_id   = aws_api_gateway_rest_api.shortener.id
  resource_id   = aws_api_gateway_rest_api.shortener.root_resource_id
  http_method   = "POST"
  authorization = "NONE" # TODO: switch to Cognito
  request_models = {
    "application/json" = aws_api_gateway_model.post.name
  }
}

resource "aws_api_gateway_integration" "get_url" {
  rest_api_id             = aws_api_gateway_rest_api.shortener.id
  resource_id             = aws_api_gateway_resource.get_url.id
  http_method             = aws_api_gateway_method.get_url.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.get_url_by_id.invoke_arn
  passthrough_behavior    = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = <<EoF
{"Key":{"url":{"S": $input.json('$.url')}},"TableName":"URLTable"}
EoF
  }
}

resource "aws_api_gateway_integration" "post_url" {
  rest_api_id             = aws_api_gateway_rest_api.shortener.id
  resource_id             = aws_api_gateway_rest_api.shortener.root_resource_id
  http_method             = aws_api_gateway_method.post_url.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.post_url.invoke_arn
  passthrough_behavior    = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = <<EoF
{"Key":{"url":{"S": $input.json('$.url')}},"TableName":"URLTable"}
EoF
  }
}

resource "aws_api_gateway_method_response" "get_url_ok" {
  rest_api_id = aws_api_gateway_rest_api.shortener.id
  resource_id = aws_api_gateway_resource.get_url.id
  http_method = aws_api_gateway_method.get_url.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Location" = true
  }
}

resource "aws_api_gateway_method_response" "post_url_ok" {
  rest_api_id = aws_api_gateway_rest_api.shortener.id
  resource_id = aws_api_gateway_rest_api.shortener.root_resource_id
  http_method = aws_api_gateway_method.post_url.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "get_url_redirect" {
  rest_api_id = aws_api_gateway_rest_api.shortener.id
  resource_id = aws_api_gateway_resource.get_url.id
  http_method = aws_api_gateway_method.get_url.http_method
  status_code = aws_api_gateway_method_response.get_url_ok.status_code

  response_parameters = {
    "method.response.header.Location" = "integration.response.body.Item.url"
  }

  response_templates = {
    "application/json" = <<EoF
#set($inputRoot = $input.path('$')) 
#if($inputRoot.toString().contains("url")) 
#set($context.responseOverride.header.Location = $inputRoot.url.S) 
#end
EoF
  }

  depends_on = [aws_api_gateway_integration.get_url]
}

resource "aws_api_gateway_integration_response" "post_url" {
  rest_api_id = aws_api_gateway_rest_api.shortener.id
  resource_id = aws_api_gateway_rest_api.shortener.root_resource_id
  http_method = aws_api_gateway_method.post_url.http_method
  status_code = aws_api_gateway_method_response.post_url_ok.status_code

  response_templates = {
    "application/json" = <<EoF
#set($inputRoot = $input.path('$')) 
{"id":"$inputRoot.id.S", "url":"$inputRoot.url.S", "created":"$inputRoot.created.S", "userid":"$inputRoot.userid.S"}
EoF
  }
}
resource "aws_api_gateway_deployment" "shortener_deployment" {
  rest_api_id = aws_api_gateway_rest_api.shortener.id
  stage_name  = "v1"

  variables = {
    deployedAt = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.get_url, aws_api_gateway_integration.post_url]
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.shortener_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.shortener.id
  stage_name    = "v1"
}

resource "aws_api_gateway_model" "post" {
  rest_api_id  = aws_api_gateway_rest_api.shortener.id
  name         = "PostBody"
  description  = "Schema for POSTing URLs to /"
  content_type = "application/json"

  schema = <<EoF
{
  "required" : [ "url" ],
  "type" : "string",
  "pattern" : "^https?://[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{2,6}\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*)"
}
EoF
}
