output "api_endpoint" {
  value       = aws_apigatewayv2_api.api.api_endpoint
  description = "The base URL for the API Gateway in this region"
}