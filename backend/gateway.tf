# API Gateway for Chalice
resource "aws_api_gateway_rest_api" "api" {
  name = "bitbettyAPI"
}

# POST /guesses
resource "aws_api_gateway_resource" "guesses_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "guesses"
}

resource "aws_api_gateway_method" "post_guesses" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.guesses_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_post_guesses" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.guesses_resource.id
  http_method             = aws_api_gateway_method.post_guesses.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api-handler.invoke_arn
}

# GET /scores/{username}
resource "aws_api_gateway_resource" "scores_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "scores"
}

resource "aws_api_gateway_resource" "scores_username_param" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.scores_resource.id
  path_part   = "{username}"
}

resource "aws_api_gateway_method" "get_scores" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.scores_username_param.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.username" = true
  }
}

resource "aws_api_gateway_integration" "lambda_integration_get_scores" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scores_username_param.id
  http_method             = aws_api_gateway_method.get_scores.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api-handler.invoke_arn
  request_parameters = {
    "integration.request.path.username" = "method.request.path.username"
  }
}

# Permission to invoke Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api-handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_log_group.arn
    format          = "$context.requestId $context.identity.sourceIp $context.identity.userAgent $context.requestTime $context.status $context.protocol"
  }

  depends_on = [aws_api_gateway_account.api_gw_account]
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration_post_guesses,
    aws_api_gateway_integration.lambda_integration_get_scores
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

# Create IAM role for API Gateway to log to CloudWatch
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api-gateway-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "apigateway.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Attach a policy to the IAM role allowing it to publish logs to CloudWatch
resource "aws_iam_role_policy" "api_gateway_cloudwatch_role_policy" {
  role = aws_iam_role.api_gateway_cloudwatch_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Set the IAM role for API Gateway logging
resource "aws_api_gateway_account" "api_gw_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

resource "aws_cloudwatch_log_group" "api_gw_log_group" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.api.name}"
  retention_in_days = 7
}

# Define method settings separately using aws_api_gateway_method_settings
resource "aws_api_gateway_method_settings" "all_methods" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*" # This applies to all methods

  settings {
    logging_level      = "INFO" # Adjust logging level
    data_trace_enabled = true   # Enable detailed logging
    metrics_enabled    = true   # Enable CloudWatch metrics
  }
}