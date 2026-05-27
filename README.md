# adm_cloud_project

## Group Members
- Diogo Leandro: up202005034
- Luís Ganço: up202004196

## Setup (Terraform only)
1. Create a terraform.tfvars file in the terraform/ folder.
	Use terraform/terraform.tfvars.example as a template.
2. Initialize and apply Terraform:
	- terraform -chdir=terraform init
	- terraform -chdir=terraform apply
3. Tear down with:
	- terraform -chdir=terraform destroy

## K6 Test
k6 run tests/load-test.js

## Notes
- All Kubernetes resources are provisioned by Terraform (no kubectl apply).
- NGINX accepts Basic Auth (htpasswd) or JWT Bearer tokens.
- MinIO buckets and the API user are created by a Terraform-managed Job.
- For local dev with docker-compose, keep nginx/auth/.htpasswd and nginx/ssl/*.
