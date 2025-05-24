<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Deploying Go Bedrock Application to Amazon EKS

This document provides detailed instructions for deploying the Go Bedrock application to Amazon EKS with the necessary IAM permissions to access Amazon Bedrock foundational models.

## Overview

The Go Bedrock application is a containerized Go application that interacts with Amazon Bedrock to access foundation models. This deployment guide covers:

1. Creating the necessary IAM roles and service accounts
2. Deploying the application with Kubernetes
3. Exposing the application using AWS Load Balancer Controller
4. Troubleshooting common deployment issues

## Prerequisites

- Access to an Amazon EKS cluster
- `kubectl` CLI configured to access your cluster
- `eksctl` CLI installed
- Docker image of the Go Bedrock application pushed to Amazon ECR
- AWS Load Balancer Controller installed on the EKS cluster

## Deployment Files

The deployment uses several YAML files:

1. **Deployment Manifest** (`yaml/go-bedrock-app-deployment.yaml`): Defines the application deployment
2. **Service Manifest** (`yaml/go-bedrock-app-service.yaml`): Exposes the application via AWS Load Balancer Controller
3. **Service Account Configuration** (`yaml/go-bedrock-app-iam-role.yaml`): Configures IAM roles for the service account
4. **IAM Policy** (`yaml/go-bedrock-app-iam-policy.json`): Defines the permissions for accessing Amazon Bedrock

## Service Account and IAM Role Setup

### Understanding Kubernetes Service Accounts with IAM Roles

A Kubernetes Service Account provides an identity for processes that run in a Pod. When integrated with AWS IAM roles through IRSA (IAM Roles for Service Accounts), it allows pods to securely access AWS services without storing AWS credentials in the application code or as Kubernetes secrets.

Key components:
- **Service Account**: Kubernetes resource that provides an identity for pods
- **IAM Role**: AWS IAM role with specific permissions
- **OIDC Provider**: Connects Kubernetes service accounts to AWS IAM roles
- **Trust Relationship**: Allows the service account to assume the IAM role

### How Service Accounts and IAM Roles Work Together

```
┌─────────────────────────────────────────────────────────────────┐
│                      Amazon EKS Cluster                         │
│                                                                 │
│  ┌─────────────────┐      ┌───────────────────────────────┐     │
│  │                 │      │                               │     │
│  │    Pod          │      │  Kubernetes API Server        │     │
│  │                 │      │                               │     │
│  │  ┌───────────┐  │      │                               │     │
│  │  │Application│  │      │                               │     │
│  │  └───────────┘  │      │                               │     │
│  │        │        │      │                               │     │
│  │        ▼        │      │                               │     │
│  │  ┌───────────┐  │      │  ┌─────────────────────────┐  │     │
│  │  │AWS SDK    │──┼──────┼─▶│Service Account          │  │     │
│  │  └───────────┘  │      │  │(go-bedrock-service-     │  │     │
│  │        │        │      │  │account)                 │  │     │
│  └────────┼────────┘      │  └────────────┬────────────┘  │     │
│           │               │               │               │     │
└───────────┼───────────────┼───────────────┼───────────────┘     │
            │               │               │                     │
            │               │               │                     │
            │               │               ▼                     │
            │               │    ┌─────────────────────┐          │
            │               │    │  OIDC Provider      │          │
            │               │    └──────────┬──────────┘          │
            │               │               │                     │
┌───────────┼───────────────┼───────────────┼─────────────────────┘
│           │               │               │
│ AWS       │               │               │
│           ▼               │               ▼
│  ┌─────────────────┐      │      ┌─────────────────┐
│  │ AWS Bedrock     │      │      │ IAM Role        │
│  │ Service         │◀─────┴──────│ (with Bedrock   │
│  └─────────────────┘             │  permissions)   │
│                                  └─────────────────┘
└─────────────────────────────────────────────────────
```

**Flow:**
1. The pod runs with a Kubernetes service account identity
2. When the application makes an AWS API call, the AWS SDK:
   - Retrieves a web identity token from the service account token file
   - Uses this token to assume the IAM role via AWS STS
3. The IAM role has a trust relationship with the OIDC provider, allowing only pods using the specific service account to assume the role
4. The assumed role provides temporary credentials that the SDK uses to access AWS services (Bedrock)
5. The IAM role's permissions policy determines what AWS resources the pod can access

### Setting Up OIDC for the EKS Cluster

Before creating service accounts with IAM roles, the EKS cluster must have an OIDC provider configured:

```bash
eksctl utils associate-iam-oidc-provider --cluster your-cluster-name --region your-region --approve
```

### Creating the IAM Role and Service Account

The service account and IAM role are defined in a YAML file:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: your-cluster-name
  region: your-region
iam:
  withOIDC: true  # This is crucial for enabling IAM roles for service accounts
  serviceAccounts:
  - metadata:
      name: go-bedrock-service-account
      namespace: default
    roleName: go-bedrock-app-role
    attachPolicy:
      Version: "2012-10-17"
      Statement:
      - Effect: Allow
        Action:
        - "bedrock:InvokeModel"
        - "bedrock:InvokeModelWithResponseStream"
        Resource:
        - "arn:aws:bedrock:your-region::foundation-model/*"
      - Effect: Allow
        Action:
        - "bedrock:ListFoundationModels"
        - "bedrock:GetFoundationModel"
        Resource: "*"
```

To create the service account and IAM role:

```bash
eksctl create iamserviceaccount -f yaml/go-bedrock-app-iam-role.yaml --approve
```

This command:
1. Creates an IAM role with the specified permissions
2. Creates a trust relationship allowing the service account to assume the role
3. Creates a Kubernetes service account with annotations linking it to the IAM role

### Creating Service Account and IAM Role Without eksctl

If you prefer not to use eksctl, you can create the IAM role and service account manually:

#### 1. Create the IAM Policy

```bash
# Create the IAM policy
aws iam create-policy \
  --policy-name BedrockAccessPolicy \
  --policy-document file://yaml/go-bedrock-app-iam-policy.json
```

#### 2. Get the OIDC Provider URL

```bash
# Get the OIDC provider URL for your EKS cluster
OIDC_PROVIDER=$(aws eks describe-cluster \
  --name your-cluster-name \
  --region your-region \
  --query "cluster.identity.oidc.issuer" \
  --output text | sed -e "s/^https:\/\///")

# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

#### 3. Create the IAM Role with Trust Relationship

Create a file named `trust-relationship.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/<OIDC_PROVIDER>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "<OIDC_PROVIDER>:sub": "system:serviceaccount:default:go-bedrock-service-account",
          "<OIDC_PROVIDER>:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Create the IAM role:

```bash
# Replace variables in the trust relationship document
sed -i "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" trust-relationship.json
sed -i "s/<OIDC_PROVIDER>/$OIDC_PROVIDER/g" trust-relationship.json

# Create the IAM role
aws iam create-role \
  --role-name go-bedrock-app-role \
  --assume-role-policy-document file://trust-relationship.json

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name go-bedrock-app-role \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/BedrockAccessPolicy
```

#### 4. Create the Kubernetes Service Account

Create a file named `service-account.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: go-bedrock-service-account
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/go-bedrock-app-role
```

Apply the service account:

```bash
# Replace the account ID in the service account YAML
sed -i "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" service-account.yaml

# Create the service account
kubectl apply -f service-account.yaml
```

## Deployment Configuration

### Deployment Manifest

The deployment manifest specifies:
- The container image to use
- Resource requirements
- Health checks
- Environment variables
- The service account to use

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-bedrock-app
  namespace: default
  labels:
    app: go-bedrock-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: go-bedrock-app
  template:
    metadata:
      labels:
        app: go-bedrock-app
    spec:
      serviceAccountName: go-bedrock-service-account  # This links the pod to the service account
      containers:
      - name: go-bedrock-app
        image: <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/go-bedrock-app:v4
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        env:
        - name: AWS_REGION
          value: "<REGION>"
```

### Service Manifest

The service manifest uses AWS Load Balancer Controller annotations to create a Network Load Balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-bedrock-service
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "http"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "3000"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "15"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
spec:
  selector:
    app: go-bedrock-app
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
```

## Deployment Process

### 1. Create the IAM Role and Service Account

```bash
eksctl create iamserviceaccount -f yaml/go-bedrock-app-iam-role.yaml --approve
```

### 2. Deploy the Application

```bash
kubectl apply -f yaml/go-bedrock-app-deployment.yaml
```

### 3. Create the Service

```bash
kubectl apply -f yaml/go-bedrock-app-service.yaml
```

### 4. Verify the Deployment

```bash
kubectl get pods -l app=go-bedrock-app
kubectl get service go-bedrock-service
```

## Troubleshooting Common Issues

### Issue: OIDC Provider Not Configured

**Error Message:**
```
Error: iam.withOIDC must be enabled explicitly for iam.serviceAccounts to be created
```

**Solution:**
1. Enable OIDC for the EKS cluster:
   ```bash
   eksctl utils associate-iam-oidc-provider --cluster your-cluster-name --region your-region --approve
   ```
2. Update the YAML file to include `withOIDC: true` in the iam section:
   ```yaml
   iam:
     withOIDC: true
     serviceAccounts:
     # ...
   ```

### Issue: Service Account Already Exists

**Error Message:**
```
serviceaccounts that exist in Kubernetes will be excluded
```

**Solution:**
1. Delete the existing service account:
   ```bash
   kubectl delete serviceaccount go-bedrock-service-account
   ```
2. Recreate the service account with IAM role:
   ```bash
   eksctl create iamserviceaccount -f yaml/go-bedrock-app-iam-role.yaml --approve
   ```

### Issue: Container Security Context Error

**Error Message:**
```
Error: container has runAsNonRoot and image has non-numeric user (nonroot), cannot verify user is non-root
```

**Solution:**
1. Remove the securityContext section from the deployment YAML:
   ```yaml
   # Remove this section
   securityContext:
     runAsNonRoot: true
     allowPrivilegeEscalation: false
     capabilities:
       drop:
       - ALL
   ```
2. Apply the updated deployment:
   ```bash
   kubectl apply -f yaml/go-bedrock-app-deployment-fixed.yaml
   ```

This error occurs because the container image uses a non-numeric user named "nonroot", but Kubernetes expects a numeric user ID when `runAsNonRoot: true` is specified.

## Verifying AWS Permissions

To verify that the pods can access Amazon Bedrock:

1. Check if the service account has the correct annotations:
   ```bash
   kubectl get serviceaccount go-bedrock-service-account -o yaml
   ```
   
   Look for the annotation:
   ```
   eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/go-bedrock-app-role
   ```

2. Check the pod's environment variables:
   ```bash
   kubectl exec -it <pod-name> -- env | grep AWS
   ```
   
   You should see environment variables like:
   ```
   AWS_ROLE_ARN=arn:aws:iam::<ACCOUNT_ID>:role/go-bedrock-app-role
   AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
   ```

## Accessing the Application

Once deployed, the application is accessible via the Network Load Balancer's DNS name:

```bash
kubectl get service go-bedrock-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Example URL:
```
http://k8s-default-gobedroc-xxxxxxxx.<REGION>.elb.amazonaws.com
```

## Verifying AWS Credentials Inside the Pod

To better understand how the service account and IAM role integration works, you can access a pod and verify the AWS credentials it's using. This is useful for troubleshooting and confirming that the pod has the correct permissions to access AWS services.

### Accessing a Pod

First, get the name of one of your running pods:

```bash
kubectl get pods -l app=go-bedrock-app
```

Example output:
```
NAME                              READY   STATUS    RESTARTS   AGE
go-bedrock-app-68f7dff78f-6rpzx   1/1     Running   0          10m
go-bedrock-app-68f7dff78f-b5ptp   1/1     Running   0          10m
```

Access the pod using the `kubectl exec` command:

```bash
kubectl exec -it go-bedrock-app-68f7dff78f-6rpzx -- /bin/sh
```

If the container doesn't have a shell, you might need to use:

```bash
kubectl exec -it go-bedrock-app-68f7dff78f-6rpzx -- /bin/bash
```

### Verifying AWS Identity

Once inside the pod, you can verify the AWS identity that the pod is assuming:

```bash
# Check environment variables related to AWS credentials
env | grep AWS
```

Example output:
```
AWS_ROLE_ARN=arn:aws:iam::<ACCOUNT_ID>:role/go-bedrock-app-role
AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

These environment variables are automatically set by the EKS Pod Identity Webhook when using IAM roles for service accounts.

### Calling AWS STS to Verify Identity

If the AWS CLI is installed in the container, you can directly verify the identity:

```bash
aws sts get-caller-identity
```

Example output:
```json
{
    "UserId": "AROA1EXAMPLE:botocore-session-1234567890",
    "Account": "<ACCOUNT_ID>",
    "Arn": "arn:aws:sts::<ACCOUNT_ID>:assumed-role/go-bedrock-app-role/botocore-session-1234567890"
}
```

This confirms that the pod is successfully assuming the IAM role.

### If AWS CLI is Not Available

If the AWS CLI is not available in the container, you can install it or use the AWS SDK in your application code to verify the identity. Here's a simple example using Python:

```python
import boto3
import json

sts_client = boto3.client('sts')
identity = sts_client.get_caller_identity()
print(json.dumps(identity, default=str))
```

### Testing Access to Amazon Bedrock

To verify that the pod has the correct permissions to access Amazon Bedrock, you can make a simple API call:

```bash
# If AWS CLI is available and configured for Bedrock
aws bedrock list-foundation-models --region <REGION>
```

Or using Python:

```python
import boto3
import json

bedrock_client = boto3.client('bedrock', region_name='<REGION>')
models = bedrock_client.list_foundation_models()
print(json.dumps(models, default=str))
```

### Understanding the Authentication Flow

When you run these commands inside the pod:

1. The AWS SDK or CLI detects the `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` environment variables
2. It reads the web identity token from the file path specified in `AWS_WEB_IDENTITY_TOKEN_FILE`
3. It calls the AWS STS `AssumeRoleWithWebIdentity` API with:
   - The role ARN from `AWS_ROLE_ARN`
   - The web identity token from the file
4. AWS STS verifies the token with the OIDC provider and returns temporary credentials
5. The SDK or CLI uses these temporary credentials to make API calls to AWS services

This process happens automatically and is transparent to your application code, making it a secure way to access AWS services without managing credentials.

## Conclusion

This deployment provides a secure way for the Go Bedrock application to access Amazon Bedrock foundational models without embedding AWS credentials in the application. The IAM role is assumed by the pod through the service account, providing fine-grained access control and following security best practices.

By using the AWS Load Balancer Controller, the application is exposed through a Network Load Balancer, providing high availability and efficient load distribution.
