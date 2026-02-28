variable "candidate_email" {
  type        = string
  description = "Candidate email address for SNS payload"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository link for SNS payload"
}

variable "cognito_user_pool_id" {
  type        = string
  description = "Cognito User Pool ID for API Gateway Authorizer"
}

variable "cognito_client_id" {
  type        = string
  description = "Cognito Client ID for API Gateway Authorizer"
}

data "aws_region" "current" {}