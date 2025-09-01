#!/usr/bin/env bash
set -euo pipefail

PROFILE="wiz-sandbox"
REGION="us-east-1"

echo "🔎 Starting cleanup for AWS resources (profile=$PROFILE, region=$REGION)"

# --- EKS clusters ---
CLUSTERS=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query "clusters[]" --output text)
for c in $CLUSTERS; do
  if [[ "$c" == wiz* ]]; then
    echo "🗑 Deleting EKS cluster: $c"
    aws eks delete-cluster --name "$c" --region "$REGION" --profile "$PROFILE"
  fi
done

# --- EC2 instances ---
INSTANCES=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
  --filters "Name=tag:Name,Values=wiz*" --query "Reservations[].Instances[].InstanceId" --output text)

for i in $INSTANCES; do
  echo "🗑 Terminating EC2 instance: $i"
  aws ec2 terminate-instances --instance-ids "$i" --region "$REGION" --profile "$PROFILE"

  # Wait until terminated
  echo "⏳ Waiting for EC2 $i to terminate..."
  aws ec2 wait instance-terminated --instance-ids "$i" --region "$REGION" --profile "$PROFILE"
  echo "✅ EC2 $i terminated"
done

# --- Security groups ---
SGS=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
  --query "SecurityGroups[?contains(GroupName, 'wiz')].GroupId" --output text)
for sg in $SGS; do
  echo "🗑 Deleting Security Group: $sg"
  aws ec2 delete-security-group --group-id "$sg" --region "$REGION" --profile "$PROFILE" || true
done

# --- VPCs ---
VPCS=$(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" \
  --query "Vpcs[?contains(Tags[?Key=='Name'].Value|[0], 'wiz')].VpcId" --output text)
for v in $VPCS; do
  echo "🗑 Deleting VPC: $v"

  IGWS=$(aws ec2 describe-internet-gateways --region "$REGION" --profile "$PROFILE" \
    --filters "Name=attachment.vpc-id,Values=$v" --query "InternetGateways[].InternetGatewayId" --output text)
  for ig in $IGWS; do
    echo "  🔌 Detaching and deleting IGW: $ig"
    aws ec2 detach-internet-gateway --internet-gateway-id "$ig" --vpc-id "$v" --region "$REGION" --profile "$PROFILE" || true
    aws ec2 delete-internet-gateway --internet-gateway-id "$ig" --region "$REGION" --profile "$PROFILE" || true
  done

  SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --profile "$PROFILE" \
    --filters "Name=vpc-id,Values=$v" --query "Subnets[].SubnetId" --output text)
  for s in $SUBNETS; do
    echo "  🔌 Deleting subnet: $s"
    aws ec2 delete-subnet --subnet-id "$s" --region "$REGION" --profile "$PROFILE" || true
  done

  aws ec2 delete-vpc --vpc-id "$v" --region "$REGION" --profile "$PROFILE" || true
done

# --- S3 buckets ---
BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query "Buckets[].Name" --output text | tr '\t' '\n' | grep wiz || true)
for b in $BUCKETS; do
  echo "🗑 Deleting S3 bucket: $b"
  aws s3 rb "s3://$b" --force --profile "$PROFILE"
done

# --- IAM roles ---
ROLES=$(aws iam list-roles --profile "$PROFILE" --query "Roles[?contains(RoleName, 'wiz')].RoleName" --output text)
for r in $ROLES; do
  echo "🗑 Deleting IAM role: $r"
  aws iam delete-role --role-name "$r" --profile "$PROFILE" || true
done

echo ""
echo "✅ Cleanup complete!"

# --- Final sanity check ---
echo "🔍 Running final checks..."
aws eks list-clusters --region "$REGION" --profile "$PROFILE"
aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" --filters "Name=tag:Name,Values=wiz*"
aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" --filters "Name=tag:Name,Values=wiz*"
aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" --query "SecurityGroups[?contains(GroupName, 'wiz')]"
aws s3api list-buckets --profile "$PROFILE" --query "Buckets[].Name"
aws iam list-roles --profile "$PROFILE" --query "Roles[?contains(RoleName, 'wiz')].RoleName"
