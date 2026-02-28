# Call Cognito module
module "cognito" {
  source = "../../modules/cognito"

  # use us-east-1 provider from providers.tf
  providers = {
    aws = aws.us_east_1
  }

  # Pass variables from environment to module
  candidate_email    = var.candidate_email
  candidate_password = var.candidate_password
}

# Output IDs needed for test script
output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

variable "github_repo" {
  type        = string
  description = "Your GitHub repository URL"
  default     = "https://github.com/your-username/aws-assessment"
}

# --- DEPLOY COMPUTE STACK TO US-EAST-1 ---
module "compute_us_east_1" {
  source = "../../modules/compute-stack"
  
  providers = {
    aws = aws.us_east_1
  }

  candidate_email      = var.candidate_email
  github_repo          = var.github_repo
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.client_id
}

# --- DEPLOY COMPUTE STACK TO EU-WEST-1 ---
module "compute_eu_west_1" {
  source = "../../modules/compute-stack"
  
  providers = {
    aws = aws.eu_west_1
  }

  candidate_email      = var.candidate_email
  github_repo          = var.github_repo
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.client_id
}

# --- EXPORT REGIONAL API URLS ---
output "api_url_us_east_1" {
  value = module.compute_us_east_1.api_endpoint
}

output "api_url_eu_west_1" {
  value = module.compute_eu_west_1.api_endpoint
}