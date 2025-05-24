<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Deploying AWS CLI Pod with IAM Role in EKS

This document explains how to deploy an AWS CLI container as a pod in an EKS cluster with appropriate IAM permissions using IAM Roles for Service Accounts (IRSA).

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                       AWS CLI Pod with IRSA Architecture                        │
│                                                                                 │
├───────────────────┐          ┌───────────────────┐          ┌───────────────────┤
│                   │          │                   │          │                   │
│  IAM Policy       │──────────►  IAM Role         │◄─────────┤  EKS OIDC         │
│  (S3 Admin)       │  Attach  │                   │  Trust   │  Provider         │
│                   │          │                   │          │                   │
└───────────────────┘          └─────────┬─────────┘          └───────────────────┘
                                         │
                                         │ Referenced by
                                         │
                                         ▼
┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐
│                   │          │                   │          │                   │
│  Kubernetes       │◄─────────┤  Service Account  │──────────►  AWS CLI Pod      │
│  API Server       │  Auth    │  with Annotation  │  Uses    │                   │
│                   │          │                   │          │                   │
└───────────────────┘          └───────────────────┘          └───────────────────┘
```

## Prerequisites

- An EKS cluster with OIDC provider configured
- kubectl configured to communicate with your cluster
- AWS CLI installed and configured with appropriate permissions

## Step 1: Create IAM Policy for S3 Administration

```bash
# Create IAM policy for S3 administration
aws iam create-policy \
    --policy-name S3AdministrationPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": ["s3:*"],
                "Resource": ["*"]
            }
        ]
    }'
```

Output:
```json
{
    "Policy": {
        "PolicyName": "S3AdministrationPolicy",
        "PolicyId": "ANPAXXXXXXXXXXXXXXXXX",
        "Arn": "arn:aws:iam::XXXXXXXXXXXX:policy/S3AdministrationPolicy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2025-05-17T13:00:10+00:00",
        "UpdateDate": "2025-05-17T13:00:10+00:00"
    }
}
```

## Step 2: Get OIDC Provider Information

```bash
# Get OIDC provider URL for the cluster
aws eks describe-cluster --name eks-stack-eks-cluster --region us-west-2 --query "cluster.identity.oidc.issuer" --output text

# Extract OIDC provider ID
OIDC_PROVIDER=$(aws eks describe-cluster --name eks-stack-eks-cluster --region us-west-2 --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\\/\\///")
echo $OIDC_PROVIDER
```

Output:
```
https://oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647
oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647
```

## Step 3: Create Trust Policy for IAM Role

```bash
# Create trust policy JSON file
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::XXXXXXXXXXXX:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647:sub": "system:serviceaccount:default:aws-cli-sa",
          "oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
```

## Step 4: Create IAM Role and Attach Policy

```bash
# Create IAM role with trust policy
aws iam create-role \
    --role-name EKS-AWS-CLI-S3-Role \
    --assume-role-policy-document file://trust-policy.json

# Attach S3 administration policy to the role
aws iam attach-role-policy \
    --role-name EKS-AWS-CLI-S3-Role \
    --policy-arn arn:aws:iam::XXXXXXXXXXXX:policy/S3AdministrationPolicy
```

Output (create-role):
```json
{
    "Role": {
        "Path": "/",
        "RoleName": "EKS-AWS-CLI-S3-Role",
        "RoleId": "AROAXXXXXXXXXXXXXXXXX",
        "Arn": "arn:aws:iam::XXXXXXXXXXXX:role/EKS-AWS-CLI-S3-Role",
        "CreateDate": "2025-05-17T13:01:09+00:00",
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "arn:aws:iam::XXXXXXXXXXXX:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647:sub": "system:serviceaccount:default:aws-cli-sa",
                            "oidc.eks.us-west-2.amazonaws.com/id/1C7E354E68A5D70F613DDA4637C1F647:aud": "sts.amazonaws.com"
                        }
                    }
                }
            ]
        }
    }
}
```

## Step 5: Create Kubernetes Service Account with IAM Role Annotation

```bash
# Create service account YAML file
cat > aws-cli-sa.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-cli-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::XXXXXXXXXXXX:role/EKS-AWS-CLI-S3-Role"
EOF

# Apply the service account
kubectl apply -f aws-cli-sa.yaml
```

Output:
```
serviceaccount/aws-cli-sa created
```

## Step 6: Deploy AWS CLI Pod

```bash
# Create pod YAML file
cat > aws-cli-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: aws-cli
  namespace: default
spec:
  serviceAccountName: aws-cli-sa
  containers:
  - name: aws-cli
    image: public.ecr.aws/aws-cli/aws-cli:latest
    command:
      - "sleep"
      - "infinity"
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "200m"
EOF

# Apply the pod configuration
kubectl apply -f aws-cli-pod.yaml
```

Output:
```
pod/aws-cli created
```

## Step 7: Wait for Pod to be Ready

```bash
# Wait for the pod to be ready
kubectl wait --for=condition=Ready pod/aws-cli --timeout=60s
```

Output:
```
pod/aws-cli condition met
```

## Step 8: Verify IAM Role Assumption

```bash
# Execute AWS STS get-caller-identity in the pod
kubectl exec -it aws-cli -- aws sts get-caller-identity
```

Output:
```json
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:botocore-session-1747486934",
    "Account": "XXXXXXXXXXXX",
    "Arn": "arn:aws:sts::XXXXXXXXXXXX:assumed-role/EKS-AWS-CLI-S3-Role/botocore-session-1747486934"
}
```

## Step 9: Test S3 Access

```bash
# List S3 buckets
kubectl exec -it aws-cli -- aws s3 ls

# Create a test bucket
kubectl exec -it aws-cli -- aws s3 mb s3://test-bucket-$(date +%s)

# List objects in a bucket
kubectl exec -it aws-cli -- aws s3 ls s3://your-bucket-name

# Upload a file to S3
kubectl exec -it aws-cli -- sh -c "echo 'Hello from EKS' > /tmp/hello.txt && aws s3 cp /tmp/hello.txt s3://your-bucket-name/"

# Download a file from S3
kubectl exec -it aws-cli -- aws s3 cp s3://your-bucket-name/hello.txt /tmp/downloaded.txt
```

## Alternative: Deploy as a Deployment

For a more persistent solution, you can deploy the AWS CLI as a Deployment instead of a single Pod:

```bash
# Create deployment YAML file
cat > aws-cli-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-cli
  namespace: default
  labels:
    app: aws-cli
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aws-cli
  template:
    metadata:
      labels:
        app: aws-cli
    spec:
      serviceAccountName: aws-cli-sa
      containers:
      - name: aws-cli
        image: public.ecr.aws/aws-cli/aws-cli:latest
        command:
          - "sleep"
          - "infinity"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
EOF

# Apply the deployment
kubectl apply -f aws-cli-deployment.yaml
```

## Cleanup

```bash
# Delete the pod
kubectl delete -f aws-cli-pod.yaml

# Delete the service account
kubectl delete -f aws-cli-sa.yaml

# Detach the policy from the role
aws iam detach-role-policy \
    --role-name EKS-AWS-CLI-S3-Role \
    --policy-arn arn:aws:iam::XXXXXXXXXXXX:policy/S3AdministrationPolicy

# Delete the role
aws iam delete-role --role-name EKS-AWS-CLI-S3-Role

# Delete the policy
aws iam delete-policy --policy-arn arn:aws:iam::XXXXXXXXXXXX:policy/S3AdministrationPolicy
```

## Key Concepts

1. **IAM Roles for Service Accounts (IRSA)**: Allows Kubernetes service accounts to assume IAM roles through a trust relationship with the EKS OIDC provider.

2. **Service Account Annotation**: The `eks.amazonaws.com/role-arn` annotation tells the EKS pod identity webhook to configure the AWS SDK in the pod to use the specified IAM role.

3. **OIDC Federation**: The EKS cluster's OIDC provider allows AWS to trust identities from your Kubernetes cluster.

4. **AWS CLI Container**: The official AWS CLI container image provides a convenient way to run AWS CLI commands in Kubernetes.

## Security Considerations

1. **Principle of Least Privilege**: Consider restricting the IAM policy to only the S3 actions and resources needed.

2. **Pod Security**: The AWS CLI pod has access to powerful AWS credentials. Ensure it's deployed in a secure namespace with appropriate RBAC controls.

3. **Credential Rotation**: The temporary credentials are automatically rotated by the AWS SDK.

4. **Audit Logging**: Enable AWS CloudTrail to monitor actions performed using the assumed role.
