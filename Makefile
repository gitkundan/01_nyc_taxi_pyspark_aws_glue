ENV ?=dev
TF_DIR := infrastructure/terraform

.PHONY: tf-init tf-fmt tf-validate tf-plan tf-apply tf-destroy tf-clean tf-deploy glue-start-bronze

# Terraform commands for AWS Glue setup
tf-init:
	cd $(TF_DIR) && rm -f terraform.tfstate terraform.tfstate.backup tfplan.bin
	cd $(TF_DIR) && rm -rf .terraform
	cd $(TF_DIR) && rm -f .terraform.lock.hcl
	cd $(TF_DIR) && terraform init

tf-fmt:
	cd $(TF_DIR) && terraform fmt -recursive

tf-validate:
	cd $(TF_DIR) && terraform validate

tf-ls:
	cd $(TF_DIR) && terraform state list


tf-plan:
	cd $(TF_DIR) && terraform plan -refresh=false -var-file=env/$(ENV).tfvars

tf-apply:
	cd $(TF_DIR) && terraform apply -auto-approve -var-file=env/$(ENV).tfvars

tf-destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve -var-file=env/$(ENV).tfvars

tf-clean:
	cd $(TF_DIR) && rm -f terraform.tfstate terraform.tfstate.backup tfplan.bin
	cd $(TF_DIR) && rm -rf .terraform
	cd $(TF_DIR) && rm -f .terraform.lock.hcl

tf-deploy:
	$(MAKE) tf-fmt ENV=$(ENV)
	$(MAKE) tf-validate ENV=$(ENV)
	$(MAKE) tf-apply ENV=$(ENV)

# Glue commands
glue-start-bronze:
	aws glue start-job-run --job-name dev_ingest_into_bronze

# Airflow commands