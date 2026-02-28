# Unleash live AWS DevOps Assessment

## Candidate Info
* **Name:** Kevin Hoffmann
* **Email:** k-hoff-mann@web.de
* **Repository:** https://github.com/s9096309/aws-assessment

## Architecture Overview
This project provisions a multi-region compute stack (API Gateway, Lambda, DynamoDB, ECS Fargate) in `us-east-1` and `eu-west-1`. Both compute stacks are secured by a centralized Amazon Cognito User Pool located in `us-east-1`.

### Multi-Region Provider Structure
To achieve a DRY (Don't Repeat Yourself) multi-region deployment, this project utilizes Terraform modules. 
* The `compute-stack` module encapsulates all regional resources.
* In the `environments/dev/main.tf` file, the `compute-stack` module is called twice. 
* We use **provider aliases** (`aws.us_east_1` and `aws.eu_west_1`) passed into the module blocks to route the identical infrastructure configurations to their respective AWS regions.

## Prerequisites
* [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
* [AWS CLI](https://aws.amazon.com/cli/) installed and configured with appropriate credentials
* Python 3.x installed (for the test script)
* `boto3` and `requests` libraries installed (`pip install boto3 requests`)

## How to Deploy Manually

1. **Clone the repository and navigate to the environment directory:**
   ```bash
   cd environments/dev