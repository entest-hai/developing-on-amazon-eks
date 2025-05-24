<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# CloudWatch Observability Troubleshooting Guide

This document provides troubleshooting steps for issues with the Amazon CloudWatch Observability add-on for EKS.

## Current Issue

The CloudWatch Observability add-on is installed and running, but no metrics or logs are appearing in CloudWatch. The CloudWatch agent pods are running but encountering authentication errors when trying to send data to CloudWatch.

## Diagnosis

After investigating the issue, we found that:

1. The CloudWatch agent pods are running correctly
2. The IAM role and trust relationship are configured properly
3. The service account has the correct annotations
4. The OIDC provider is set up correctly

However, the CloudWatch agent logs show consistent authentication errors:

```
WebIdentityErr: failed to retrieve credentials
caused by: AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

This indicates that the CloudWatch agent is unable to assume the IAM role using web identity federation.

## Root Cause Analysis

The issue appears to be related to how the CloudWatch agent is using the service account token. There are two service accounts in the `amazon-cloudwatch` namespace that are relevant:

1. `cloudwatch-observability` - Created by eksctl with the IAM role annotation
2. `cloudwatch-agent` - Used by the CloudWatch agent pods

The `cloudwatch-agent` service account has been annotated with the same IAM role ARN, but the CloudWatch agent is still encountering authentication issues.

## Solution Steps

To resolve this issue, try the following steps:

### 1. Verify the IAM Role Policy

Ensure the IAM role has the necessary permissions for CloudWatch:

```bash
# Replace <ACCOUNT_ID> with your AWS account ID
aws iam get-policy-version --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/CloudWatchObservabilityPolicy --version-id v1
```

The policy should include permissions for:
- `cloudwatch:PutMetricData`
- `logs:PutLogEvents`
- `logs:CreateLogStream`
- `logs:CreateLogGroup`

### 2. Update the Trust Relationship with Namespace Wildcard

Update the trust relationship to allow any service account in the `amazon-cloudwatch` namespace to assume the role:

```bash
cat <<EOF > updated-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:amazon-cloudwatch:*"
        }
      }
    }
  ]
}
EOF

# Replace <ROLE_NAME> with your IAM role name
aws iam update-assume-role-policy --role-name <ROLE_NAME> --policy-document file://updated-trust-policy.json
```

### 3. Restart the CloudWatch Agent Pods

After updating the trust relationship, restart the CloudWatch agent pods:

```bash
kubectl delete pods -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent
```

### 4. Check for AWS Region Mismatch

Verify that the AWS region in the CloudWatch agent configuration matches the region where your EKS cluster is running:

```bash
kubectl get configmap -n amazon-cloudwatch cloudwatch-agent -o yaml
```

Ensure the region is set to your cluster's region.

### 5. Check for CloudWatch Endpoint Issues

If you're using VPC endpoints or have network restrictions, ensure that the CloudWatch agent can reach the CloudWatch and CloudWatch Logs endpoints:

```bash
# Replace <REGION> with your AWS region and <POD_NAME> with your actual pod name
kubectl exec -n amazon-cloudwatch <POD_NAME> -- curl -v https://logs.<REGION>.amazonaws.com
kubectl exec -n amazon-cloudwatch <POD_NAME> -- curl -v https://monitoring.<REGION>.amazonaws.com
```

### 6. Recreate the Add-on with Default Service Account

If the above steps don't resolve the issue, try recreating the add-on without specifying a custom service account:

```bash
# Replace <CLUSTER_NAME> and <REGION> with your values
eksctl delete addon --name amazon-cloudwatch-observability --cluster <CLUSTER_NAME> --region <REGION>

eksctl create addon \
  --name amazon-cloudwatch-observability \
  --cluster <CLUSTER_NAME> \
  --region <REGION>
```

## Verification

After implementing the solution, verify that the CloudWatch agent is working correctly:

1. Check the CloudWatch agent logs for authentication errors:
   ```bash
   kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent
   ```

2. Check if log groups are being created in CloudWatch Logs:
   ```bash
   # Replace <CLUSTER_NAME> and <REGION> with your values
   aws logs describe-log-groups --log-group-name-prefix "/aws/containerinsights/<CLUSTER_NAME>" --region <REGION>
   ```

3. Check if metrics are appearing in CloudWatch Container Insights:
   ```bash
   # Replace <REGION> with your AWS region
   aws cloudwatch list-metrics --namespace ContainerInsights --region <REGION>
   ```

## Additional Resources

- [Amazon CloudWatch Observability EKS Add-on Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-EKS-addon.html)
- [IAM Roles for Service Accounts (IRSA) Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Troubleshooting EKS IAM Authentication](https://aws.amazon.com/premiumsupport/knowledge-center/eks-troubleshoot-oidc-and-irsa/)
- [AWS CloudWatch Container Insights Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
