.PHONY: help init plan apply destroy validate fmt clean status

# Default target
help:
	@echo "Available targets:"
	@echo "  init     - Initialize Terraform"
	@echo "  validate - Validate Terraform configuration"
	@echo "  fmt      - Format Terraform files"
	@echo "  plan     - Create Terraform execution plan"
	@echo "  apply    - Apply Terraform configuration"
	@echo "  destroy  - Destroy Terraform infrastructure"
	@echo "  status   - Show current infrastructure status"
	@echo "  clean    - Clean Terraform cache and state"

# Initialize Terraform
init:
	terraform init

# Validate configuration
validate:
	terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive

# Create execution plan
plan:
	terraform plan

# Apply configuration
apply:
	terraform apply

# Destroy infrastructure
destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	terraform destroy

# Show current status
status:
	@echo "=== Terraform Workspace ==="
	terraform workspace show
	@echo "\n=== Infrastructure State ==="
	terraform show -json | jq -r '.values.root_module.resources[].address' 2>/dev/null || echo "No resources found"
	@echo "\n=== Outputs ==="
	terraform output 2>/dev/null || echo "No outputs available"

# Clean cache and state
clean:
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.plan
	rm -f *.backup

# Full deployment workflow
deploy: init validate fmt plan apply

# Development workflow
dev: fmt validate plan
