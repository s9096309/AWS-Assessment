# Unleash live AWS DevOps Assessment

## Candidate Info
- **Name:** Kevin Hoffmann
- **Email:** k-hoff-mann@web.de
- **Repository:** https://github.com/s9096309/aws-assessment

---

## Architecture Overview
This project provisions a highly available, multi-region compute stack across **us-east-1** (N. Virginia) and **eu-west-1** (Ireland). 

### Key Components:
* **Centralized Identity:** A single Amazon Cognito User Pool in `us-east-1` providing JWT-based authentication for both regions.
* **API Layer:** Amazon API Gateway (HTTP) with a JWT Authorizer.
* **Serverless Compute:**
    * **Lambda 1 (The Greeter):** Logs metadata to a regional DynamoDB table and publishes a verification payload to the Unleash live SNS Topic.
    * **Lambda 2 (The Dispatcher):** Programmatically triggers an ECS Fargate Task.
* **Containerized Compute:** (ECS Fargate Task): Runs a lightweight container using the AWS CLI to publish a secondary verification payload to the SNS Topic.
* **Storage:** Regional DynamoDB tables for localized greeting logs.

---

## Multi-Region Provider Structure
To achieve a DRY (Don't Repeat Yourself) deployment, the project utilizes Terraform modules:
* The `compute-stack` module encapsulates all regional resources.
* In `environments/dev/main.tf`, the module is called twice using **Provider Aliases** (`aws.us_east_1` and `aws.eu_west_1`). This allows identical infrastructure to be deployed globally with a single command.

---

## Security Remediation Note
During development, a secret leak was detected by GitGuardian in the initial commit history. 
**Remediation actions taken:**
1.  Completely deleted the compromised GitHub repository and created a fresh one.
2.  Rotated all sensitive passwords.
3.  Refactored the Python test script to use **Environment Variables** instead of hardcoded strings.
4.  Ensured `.tfvars` and `.terraform` files are strictly excluded via `.gitignore`.

---

## Prerequisites
* Terraform installed (v1.7+)
* AWS CLI configured with appropriate credentials
* Python 3.12+ installed
* Python libraries: `pip install boto3 requests`

---

## Deployment & Testing Instructions

### 1. Provision Infrastructure
```bash
cd environments/dev
terraform init
terraform apply -auto-approve
```

---

### 2. Configure Cognito User
Because Cognito users are created with a temporary status, you must confirm the user and set the password for the test script:

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id "$(terraform output -raw cognito_user_pool_id)" \
  --username "k-hoff-mann@web.de" \
  --password 'YOUR_CHOSEN_PASSWORD' \
  --permanent \
  --region us-east-1
```

---

### 3. Run Integration Tests
Set your chosen password as an environment variable and run the test script. The script will authenticate, hit all regional endpoints, and measure latency.

```bash
export TEST_PASSWORD='YOUR_CHOSEN_PASSWORD'
cd ../../scripts
python3 test_deployment.py
```

---

### 4. Cleanup
To avoid ongoing AWS charges for Fargate and VPC networking:

```bash
cd ../environments/dev
terraform destroy -auto-approve
```