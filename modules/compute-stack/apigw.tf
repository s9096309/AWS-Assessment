# --- API GATEWAY ---
resource "aws_apigatewayv2_api" "api" {
  name          = "unleash-api-${data.aws_region.current.name}"
  protocol_type = "HTTP"
}

# --- COGNITO AUTHORIZER ---
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${var.cognito_user_pool_id}"
    audience = [var.cognito_client_id]
  }
}

# --- INTEGRATIONS ---
resource "aws_apigatewayv2_integration" "greeter_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.greeter.invoke_arn
}

resource "aws_apigatewayv2_integration" "dispatcher_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.dispatcher.invoke_arn
}

# --- ROUTES ---
resource "aws_apigatewayv2_route" "greet_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /greet"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
  target             = "integrations/${aws_apigatewayv2_integration.greeter_integration.id}"
}

resource "aws_apigatewayv2_route" "dispatch_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /dispatch"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
  target             = "integrations/${aws_apigatewayv2_integration.dispatcher_integration.id}"
}

# --- STAGE ---
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# --- LAMBDA PERMISSIONS ---
# Allow API Gateway to invoke Lambda functions
resource "aws_lambda_permission" "apigw_greeter" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_dispatcher" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatcher.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}