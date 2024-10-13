resource "aws_api_gateway_method" "guesses_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.guesses_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "guesses_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.guesses_resource.id
  http_method = aws_api_gateway_method.guesses_options_method.http_method
  status_code = 200
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.guesses_options_method]
}

resource "aws_api_gateway_integration" "guesses_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.guesses_resource.id
  http_method = aws_api_gateway_method.guesses_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
  depends_on = [aws_api_gateway_method.guesses_options_method]
}
resource "aws_api_gateway_integration_response" "guesses_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.guesses_resource.id
  http_method = aws_api_gateway_method.guesses_options_method.http_method
  status_code = aws_api_gateway_method_response.guesses_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.guesses_options_200]
}

# OPTIONS for /scores/{username}
resource "aws_api_gateway_method" "scores_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.scores_username_param.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "scores_options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.scores_username_param.id
  http_method = aws_api_gateway_method.scores_options_method.http_method
  status_code = 200
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.scores_options_method]
}

resource "aws_api_gateway_integration" "scores_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.scores_username_param.id
  http_method = aws_api_gateway_method.scores_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
  depends_on = [aws_api_gateway_method.scores_options_method]
}
resource "aws_api_gateway_integration_response" "scores_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.scores_username_param.id
  http_method = aws_api_gateway_method.scores_options_method.http_method
  status_code = aws_api_gateway_method_response.scores_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.scores_options_200]
}