# AWS CLI Pod with S3 Administration Permissions

This directory contains YAML files to deploy an AWS CLI pod with S3 administration permissions in your EKS cluster.

## Files

- `aws-cli-sa.yaml`: Service account with IAM role annotation
- `aws-cli-pod.yaml`: Pod definition using the AWS CLI image
- `aws-cli-deployment.yaml`: Deployment definition (alternative to single pod)
- `trust-policy.json`: IAM role trust policy for OIDC federation

## IAM Resources Created

- **Policy**: `S3AdministrationPolicy` with full S3 permissions
- **Role**: `EKS-AWS-CLI-S3-Role` with trust relationship to the EKS OIDC provider

## How to Use

### 1. Deploy the Service Account and Pod

```bash
kubectl apply -f aws-cli-sa.yaml
kubectl apply -f aws-cli-pod.yaml
```

### 2. Verify the Pod is Running

```bash
kubectl get pods | grep aws-cli
```

### 3. Execute AWS CLI Commands in the Pod

```bash
# Check the identity being used
kubectl exec -it aws-cli -- aws sts get-caller-identity

# List S3 buckets
kubectl exec -it aws-cli -- aws s3 ls

# Run other AWS CLI commands
kubectl exec -it aws-cli -- aws s3 mb s3://test-bucket-$(date +%s)
```

### 4. Deploy as a Deployment (Optional)

If you want to deploy as a Deployment instead of a single Pod:

```bash
kubectl apply -f aws-cli-deployment.yaml
```

## Verification

The pod is using the IAM role `EKS-AWS-CLI-S3-Role` which has full S3 administration permissions. You can verify this by running:

```bash
kubectl exec -it aws-cli -- aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AROAXZRYMB5ABB4UTHT7U:botocore-session-1747486934",
    "Account": "535915401024",
    "Arn": "arn:aws:sts::535915401024:assumed-role/EKS-AWS-CLI-S3-Role/botocore-session-1747486934"
}
```

## Cleanup

To remove the resources:

```bash
kubectl delete -f aws-cli-pod.yaml
kubectl delete -f aws-cli-sa.yaml
```

To remove the IAM resources:

```bash
aws iam detach-role-policy --role-name EKS-AWS-CLI-S3-Role --policy-arn arn:aws:iam::535915401024:policy/S3AdministrationPolicy
aws iam delete-role --role-name EKS-AWS-CLI-S3-Role
aws iam delete-policy --policy-arn arn:aws:iam::535915401024:policy/S3AdministrationPolicy
```
