<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# EKS Deployment Documentation

## Deployment Process

The EKS cluster is deployed using CloudFormation templates from an EC2 instance with an instance profile that has the necessary permissions.

```bash
aws cloudformation create-stack \
 --stack-name eks-stack \
 --template-body file://template/2-eks.yaml \
 --capabilities CAPABILITY_NAMED_IAM \
 --region us-west-2
```

## Role Assumption for AWS Console Access

### Background
The EKS cluster is deployed using the EC2 instance profile with role `code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk`. When accessing the AWS Console with a different IAM role, you won't have permissions to view EKS nodes and pods.

### Current Setup
- **Deployment Role (EC2 Instance Profile)**: `code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk`
- **AWS Account ID**: XXXXXXXXXXXX (anonymized for security)

### Solution 1: Role Assumption Process

```
┌───────────────────┐     assumes     ┌───────────────────┐     accesses     ┌───────────────────┐
│                   │                 │                   │                  │                   │
│   Console User    │ ─────────────► │  Deployment Role  │ ───────────────► │   EKS Cluster     │
│                   │                 │                   │                  │                   │
└───────────────────┘                 └───────────────────┘                  └───────────────────┘
```

#### 1. Create a Trust Relationship

Edit the trust policy of the `code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk` role to allow the console user's role to assume it:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::XXXXXXXXXXXX:role/ConsoleUserRole"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

To update the trust policy:

```bash
aws iam update-assume-role-policy \
  --role-name code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk \
  --policy-document file://trust-policy.json
```

#### 2. Create a Permission Policy for the Console User

The console user's role needs permission to assume the deployment role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::XXXXXXXXXXXX:role/code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk"
    }
  ]
}
```

#### 3. Assume Role in AWS Console

- In the AWS Console, click on your username in the top-right corner
- Select "Switch Role"
- Enter the following details:
  - **Account**: XXXXXXXXXXXX
  - **Role**: code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk
  - **Display Name**: EKS Admin (or any preferred name)
- Click "Switch Role"

#### 4. Access EKS Resources

- After assuming the role, navigate to the EKS console
- You should now be able to view and manage the EKS cluster, nodes, and pods

### Solution 2: Configure aws-auth ConfigMap

```
┌───────────────────┐                 ┌───────────────────┐                  ┌───────────────────┐
│                   │                 │                   │                  │                   │
│   Console User    │ ─────────────► │   aws-auth        │ ───────────────► │   EKS Cluster     │
│                   │   mapped in    │   ConfigMap       │    grants        │                   │
└───────────────────┘                 └───────────────────┘    access        └───────────────────┘
```

This approach modifies the EKS cluster's authentication configuration to recognize and grant permissions to the console user's role directly.

#### 1. Get Current aws-auth ConfigMap

First, ensure you have kubectl configured to access your EKS cluster:

```bash
aws eks update-kubeconfig --name eks-stack --region us-west-2
```

Then, get the current ConfigMap:

```bash
kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml
```

#### 2. Edit the ConfigMap

Add the console user's role to the `mapRoles` section:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::XXXXXXXXXXXX:role/code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    # Add the console user's role here
    - rolearn: arn:aws:iam::XXXXXXXXXXXX:role/ConsoleUserRole
      username: console-user
      groups:
        - system:masters  # Grants full admin access (use more restrictive groups in production)
```

#### 3. Apply the Updated ConfigMap

```bash
kubectl apply -f aws-auth.yaml
```

#### 4. Verify Access

The console user should now be able to access the EKS cluster directly through the AWS Console without needing to switch roles.

### Comparison of Solutions

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                           EKS Access Solutions                                  │
│                                                                                 │
├─────────────────────────────────┬───────────────────────────────────────────────┤
│                                 │                                               │
│     Solution 1: Role Assumption │     Solution 2: aws-auth ConfigMap            │
│                                 │                                               │
├─────────────────────────────────┼───────────────────────────────────────────────┤
│ + No changes to EKS cluster     │ + Direct access without role switching        │
│ + Temporary access              │ + Persistent access configuration             │
│ - Requires manual role switching│ - Requires kubectl access to update ConfigMap │
│ - More steps for users          │ - Changes cluster configuration               │
│                                 │                                               │
└─────────────────────────────────┴───────────────────────────────────────────────┘
```

## Security Considerations

- Always follow the principle of least privilege when granting permissions
- For the aws-auth ConfigMap approach, consider using more restrictive groups than `system:masters`
- Regularly audit access permissions and remove unnecessary access
- Consider implementing additional security controls for production environments
- Use temporary credentials when possible
- Enable CloudTrail logging to monitor role assumption activities
