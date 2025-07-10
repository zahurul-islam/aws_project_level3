#!/bin/bash
# AWS Capstone Level 3 Infrastructure Cleanup Script
# This script safely destroys all resources in the proper order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project variables
PROJECT_NAME="aws-capstone-level3"
REGION="us-west-2"

echo -e "${YELLOW}🧹 Starting AWS Infrastructure Cleanup...${NC}"
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

# Function to check if resource exists and delete it
delete_if_exists() {
    local resource_type=$1
    local resource_name=$2
    local delete_command=$3
    
    echo -e "${YELLOW}Checking $resource_type: $resource_name${NC}"
    if eval $delete_command 2>/dev/null; then
        echo -e "${GREEN}✅ Deleted $resource_type: $resource_name${NC}"
    else
        echo -e "${RED}❌ Failed or not found: $resource_type $resource_name${NC}"
    fi
}

# 1. Delete Auto Scaling Group (if exists)
echo -e "\n${YELLOW}🔄 Step 1: Deleting Auto Scaling Group...${NC}"
ASG_NAME="${PROJECT_NAME}-wordpress-asg"

# First, set desired capacity to 0
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $ASG_NAME \
    --desired-capacity 0 \
    --min-size 0 \
    --region $REGION 2>/dev/null || echo "ASG not found or already cleaned"

# Wait a moment for instances to terminate
sleep 10

# Delete the ASG
delete_if_exists "Auto Scaling Group" $ASG_NAME \
    "aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ASG_NAME --force-delete --region $REGION"

# 2. Delete Launch Template
echo -e "\n${YELLOW}🚀 Step 2: Deleting Launch Template...${NC}"
LAUNCH_TEMPLATE_NAME="${PROJECT_NAME}-wordpress"

delete_if_exists "Launch Template" $LAUNCH_TEMPLATE_NAME \
    "aws ec2 delete-launch-template --launch-template-name $LAUNCH_TEMPLATE_NAME --region $REGION"

# 3. Delete Load Balancer Listener Rules and Listeners
echo -e "\n${YELLOW}⚖️ Step 3: Deleting Load Balancer components...${NC}"

# Get Load Balancer ARN
LB_ARN=$(aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region $REGION 2>/dev/null || echo "None")

if [ "$LB_ARN" != "None" ] && [ "$LB_ARN" != "null" ]; then
    # Delete listeners
    LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --query 'Listeners[*].ListenerArn' --output text --region $REGION 2>/dev/null || echo "")
    for listener in $LISTENERS; do
        delete_if_exists "Load Balancer Listener" $listener \
            "aws elbv2 delete-listener --listener-arn $listener --region $REGION"
    done
    
    # Delete the load balancer
    delete_if_exists "Load Balancer" "${PROJECT_NAME}-alb" \
        "aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN --region $REGION"
    
    echo "Waiting for Load Balancer to be deleted..."
    sleep 30
fi

# 4. Delete Target Groups
echo -e "\n${YELLOW}🎯 Step 4: Deleting Target Groups...${NC}"
TG_ARN=$(aws elbv2 describe-target-groups --names ${PROJECT_NAME}-wordpress-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region $REGION 2>/dev/null || echo "None")

if [ "$TG_ARN" != "None" ] && [ "$TG_ARN" != "null" ]; then
    delete_if_exists "Target Group" "${PROJECT_NAME}-wordpress-tg" \
        "aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION"
fi

# 5. Delete EC2 Instances
echo -e "\n${YELLOW}💻 Step 5: Deleting EC2 Instances...${NC}"

# Get all instances with our project tag
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=AWS-Capstone-Level3" "Name=instance-state-name,Values=running,stopped,stopping" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text --region $REGION 2>/dev/null || echo "")

if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION
    
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
    echo -e "${GREEN}✅ All instances terminated${NC}"
else
    echo "No instances found to terminate"
fi

# 6. Delete RDS Database
echo -e "\n${YELLOW}🗄️ Step 6: Deleting RDS Database...${NC}"
DB_IDENTIFIER="${PROJECT_NAME}-database"

delete_if_exists "RDS Database" $DB_IDENTIFIER \
    "aws rds delete-db-instance --db-instance-identifier $DB_IDENTIFIER --skip-final-snapshot --delete-automated-backups --region $REGION"

# 7. Delete Backup Selections and Plans
echo -e "\n${YELLOW}💾 Step 7: Deleting AWS Backup resources...${NC}"

# Delete backup selections
BACKUP_PLAN_ID=$(aws backup list-backup-plans --query "BackupPlansList[?BackupPlanName=='${PROJECT_NAME}-backup-plan'].BackupPlanId" --output text --region $REGION 2>/dev/null || echo "")

if [ -n "$BACKUP_PLAN_ID" ] && [ "$BACKUP_PLAN_ID" != "None" ]; then
    # Delete backup selections
    SELECTIONS=$(aws backup list-backup-selections --backup-plan-id $BACKUP_PLAN_ID --query 'BackupSelectionsList[*].SelectionId' --output text --region $REGION 2>/dev/null || echo "")
    for selection in $SELECTIONS; do
        delete_if_exists "Backup Selection" $selection \
            "aws backup delete-backup-selection --backup-plan-id $BACKUP_PLAN_ID --selection-id $selection --region $REGION"
    done
    
    # Delete backup plan
    delete_if_exists "Backup Plan" "${PROJECT_NAME}-backup-plan" \
        "aws backup delete-backup-plan --backup-plan-id $BACKUP_PLAN_ID --region $REGION"
fi

# Delete backup vault
delete_if_exists "Backup Vault" "${PROJECT_NAME}-backup-vault" \
    "aws backup delete-backup-vault --backup-vault-name ${PROJECT_NAME}-backup-vault --region $REGION"

# 8. Delete CloudWatch Log Groups
echo -e "\n${YELLOW}📊 Step 8: Deleting CloudWatch Log Groups...${NC}"

LOG_GROUPS=$(aws logs describe-log-groups --log-group-name-prefix "/aws/rds/instance/${PROJECT_NAME}" --query 'logGroups[*].logGroupName' --output text --region $REGION 2>/dev/null || echo "")
for log_group in $LOG_GROUPS; do
    delete_if_exists "CloudWatch Log Group" $log_group \
        "aws logs delete-log-group --log-group-name $log_group --region $REGION"
done

# 9. Delete CloudWatch Alarms
echo -e "\n${YELLOW}⏰ Step 9: Deleting CloudWatch Alarms...${NC}"

ALARMS=$(aws cloudwatch describe-alarms --alarm-name-prefix "$PROJECT_NAME" --query 'MetricAlarms[*].AlarmName' --output text --region $REGION 2>/dev/null || echo "")
for alarm in $ALARMS; do
    delete_if_exists "CloudWatch Alarm" $alarm \
        "aws cloudwatch delete-alarms --alarm-names $alarm --region $REGION"
done

# 10. Delete Auto Scaling Policies
echo -e "\n${YELLOW}📈 Step 10: Deleting Auto Scaling Policies...${NC}"

POLICIES=$(aws autoscaling describe-policies --query "ScalingPolicies[?contains(PolicyName, '$PROJECT_NAME')].PolicyName" --output text --region $REGION 2>/dev/null || echo "")
for policy in $POLICIES; do
    delete_if_exists "Auto Scaling Policy" $policy \
        "aws autoscaling delete-policy --policy-name $policy --region $REGION"
done

# 11. Detach and Delete IAM Policies, then Delete IAM Roles
echo -e "\n${YELLOW}🔐 Step 11: Deleting IAM Resources...${NC}"

# Delete IAM Instance Profiles
for profile in "${PROJECT_NAME}-wordpress-profile" "${PROJECT_NAME}-bastion-profile"; do
    # Remove role from instance profile first
    aws iam remove-role-from-instance-profile --instance-profile-name $profile --role-name ${profile%-profile}-role --region $REGION 2>/dev/null || true
    
    delete_if_exists "IAM Instance Profile" $profile \
        "aws iam delete-instance-profile --instance-profile-name $profile"
done

# Delete IAM Role Policies and Roles
for role in "${PROJECT_NAME}-wordpress-role" "${PROJECT_NAME}-bastion-role" "${PROJECT_NAME}-backup-role" "${PROJECT_NAME}-rds-monitoring-role"; do
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null || echo "")
    for policy_arn in $ATTACHED_POLICIES; do
        aws iam detach-role-policy --role-name $role --policy-arn $policy_arn 2>/dev/null || true
    done
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name $role --query 'PolicyNames[*]' --output text 2>/dev/null || echo "")
    for policy in $INLINE_POLICIES; do
        aws iam delete-role-policy --role-name $role --policy-name $policy 2>/dev/null || true
    done
    
    # Delete the role
    delete_if_exists "IAM Role" $role \
        "aws iam delete-role --role-name $role"
done

# 12. Delete DB Parameter Group
echo -e "\n${YELLOW}⚙️ Step 12: Deleting DB Parameter Group...${NC}"
delete_if_exists "DB Parameter Group" "${PROJECT_NAME}-mysql-params" \
    "aws rds delete-db-parameter-group --db-parameter-group-name ${PROJECT_NAME}-mysql-params --region $REGION"

# 13. Delete DB Subnet Group
echo -e "\n${YELLOW}🌐 Step 13: Deleting DB Subnet Group...${NC}"
delete_if_exists "DB Subnet Group" "${PROJECT_NAME}-db-subnet-group" \
    "aws rds delete-db-subnet-group --db-subnet-group-name ${PROJECT_NAME}-db-subnet-group --region $REGION"

# 14. Delete KMS Key Alias and Key
echo -e "\n${YELLOW}🔑 Step 14: Deleting KMS Resources...${NC}"

# Delete KMS alias
delete_if_exists "KMS Alias" "alias/${PROJECT_NAME}-backup" \
    "aws kms delete-alias --alias-name alias/${PROJECT_NAME}-backup --region $REGION"

# Get and schedule KMS key for deletion
KEY_ID=$(aws kms list-keys --query "Keys[?KeyId!=''].KeyId" --output text --region $REGION 2>/dev/null || echo "")
if [ -n "$KEY_ID" ]; then
    # We'll schedule for deletion rather than immediate deletion
    for key in $KEY_ID; do
        KEY_DESC=$(aws kms describe-key --key-id $key --query 'KeyMetadata.Description' --output text --region $REGION 2>/dev/null || echo "")
        if [[ "$KEY_DESC" == *"backup encryption"* ]]; then
            delete_if_exists "KMS Key (scheduled for deletion)" $key \
                "aws kms schedule-key-deletion --key-id $key --pending-window-in-days 7 --region $REGION"
        fi
    done
fi

# 15. Delete Route Table Associations
echo -e "\n${YELLOW}🛣️ Step 15: Deleting Route Table Associations...${NC}"

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" --query 'Vpcs[0].VpcId' --output text --region $REGION 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    # Get custom route tables (not main route table)
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" --query 'RouteTables[*].RouteTableId' --output text --region $REGION 2>/dev/null || echo "")
    
    for rt in $ROUTE_TABLES; do
        # Delete associations
        ASSOCIATIONS=$(aws ec2 describe-route-tables --route-table-ids $rt --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' --output text --region $REGION 2>/dev/null || echo "")
        for assoc in $ASSOCIATIONS; do
            delete_if_exists "Route Table Association" $assoc \
                "aws ec2 disassociate-route-table --association-id $assoc --region $REGION"
        done
    done
fi

# 16. Delete Security Groups
echo -e "\n${YELLOW}🛡️ Step 16: Deleting Security Groups...${NC}"

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    # Get custom security groups (not default)
    SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=${PROJECT_NAME}-*" --query 'SecurityGroups[*].GroupId' --output text --region $REGION 2>/dev/null || echo "")
    
    for sg in $SECURITY_GROUPS; do
        delete_if_exists "Security Group" $sg \
            "aws ec2 delete-security-group --group-id $sg --region $REGION"
    done
fi

# 17. Delete Route Tables
echo -e "\n${YELLOW}📍 Step 17: Deleting Route Tables...${NC}"

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" --query 'RouteTables[*].RouteTableId' --output text --region $REGION 2>/dev/null || echo "")
    
    for rt in $ROUTE_TABLES; do
        delete_if_exists "Route Table" $rt \
            "aws ec2 delete-route-table --route-table-id $rt --region $REGION"
    done
fi

# 18. Delete Subnets
echo -e "\n${YELLOW}🌐 Step 18: Deleting Subnets...${NC}"

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region $REGION 2>/dev/null || echo "")
    
    for subnet in $SUBNETS; do
        delete_if_exists "Subnet" $subnet \
            "aws ec2 delete-subnet --subnet-id $subnet --region $REGION"
    done
fi

# 19. Delete Internet Gateway
echo -e "\n${YELLOW}🌍 Step 19: Deleting Internet Gateway...${NC}"

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --region $REGION 2>/dev/null || echo "None")
    
    if [ "$IGW_ID" != "None" ] && [ "$IGW_ID" != "null" ]; then
        # Detach from VPC first
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION 2>/dev/null || true
        
        delete_if_exists "Internet Gateway" $IGW_ID \
            "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION"
    fi
fi

# 20. Delete VPC
echo -e "\n${YELLOW}🏠 Step 20: Deleting VPC...${NC}"

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    delete_if_exists "VPC" $VPC_ID \
        "aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION"
fi

# Final cleanup check
echo -e "\n${GREEN}🎉 Cleanup Complete!${NC}"
echo ""
echo "Summary:"
echo "- All EC2 instances terminated"
echo "- RDS database deleted" 
echo "- Load balancer and target groups removed"
echo "- Auto Scaling Group and Launch Template deleted"
echo "- IAM roles and policies cleaned up"
echo "- Network infrastructure (VPC, subnets, security groups) removed"
echo "- Backup vault and plans deleted"
echo "- KMS key scheduled for deletion"
echo ""
echo -e "${YELLOW}Note: Some resources like RDS and KMS keys may take a few minutes to be fully deleted.${NC}"
echo -e "${YELLOW}RDS will be deleted with automated backups, and KMS key is scheduled for deletion in 7 days.${NC}"