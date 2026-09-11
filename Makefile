.PHONY: init plan apply destroy fmt validate

TF_DIR := terraform

init:
	cd $(TF_DIR) && terraform init

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate: fmt
	cd $(TF_DIR) && terraform validate

plan: validate
	cd $(TF_DIR) && terraform plan

apply: validate
	cd $(TF_DIR) && terraform apply

destroy:
	cd $(TF_DIR) && terraform destroy
