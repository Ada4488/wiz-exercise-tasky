#!/bin/bash

# Create aws-auth ConfigMap using AWS CLI and curl
CLUSTER_NAME="wiz-eks"
REGION="us-west-2"
USER_ARN="arn:aws:iam::307946653798:user/odl_user_1839486"

# Get cluster endpoint and certificate
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.endpoint' --output text)
CLUSTER_CA=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.certificateAuthority.data' --output text)

# Get authentication token
TOKEN=$(aws eks get-token --cluster-name $CLUSTER_NAME --region $REGION | jq -r '.status.token')

# Create aws-auth ConfigMap JSON
cat > aws-auth-configmap.json << EOF
{
  "apiVersion": "v1",
  "kind": "ConfigMap",
  "metadata": {
    "name": "aws-auth",
    "namespace": "kube-system"
  },
  "data": {
    "mapRoles": "- rolearn: arn:aws:iam::307946653798:role/wiz-eks-cluster\n  username: system:node:{{EC2PrivateDNSName}}\n  groups:\n    - system:bootstrappers\n    - system:nodes\n",
    "mapUsers": "- userarn: $USER_ARN\n  username: admin\n  groups:\n    - system:masters\n"
  }
}
EOF

# Try to create the ConfigMap
echo "Attempting to create aws-auth ConfigMap..."
curl -k -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST \
  -d @aws-auth-configmap.json \
  "$CLUSTER_ENDPOINT/api/v1/namespaces/kube-system/configmaps"

echo ""
echo "If the above failed, try running this manually in AWS CloudShell or with proper credentials."
