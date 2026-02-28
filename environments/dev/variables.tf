variable "candidate_email" {
  type        = string
  description = "Candidate email address for Cognito test user"
}

variable "candidate_password" {
  type        = string
  description = "Password for the Cognito test user"
  sensitive   = true # Hide the value in CLI outputs
}