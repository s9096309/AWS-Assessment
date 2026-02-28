# User pool
resource "aws_cognito_user_pool" "pool" {
  name = "unleash-live-assessment-pool"

  # Allow login with valid email address
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
}

# Client (used by test-script and API Gateway)
resource "aws_cognito_user_pool_client" "client" {
  name         = "unleash-live-assessment-client"
  user_pool_id = aws_cognito_user_pool.pool.id

  generate_secret = false

  # Flows to allow easy login via script
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"
  ]
}

# Test-user
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.pool.id
  username     = var.candidate_email
  password     = var.candidate_password

  attributes = {
    email          = var.candidate_email
    email_verified = "true"
  }
}