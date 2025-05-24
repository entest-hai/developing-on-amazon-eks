<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Pod Identity vs. IAM Roles for Service Accounts (IRSA)

This document compares Pod Identity and IAM Roles for Service Accounts (IRSA) and explains how to use Pod Identity with Amazon CloudWatch Observability.

## Comparison: Pod Identity vs. IRSA

### IAM Roles for Service Accounts (IRSA)

IRSA is the traditional method for providing AWS IAM permissions to pods in an EKS cluster.

**How IRSA Works:**
1. A Kubernetes service account is annotated with an IAM role ARN
2. The EKS pod identity webhook injects AWS credentials into pods that use this service account
3. The AWS SDK in the pod uses these credentials to make AWS API calls

**Key Components:**
- Requires the OpenID Connect (OIDC) provider associated with the EKS cluster
- Uses web identity federation with the AssumeRoleWithWebIdentity API
- Credentials are delivered via environment variables and projected service account tokens

**Example IRSA Configuration:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudwatch-observability
  namespace: amazon-cloudwatch
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/CloudWatchObservabilityRole
```

### Pod Identity

Pod Identity is a newer, more streamlined approach introduced by AWS for EKS clusters.

**How Pod Identity Works:**
1. An EKS Pod Identity association is created, linking a service account to an IAM role
2. The EKS Pod Identity agent (running as a DaemonSet) intercepts AWS API calls from pods
3. The agent automatically exchanges pod identity for temporary AWS credentials

**Key Components:**
- No need for an OIDC provider
- Uses the EKS Pod Identity agent instead of the webhook
- Simplified setup and management
- Reduced latency for credential retrieval
- Better security posture with automatic credential rotation

**Example Pod Identity Configuration:**
```bash
# Create the Pod Identity association
aws eks create-pod-identity-association \
  --cluster-name <CLUSTER_NAME> \
  --namespace amazon-cloudwatch \
  --service-account cloudwatch-observability \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/CloudWatchObservabilityRole
```

## Key Differences

| Feature | IRSA | Pod Identity |
|---------|------|-------------|
| Setup Complexity | Requires OIDC provider setup | Simpler setup, no OIDC required |
| Credential Delivery | Environment variables & projected volumes | Transparent interception of AWS API calls |
| Latency | Higher due to token exchange | Lower latency |
| Security | Good, but credentials exist in pod | Better, credentials never exposed to pod |
| Compatibility | Works with all EKS versions | Requires EKS 1.24+ |
| Configuration | Service account annotations | EKS API configuration |
| Credential Refresh | Requires pod restart for some changes | Automatic and transparent |

## Using Pod Identity with CloudWatch Observability

### Prerequisites
- EKS cluster version 1.24 or later
- EKS Pod Identity agent installed on the cluster
- AWS CLI version that supports Pod Identity commands

### Step 1: Create IAM Policy for CloudWatch Observability

```bash
cat <<EOF > cloudwatch-observability-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "logs:CreateLogStream",
                "logs:CreateLogGroup",
                "logs:PutRetentionPolicy",
                "xray:PutTraceSegments",
                "xray:PutTelemetryRecords",
                "xray:GetSamplingRules",
                "xray:GetSamplingTargets",
                "xray:GetSamplingStatisticSummaries",
                "ssm:GetParameters"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
  --policy-name CloudWatchObservabilityPolicy \
  --policy-document file://cloudwatch-observability-policy.json
```

### Step 2: Create IAM Role for Pod Identity

```bash
# Create IAM role
aws iam create-role \
  --role-name CloudWatchObservabilityPodIdentityRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "pods.eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach policy to role
aws iam attach-role-policy \
  --role-name CloudWatchObservabilityPodIdentityRole \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/CloudWatchObservabilityPolicy
```

### Step 3: Create Namespace and Service Account

```bash
# Create namespace
kubectl create namespace amazon-cloudwatch

# Create service account (without any annotations)
kubectl create serviceaccount cloudwatch-observability -n amazon-cloudwatch
```

### Step 4: Create Pod Identity Association

```bash
aws eks create-pod-identity-association \
  --cluster-name <CLUSTER_NAME> \
  --namespace amazon-cloudwatch \
  --service-account cloudwatch-observability \
  --role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CloudWatchObservabilityPodIdentityRole
```

### Step 5: Install CloudWatch Observability Add-on with Pod Identity

```bash
eksctl create addon \
  --name amazon-cloudwatch-observability \
  --cluster <CLUSTER_NAME> \
  --region <REGION> \
  --configuration-values '{
    "serviceAccount": {
      "name": "cloudwatch-observability",
      "create": false
    }
  }'
```

### Step 6: Verify Pod Identity Association

```bash
# List Pod Identity associations
aws eks list-pod-identity-associations --cluster-name <CLUSTER_NAME>

# Verify the CloudWatch agent pods are running
kubectl get pods -n amazon-cloudwatch
```

## Converting from IRSA to Pod Identity for CloudWatch Observability

If you've already set up CloudWatch Observability using IRSA, you can migrate to Pod Identity:

1. **Delete the existing add-on**:
   ```bash
   eksctl delete addon --name amazon-cloudwatch-observability --cluster <CLUSTER_NAME>
   ```

2. **Remove IRSA annotation from the service account**:
   ```bash
   kubectl patch serviceaccount cloudwatch-observability -n amazon-cloudwatch --type json -p '[{"op": "remove", "path": "/metadata/annotations/eks.amazonaws.com~1role-arn"}]'
   ```

3. **Create Pod Identity association and reinstall the add-on** using the steps above.

## Benefits of Using Pod Identity with CloudWatch Observability

1. **Simplified Management**: No need to manage OIDC providers or deal with token expiration
2. **Improved Performance**: Lower latency for AWS API calls
3. **Enhanced Security**: Credentials are never exposed to the pod environment
4. **Automatic Credential Rotation**: No need to restart pods to refresh credentials
5. **Streamlined Operations**: Easier to audit and manage IAM permissions

## Limitations of Pod Identity

1. **EKS Version Requirement**: Only works with EKS 1.24+
2. **Limited Regional Availability**: Check AWS documentation for current availability
3. **Add-on Support**: Not all add-ons may support Pod Identity yet

## References

- [EKS Pod Identity Documentation](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [IAM Roles for Service Accounts Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [CloudWatch Observability Add-on Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-EKS-addon.html)
- [EKS Pod Identity Webhook GitHub](https://github.com/aws/amazon-eks-pod-identity-webhook)
