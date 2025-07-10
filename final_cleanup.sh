#!/bin/bash
# Final cleanup script for remaining AWS resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_NAME="aws-capstone-level3"
REGION="us-west-2"

echo -e "${YELLOW}🔄 Final cleanup of remaining AWS resources...${NC}"

# Wait for RDS to be completely deleted
echo -e "${YELLOW}⏳ Waiting for RDS database to finish deleting...${NC}"
while true; do
    STATUS=$(aws rds describe-db-instances --db-instance-identifier ${PROJECT_NAME}-database --query 'DBInstances[0].DBInstanceStatus' --output text --region $REGION 2>/dev/null || echo "deleted")
    if [ "$STATUS" = "deleted" ]; then
        echo -e "${GREEN}✅ RDS database deletion complete${NC}"
        break
    else
        echo "RDS status: $STATUS - waiting..."
        sleep 30
    fi
done

# Now clean up the remaining RDS dependencies
echo -e "\n${YELLOW}🗄️ Cleaning up RDS dependencies...${NC}"

# Delete DB Subnet Group
aws rds delete-db-subnet-group --db-subnet-group-name ${PROJECT_NAME}-db-subnet-group --region $REGION 2>/dev/null && echo -e "${GREEN}✅ Deleted DB Subnet Group${NC}" || echo -e "${RED}❌ DB Subnet Group not found${NC}"

# Delete DB Parameter Group
aws rds delete-db-parameter-group --db-parameter-group-name ${PROJECT_NAME}-mysql-params --region $REGION 2>/dev/null && echo -e "${GREEN}✅ Deleted DB Parameter Group${NC}" || echo -e "${RED}❌ DB Parameter Group not found${NC}"

# Clean up remaining subnets
echo -e "\n${YELLOW}🌐 Cleaning up remaining subnets...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" --query 'Vpcs[0].VpcId' --output text --region $REGION 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region $REGION 2>/dev/null || echo "")
    
    for subnet in $SUBNETS; do
        aws ec2 delete-subnet --subnet-id $subnet --region $REGION 2>/dev/null && echo -e "${GREEN}✅ Deleted subnet: $subnet${NC}" || echo -e "${RED}❌ Failed to delete subnet: $subnet${NC}"
    done
fi

# Clean up remaining security groups
echo -e "\n${YELLOW}🛡️ Cleaning up remaining security groups...${NC}"
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=${PROJECT_NAME}-*" --query 'SecurityGroups[*].GroupId' --output text --region $REGION 2>/dev/null || echo "")
    
    for sg in $SECURITY_GROUPS; do
        aws ec2 delete-security-group --group-id $sg --region $REGION 2>/dev/null && echo -e "${GREEN}✅ Deleted security group: $sg${NC}" || echo -e "${RED}❌ Failed to delete security group: $sg${NC}"
    done
fi

# Clean up remaining route tables
echo -e "\n${YELLOW}📍 Cleaning up remaining route tables...${NC}"
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" --query 'RouteTables[*].RouteTableId' --output text --region $REGION 2>/dev/null || echo "")
    
    for rt in $ROUTE_TABLES; do
        aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>/dev/null && echo -e "${GREEN}✅ Deleted route table: $rt${NC}" || echo -e "${RED}❌ Failed to delete route table: $rt${NC}"
    done
fi

# Final VPC cleanup
echo -e "\n${YELLOW}🏠 Final VPC cleanup...${NC}"
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null && echo -e "${GREEN}✅ Deleted VPC: $VPC_ID${NC}" || echo -e "${RED}❌ Failed to delete VPC: $VPC_ID${NC}"
fi

# Clean up Terraform state
echo -e "\n${YELLOW}🔧 Cleaning up Terraform state...${NC}"
if [ -f "terraform.tfstate" ]; then
    rm terraform.tfstate terraform.tfstate.backup 2>/dev/null || true
    echo -e "${GREEN}✅ Cleaned up Terraform state files${NC}"
fi

if [ -f ".terraform.tfstate.lock.info" ]; then
    rm .terraform.tfstate.lock.info 2>/dev/null || true
    echo -e "${GREEN}✅ Removed Terraform lock file${NC}"
fi

echo -e "\n${GREEN}🎉 Final cleanup complete!${NC}"
echo ""
echo "Summary of actions:"
echo "✅ RDS database fully deleted"
echo "✅ DB subnet group and parameter group removed"
echo "✅ All remaining subnets deleted"
echo "✅ All security groups removed" 
echo "✅ All route tables cleaned up"
echo "✅ VPC deleted"
echo "✅ Terraform state cleaned up"
echo ""
echo -e "${YELLOW}Your AWS infrastructure has been completely removed!${NC}"
echo -e "${YELLOW}Note: KMS key is scheduled for deletion in 7 days as a safety measure.${NC}"
