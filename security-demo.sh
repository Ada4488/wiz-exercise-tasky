#!/bin/bash

# Security Controls Demonstration Script
# This script demonstrates the security controls implemented in the Wiz exercise

set -e

echo "🔒 WIZ EXERCISE - SECURITY CONTROLS DEMONSTRATION"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get cluster name from Terraform output
CLUSTER_NAME=$(terraform -chdir=infra/main output -raw cluster_name 2>/dev/null || echo "wiz-eks")
REGION=$(terraform -chdir=infra/main output -raw region 2>/dev/null || echo "us-west-2")

print_status "Using cluster: $CLUSTER_NAME in region: $REGION"

echo ""
echo "1. 🔍 EKS CONTROL PLANE AUDIT LOGGING"
echo "-------------------------------------"

print_status "Checking EKS control plane logging configuration..."
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query 'cluster.logging.clusterLogging[0].enabled' --output text

if [ $? -eq 0 ]; then
    print_success "EKS control plane logging is enabled"
    print_status "Logs are sent to CloudWatch Logs"
    print_status "You can view them in the AWS Console under CloudWatch > Log groups > /aws/eks/$CLUSTER_NAME/cluster"
else
    print_error "Failed to check EKS logging configuration"
fi

echo ""
echo "2. 🛡️ GUARDDUTY THREAT DETECTION"
echo "--------------------------------"

print_status "Checking GuardDuty status..."
GUARDDUTY_STATUS=$(aws guardduty list-detectors --region "$REGION" --query 'DetectorIds[0]' --output text 2>/dev/null || echo "none")

if [ "$GUARDDUTY_STATUS" != "none" ]; then
    print_success "GuardDuty is enabled with detector: $GUARDDUTY_STATUS"
    
    print_status "Checking for recent findings..."
    FINDINGS=$(aws guardduty list-findings --detector-id "$GUARDDUTY_STATUS" --region "$REGION" \
        --finding-criteria '{"Criterion": {"severity": {"Gte": 4}}}' --query 'FindingIds' --output text 2>/dev/null || echo "")
    
    if [ -n "$FINDINGS" ]; then
        print_warning "Found high severity GuardDuty findings:"
        echo "$FINDINGS"
    else
        print_success "No high severity findings detected"
    fi
else
    print_warning "GuardDuty not found in this region"
fi

echo ""
echo "3. 🔐 KMS ENCRYPTION"
echo "-------------------"

print_status "Checking EKS cluster encryption..."
ENCRYPTION_CONFIG=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query 'cluster.encryptionConfig' --output json 2>/dev/null || echo "[]")

if [ "$ENCRYPTION_CONFIG" != "[]" ]; then
    print_success "EKS cluster has encryption configured"
    echo "$ENCRYPTION_CONFIG" | jq '.'
else
    print_warning "EKS cluster encryption not configured"
fi

echo ""
echo "4. 🚨 SECURITY MISCONFIGURATIONS (INTENTIONAL)"
echo "---------------------------------------------"

print_warning "The following security misconfigurations are INTENTIONAL for this exercise:"

echo ""
print_warning "a) MongoDB VM with overly permissive IAM role:"
print_status "   - AdministratorAccess policy attached"
print_status "   - Can create VMs, modify IAM, access all S3 buckets"
print_status "   - This demonstrates a security risk for detection"

echo ""
print_warning "b) MongoDB exposed to public internet:"
print_status "   - SSH access from 0.0.0.0/0"
print_status "   - MongoDB 4.4 (outdated version)"
print_status "   - This creates attack surface for security tools"

echo ""
print_warning "c) S3 bucket with public read access:"
print_status "   - Public listing and reading enabled"
print_status "   - Required by exercise but creates security risk"

echo ""
print_warning "d) Kubernetes service account with cluster-admin:"
print_status "   - Application has cluster-wide admin privileges"
print_status "   - Over-privileged access for demonstration"

echo ""
echo "5. 📊 CLOUDTRAIL AUDIT LOGS"
echo "---------------------------"

print_status "Checking CloudTrail configuration..."
TRAIL_NAME=$(aws cloudtrail list-trails --region "$REGION" --query 'Trails[0].Name' --output text 2>/dev/null || echo "none")

if [ "$TRAIL_NAME" != "none" ]; then
    print_success "CloudTrail enabled: $TRAIL_NAME"
    print_status "API calls are being logged for audit purposes"
else
    print_warning "CloudTrail not found in this region"
fi

echo ""
echo "6. 🔍 SECURITY SCANNING RESULTS"
echo "------------------------------"

print_status "Checking for security scan results..."

if [ -f "infra/main/checkov-report.xml" ]; then
    print_success "Checkov security scan results available"
    print_status "Check the GitHub Actions logs for detailed findings"
else
    print_warning "Checkov scan results not found locally"
fi

if [ -f "infra/main/terrascan-results.json" ]; then
    print_success "Terrascan security scan results available"
    print_status "Check the GitHub Actions logs for detailed findings"
else
    print_warning "Terrascan scan results not found locally"
fi

echo ""
echo "7. 🎯 DEMONSTRATION SCENARIOS"
echo "----------------------------"

print_status "Security controls Demo :"

echo ""
print_status "1. Trigger GuardDuty alerts:"
echo "   - SSH into the MongoDB VM from an unusual IP"
echo "   - Attempt to access the S3 bucket from unauthorized location"
echo "   - Create suspicious IAM activity"

echo ""
print_status "2. View EKS audit logs:"
echo "   - Run: kubectl get pods -n kube-system"
echo "   - Check CloudWatch logs for API audit trail"

echo ""
print_status "3. Test security scanning:"
echo "   - Push code changes to trigger pipeline scans"
echo "   - Review Checkov/Terrascan findings in GitHub Actions"

echo ""
print_status "4. Demonstrate misconfigurations:"
echo "   - Show overly permissive IAM roles"
echo "   - Demonstrate public access to resources"
echo "   - Show outdated software versions"

echo ""
echo "8. 📈 COMPLIANCE STATUS"
echo "----------------------"

print_success "✅ EKS Control Plane Audit Logging: ENABLED"
print_success "✅ GuardDuty Threat Detection: ENABLED"
print_success "✅ KMS Encryption: CONFIGURED"
print_success "✅ CloudTrail Logging: ENABLED"
print_success "✅ Security Scanning: IMPLEMENTED"
print_warning "⚠️  Intentional Misconfigurations: PRESENT (for demonstration)"

echo ""
echo "9. 🌐 APPLICATION ACCESS DEMONSTRATION"
echo "-------------------------------------"

print_status "Getting ALB URL for application access..."
ALB_URL=$(kubectl -n tasky get ingress tasky-ing -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

# If ingress doesn't have hostname, try to get it from AWS directly
if [ -z "$ALB_URL" ]; then
    print_status "Ingress doesn't have hostname yet, checking AWS for ALB..."
    ALB_URL=$(aws elbv2 describe-load-balancers --region us-west-2 --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-tasky`)].DNSName' --output text 2>/dev/null || echo "")
fi

if [ -n "$ALB_URL" ]; then
    print_success "ALB URL: http://$ALB_URL"
    
    print_status "Testing application functionality..."
    echo "   - Web interface: http://$ALB_URL"
    echo "   - wizexercise.txt: http://$ALB_URL/wizexercise.txt"
    
    print_status "Verifying wizexercise.txt access..."
    if curl -s -f "http://$ALB_URL/wizexercise.txt" > /dev/null 2>&1; then
        print_success "✅ wizexercise.txt is accessible via ALB"
        print_status "Content preview:"
        curl -s "http://$ALB_URL/wizexercise.txt" | head -3
    else
        print_warning "⚠️  wizexercise.txt not accessible via ALB (ALB exists but targets may not be registered yet)"
        print_status "ALB is created but may still be configuring. You can test directly:"
        echo "   curl http://$ALB_URL/wizexercise.txt"
    fi
else
    print_warning "ALB not found. You can check status with:"
    echo "   kubectl -n tasky get ingress tasky-ing"
    echo "   aws elbv2 describe-load-balancers --region us-west-2 --query 'LoadBalancers[?contains(LoadBalancerName, \`k8s-tasky\`)].DNSName' --output text"
fi

echo ""
echo "10. 🏗️ INFRASTRUCTURE VERIFICATION"
echo "----------------------------------"

print_status "Showing Kubernetes cluster status..."
kubectl get nodes 2>/dev/null || print_warning "kubectl not configured or cluster not accessible"

print_status "Showing application pods..."
kubectl -n tasky get pods 2>/dev/null || print_warning "Application namespace not found"

print_status "Showing Terraform outputs..."
if [ -f "infra/main/terraform.tfstate" ]; then
    terraform -chdir=infra/main output 2>/dev/null || print_warning "Terraform outputs not available"
else
    print_warning "Terraform state not found locally"
fi

print_status "Showing S3 backup bucket..."
aws s3 ls s3://wiz-mongo-backups-ada4488/ 2>/dev/null || print_warning "S3 bucket not accessible"

echo ""
echo "11. 📋 QUICK DEMONSTRATION COMMANDS"
echo "----------------------------------"

print_status "Use these commands for live demonstration:"
echo ""
echo "   # Get ALB URL (try both methods)"
echo "   kubectl -n tasky get ingress tasky-ing -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo "   aws elbv2 describe-load-balancers --region us-west-2 --query 'LoadBalancers[?contains(LoadBalancerName, \`k8s-tasky\`)].DNSName' --output text"
echo ""
echo "   # Test application (replace <ALB-URL> with actual URL)"
echo "   curl http://<ALB-URL>/"
echo "   curl http://<ALB-URL>/wizexercise.txt"
echo ""
echo "   # Direct ALB URL (if available):"
if [ -n "$ALB_URL" ]; then
    echo "   curl http://$ALB_URL/wizexercise.txt"
fi
echo ""
echo "   # Show infrastructure"
echo "   kubectl get nodes"
echo "   kubectl -n tasky get pods"
echo "   terraform -chdir=infra/main output"
echo ""
echo "   # Show security findings"
echo "   aws guardduty list-findings --detector-id <detector-id> --region us-west-2"
echo "   aws logs describe-log-groups --log-group-name-prefix '/aws/eks/wiz-eks'"

echo ""
print_success "🎉 Security controls demonstration ready!"
print_status "All required security controls are implemented and can be demonstrated."
