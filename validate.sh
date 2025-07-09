#!/bin/bash
# Pre-deployment validation script for AWS Capstone Level 3

set -e

echo "🔍 AWS Capstone Level 3 - Pre-deployment Validation"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if required tools are installed
echo -e "\n📋 Checking Prerequisites..."

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | cut -d' ' -f2)
    print_status 0 "Terraform is installed (version: $TERRAFORM_VERSION)"
else
    print_status 1 "Terraform is not installed"
    exit 1
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    print_status 0 "AWS CLI is installed ($AWS_VERSION)"
else
    print_status 1 "AWS CLI is not installed"
    exit 1
fi

# Check AWS credentials
echo -e "\n🔐 Checking AWS Configuration..."
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region)
    print_status 0 "AWS credentials are configured (Account: $AWS_ACCOUNT, Region: $AWS_REGION)"
else
    print_status 1 "AWS credentials are not configured or invalid"
    echo "Run 'aws configure' to set up your credentials"
    exit 1
fi

# Check if terraform.tfvars exists
echo -e "\n⚙️  Checking Configuration..."
if [ -f "terraform.tfvars" ]; then
    print_status 0 "terraform.tfvars file exists"
    
    # Check key variables
    if grep -q "key_pair_name.*=" terraform.tfvars && ! grep -q "your-key-pair-name" terraform.tfvars; then
        print_status 0 "Key pair name is configured"
    else
        print_status 1 "Key pair name needs to be updated in terraform.tfvars"
    fi
    
    if grep -q "wordpress_db_password.*=" terraform.tfvars && ! grep -q "ChangeMe123!" terraform.tfvars; then
        print_status 0 "Database password has been changed"
    else
        print_warning "Database password should be changed in terraform.tfvars"
    fi
else
    print_status 1 "terraform.tfvars file not found"
    echo "Copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

# Validate Terraform configuration
echo -e "\n🔧 Validating Terraform Configuration..."
if terraform validate &> /dev/null; then
    print_status 0 "Terraform configuration is valid"
else
    print_status 1 "Terraform configuration has errors"
    echo "Run 'terraform validate' for details"
    exit 1
fi

# Check EC2 key pair exists
echo -e "\n🔑 Checking EC2 Key Pair..."
if [ -f "terraform.tfvars" ]; then
    KEY_PAIR_NAME=$(grep "key_pair_name" terraform.tfvars | cut -d'"' -f2)
    if [ -n "$KEY_PAIR_NAME" ] && [ "$KEY_PAIR_NAME" != "your-key-pair-name" ]; then
        if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" &> /dev/null; then
            print_status 0 "EC2 key pair '$KEY_PAIR_NAME' exists"
        else
            print_status 1 "EC2 key pair '$KEY_PAIR_NAME' not found"
            echo "Create the key pair or update terraform.tfvars"
        fi
    else
        print_warning "Key pair name needs to be configured"
    fi
fi

# Check available resources
echo -e "\n📊 Checking AWS Limits..."
# This is a basic check - in production you'd want more comprehensive limit checking
VPC_COUNT=$(aws ec2 describe-vpcs --query 'Vpcs | length(@)')
if [ "$VPC_COUNT" -lt 5 ]; then
    print_status 0 "VPC limit check passed ($VPC_COUNT/5 VPCs used)"
else
    print_warning "Approaching VPC limit ($VPC_COUNT/5 VPCs used)"
fi

# Final summary
echo -e "\n🎯 Validation Complete!"
echo "=================================================="
echo "If all checks passed, you can proceed with deployment:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
echo ""
echo "Or use the Makefile:"
echo "  make deploy"
echo ""
print_warning "Remember to review the plan before applying!"
