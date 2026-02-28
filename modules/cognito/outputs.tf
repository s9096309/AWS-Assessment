output "user_pool_id" {
  value       = aws_cognito_user_pool.pool.id
  description = "The ID of the Cognito User Pools"
}

output "client_id" {
  value       = aws_cognito_user_pool_client.client.id
  description = "The Client-ID for the Test-Script"
}