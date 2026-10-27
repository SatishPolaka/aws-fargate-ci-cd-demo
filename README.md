# AWS Fargate CI/CD Demo

## Overview
This project demonstrates a complete DevOps workflow for a Python Flask micro‑service that stores data in DynamoDB and runs on AWS Fargate.  It includes:
- A real Flask implementation (`app.py`).
- Dockerfile for containerising the app.
- `docker‑compose.yml` for local development with a local DynamoDB (via LocalStack).
- GitHub Actions workflow (`ci-cd.yml`) that builds, tests, pushes the image to Amazon ECR and applies Terraform to update the Fargate service.
- Terraform configuration that creates the required AWS resources (VPC, ECS cluster, task definition, service, IAM roles, DynamoDB table).

## Prerequisites
- Docker & Docker‑Compose installed locally.
- Python 3.11+ (for running tests locally).
- An AWS account with permissions to create IAM roles, ECS, DynamoDB, and ECR.
- GitHub repository with **Secrets** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` set.

## Local Setup
```bash
# Clone the repo
git clone https://github.com/your‑org/aws-fargate-ci-cd-demo.git
cd aws-fargate-ci-cd-demo

# Build and start services locally
docker compose up --build -d

# Verify the API
curl http://localhost:5000/items
```
The `docker‑compose.yml` starts the Flask app and a LocalStack container that emulates DynamoDB.

## Running Tests
```bash
# Install test dependencies
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt pytest

# Execute tests
pytest
```

## CI/CD Pipeline (GitHub Actions)
The workflow `ci-cd.yml` runs on every push to `main` and performs the following steps:
1. Checkout code.
2. Set up Python and Terraform.
3. Run unit tests.
4. Build the Docker image and push it to an ECR repository (named `aws-fargate-ci-cd-demo`).
5. Initialise Terraform, create a plan, and apply it (auto‑approve) to update the Fargate service.

The pipeline uses the GitHub secrets mentioned above; **no credentials are stored in the repo**.

## Deploying Manually with Terraform
```bash
# Initialise Terraform
terraform -chdir=terraform init

# Review the plan
terraform -chdir=terraform plan -var "aws_region=$AWS_REGION"

# Apply the infrastructure (creates VPC, ECS, DynamoDB, etc.)
terraform -chdir=terraform apply -auto-approve -var "aws_region=$AWS_REGION"
```
After the apply, the ECS service will pull the latest image from ECR.

## Security Considerations
- All IAM roles follow the principle of least privilege (only the permissions required for ECS task execution and DynamoDB access).
- Secrets are never hard‑coded; they are injected via GitHub Secrets or the ECS task definition's secret manager integration.
- The Docker image is scanned in the CI pipeline using `trivy` (you can add it as an extra step).

## Cleanup
```bash
# Stop local containers
docker compose down

# Destroy AWS resources
terraform -chdir=terraform destroy -auto-approve -var "aws_region=$AWS_REGION"
```
This removes the VPC, ECS resources, DynamoDB table, and IAM roles.

---
*Happy coding!*