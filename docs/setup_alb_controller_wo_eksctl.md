# Setting up AWS Load Balancer Controller Without eksctl

This guide provides instructions for installing the AWS Load Balancer Controller on an EKS cluster without using eksctl. It follows the official documentation from [kubernetes-sigs.github.io/aws-load-balancer-controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/installation/#option-a-iam-roles-for-service-accounts-irsa).

## Prerequisites

- An EKS cluster
- kubectl configured to communicate with your cluster
- AWS CLI installed and configured
- Helm (optional, for Helm installation method)
- OpenSSL command-line tool

## Installation Steps

### Step 1: Create IAM Policy

First, create an IAM policy that defines the permissions needed by the AWS Load Balancer Controller:

```bash
# Download the IAM policy document
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json
```

### Step 2: Create IAM Role and Trust Policy

Create an IAM role and establish a trust relationship with the OIDC provider:

```bash
# Get the OIDC provider URL for your cluster
aws eks describe-cluster --name eks-stack-eks-cluster --query "cluster.identity.oidc.issuer" --output text

# Create a trust policy file (trust-policy.json)
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "OIDC_PROVIDER:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "OIDC_PROVIDER:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Replace placeholders in the trust policy
OIDC_PROVIDER=$(aws eks describe-cluster --name eks-stack-eks-cluster --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i -e "s|OIDC_PROVIDER|$OIDC_PROVIDER|g" -e "s|ACCOUNT_ID|$ACCOUNT_ID|g" trust-policy.json

# Create the IAM role
aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file://trust-policy.json

# Attach the IAM policy to the role
aws iam attach-role-policy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
```

### Step 3: Create Service Account

Create a Kubernetes service account for the AWS Load Balancer Controller and annotate it with the IAM role ARN:

```bash
# Create a service account YAML file
cat > aws-load-balancer-controller-service-account.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole
EOF

# Replace the account ID
sed -i -e "s|ACCOUNT_ID|$ACCOUNT_ID|g" aws-load-balancer-controller-service-account.yaml

# Apply the service account
kubectl apply -f aws-load-balancer-controller-service-account.yaml
```

### Step 4: Install AWS Load Balancer Controller

You can install the controller using either Helm or by applying the controller manifests directly.

#### Option A: Install using Helm

```bash
# Add the EKS chart repository
helm repo add eks https://aws.github.io/eks-charts

# Update the repository
helm repo update eks

# Install the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=eks-stack-eks-cluster \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
```

#### Option B: Install using Kubernetes Manifests

```bash
# Download the controller specification
curl -Lo controller-v2.4.7.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.7/v2_4_7_full.yaml

# Edit the controller specification to use the correct cluster name
sed -i -e "s|your-cluster-name|eks-stack-eks-cluster|g" controller-v2.4.7.yaml

# Remove the service account section from the controller specification
# (since we've already created it with the IAM role annotation)
sed -i -e '1,/---/d' -e '/^---/,/^---/d' controller-v2.4.7.yaml

# Apply the controller specification
kubectl apply -f controller-v2.4.7.yaml
```

### Step 5: Verify the Installation

Check if the controller is running:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

You should see the controller running with available replicas.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                       Manual Setup Architecture                                 │
│                                                                                 │
├───────────────────┐          ┌───────────────────┐          ┌───────────────────┤
│                   │          │                   │          │                   │
│  IAM Policy       │──────────►  IAM Role         │◄─────────┤  OIDC Provider    │
│                   │  Attach  │                   │  Trust   │                   │
│                   │          │                   │          │                   │
└───────────────────┘          └─────────┬─────────┘          └───────────────────┘
                                         │
                                         │ Referenced by
                                         │
                                         ▼
┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐
│                   │          │                   │          │                   │
│  Kubernetes       │◄─────────┤  Service Account  │──────────►  Controller       │
│  API Server       │  Auth    │  Annotation      │  Uses     │  Deployment       │
│                   │          │                   │          │                   │
└───────────────────┘          └───────────────────┘          └───────────────────┘
```

## Comparison with eksctl Method

| Manual Method | eksctl Method |
|---------------|---------------|
| More steps and manual configuration | Fewer commands and automated setup |
| Greater control over each component | Simplified workflow |
| No dependency on eksctl | Requires eksctl installation |
| Better for understanding the underlying components | Better for quick deployment |
| Useful in environments where eksctl cannot be used | Recommended for standard EKS setups |

## Key Differences from eksctl Approach

1. **Manual OIDC Provider Setup**: Instead of using `eksctl utils associate-iam-oidc-provider`, you need to extract the OIDC provider URL and create the trust relationship manually.

2. **Manual IAM Role Creation**: Instead of using `eksctl create iamserviceaccount`, you create the IAM role and trust policy directly with AWS CLI commands.

3. **Manual Service Account Creation**: You create and annotate the Kubernetes service account yourself instead of having eksctl do it.

4. **More Detailed Control**: This approach gives you more granular control over each component of the setup.

## Troubleshooting

1. **OIDC Provider Issues**: Ensure the OIDC provider URL is correctly formatted in the trust policy.

2. **Service Account Annotation**: Verify the service account has the correct IAM role ARN annotation.

3. **IAM Role Trust Relationship**: Check that the trust relationship includes the correct OIDC provider and conditions.

4. **Controller Not Starting**: Check the controller logs for permission issues:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

## Additional Resources

- [Official AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
- [AWS IAM Roles for Service Accounts Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [AWS Load Balancer Controller GitHub Repository](https://github.com/kubernetes-sigs/aws-load-balancer-controller)
