<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

## Deploy Amazon CloudWatch Observability Add-on

This section covers deploying the Amazon CloudWatch Observability add-on to your EKS cluster to collect metrics and logs from your applications.

### Prerequisites

- EKS cluster deployed and kubectl configured
- AWS CLI installed and configured with appropriate permissions
- IAM permissions to create policies and roles

### Option 1: Deploy CloudWatch Observability Using IAM Roles for Service Accounts (IRSA)

This is the traditional method for providing AWS IAM permissions to pods in an EKS cluster.

#### 1. Create IAM Policy for CloudWatch Observability

Create a file named `cloudwatch-observability-policy.json` with the following content:

```json
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
```

Create the IAM policy:

```bash
aws iam create-policy \
  --policy-name CloudWatchObservabilityPolicy \
  --policy-document file://cloudwatch-observability-policy.json
```

Note the ARN of the created policy for use in the next step.

#### 2. Create Namespace for CloudWatch Observability

```bash
kubectl create namespace amazon-cloudwatch
```

#### 3. Create IAM Service Account

```bash
eksctl create iamserviceaccount \
    --name cloudwatch-observability \
    --namespace amazon-cloudwatch \
    --cluster eks-stack-eks-cluster \
    --attach-policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/CloudWatchObservabilityPolicy \
    --approve \
    --region us-west-2
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

#### 4. Install CloudWatch Observability Add-on

```bash
eksctl create addon \
    --name amazon-cloudwatch-observability \
    --cluster eks-stack-eks-cluster \
    --service-account-role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/eksctl-eks-stack-eks-cluster-addon-iamserviceaccount-Role1-XXXXXXXXXXXX \
    --region us-west-2
```

Replace:
- `YOUR_ACCOUNT_ID` with your actual AWS account ID
- The role name with the actual role name created by eksctl in the previous step

#### 5. Verify Installation

Check the add-on status:

```bash
eksctl get addon --cluster eks-stack-eks-cluster --region us-west-2
```

Check the CloudWatch Observability pods:

```bash
kubectl get pods -n amazon-cloudwatch
```

You should see pods for the CloudWatch agent, Fluent Bit, and the controller manager.

### Option 2: Deploy CloudWatch Observability Using Pod Identity

This is a newer, more streamlined approach for EKS clusters version 1.24 or later.

#### 1. Create IAM Policy for CloudWatch Observability

Create a file named `cloudwatch-observability-policy.json` with the following content:

```json
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
```

Create the IAM policy:

```bash
aws iam create-policy \
  --policy-name CloudWatchObservabilityPolicy \
  --policy-document file://cloudwatch-observability-policy.json
```

#### 2. Create IAM Role for Pod Identity

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
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/CloudWatchObservabilityPolicy
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

#### 3. Create Namespace and Service Account

```bash
# Create namespace
kubectl create namespace amazon-cloudwatch

# Create service account (without any annotations)
kubectl create serviceaccount cloudwatch-observability -n amazon-cloudwatch
```

#### 4. Create Pod Identity Association

```bash
aws eks create-pod-identity-association \
  --cluster-name eks-stack-eks-cluster \
  --namespace amazon-cloudwatch \
  --service-account cloudwatch-observability \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/CloudWatchObservabilityPodIdentityRole
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

#### 5. Install CloudWatch Observability Add-on with Pod Identity

```bash
eksctl create addon \
  --name amazon-cloudwatch-observability \
  --cluster eks-stack-eks-cluster \
  --region us-west-2 \
  --configuration-values '{
    "serviceAccount": {
      "name": "cloudwatch-observability",
      "create": false
    }
  }'
```

#### 6. Verify Pod Identity Association

```bash
# List Pod Identity associations
aws eks list-pod-identity-associations --cluster-name eks-stack-eks-cluster

# Verify the CloudWatch agent pods are running
kubectl get pods -n amazon-cloudwatch
```

### Update Applications to Use CloudWatch Logging

#### 1. Update Go Web Demo Application

Create a file named `go-book-app-observability.yaml` with the following content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-book-app
  namespace: default
  labels:
    app: go-book-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-book-app
  template:
    metadata:
      labels:
        app: go-book-app
      annotations:
        fluentbit.io/parser: cri  # Add this annotation for CloudWatch logging
    spec:
      containers:
      - name: go-book-app
        # REPLACE: Update with your actual AWS account ID in the image URL
        image: YOUR_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/go-book-app:latest
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

Apply the updated deployment:

```bash
kubectl apply -f go-book-app-observability.yaml
```

#### 2. Update Go Bedrock Application

Create a file named `go-bedrock-app-observability.yaml` with the following content:

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
      annotations:
        fluentbit.io/parser: cri  # Add this annotation for CloudWatch logging
    spec:
      serviceAccountName: bedrock-service-account
      containers:
      - name: go-bedrock-app
        # REPLACE: Update with your actual AWS account ID in the image URL
        image: YOUR_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/go-bedrock-app:v7
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
          value: "us-west-2"
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

Apply the updated deployment:

```bash
kubectl apply -f go-bedrock-app-observability.yaml
```

### Accessing CloudWatch Data

#### 1. Container Insights Dashboard

1. Open the CloudWatch console: https://console.aws.amazon.com/cloudwatch/
2. Navigate to "Container Insights" in the left sidebar
3. Select the cluster "eks-stack-eks-cluster"

You can view:
- Cluster performance metrics
- Node metrics
- Pod metrics
- Service metrics

#### 2. Log Groups

The following CloudWatch Log Groups are now available:

1. Performance Logs:
   ```
   /aws/containerinsights/eks-stack-eks-cluster/performance
   ```

2. Application Logs:
   ```
   /aws/containerinsights/eks-stack-eks-cluster/application
   ```

3. Host Logs:
   ```
   /aws/containerinsights/eks-stack-eks-cluster/host
   ```

#### 3. Viewing Application Logs

To view logs for specific applications:

1. Go to CloudWatch console
2. Navigate to "Log groups"
3. Select `/aws/containerinsights/eks-stack-eks-cluster/application`
4. Use the search feature with these filters:
   - For go-bedrock-app: `kubernetes.pod_name: go-bedrock-app`
   - For go-book-app: `kubernetes.pod_name: go-book-app`

### Setting Up Alarms

Example alarm for high CPU usage:

```bash
aws cloudwatch put-metric-alarm \
    --alarm-name HighCPUUsage-go-bedrock-app \
    --alarm-description "Alarm when CPU exceeds 80%" \
    --metric-name pod_cpu_utilization \
    --namespace ContainerInsights \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=ClusterName,Value=eks-stack-eks-cluster Name=Namespace,Value=default Name=PodName,Value=go-bedrock-app \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:us-west-2:YOUR_ACCOUNT_ID:your-sns-topic
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

### Troubleshooting CloudWatch Observability

#### 1. Checking Add-on Status

```bash
aws eks describe-addon \
    --cluster-name eks-stack-eks-cluster \
    --addon-name amazon-cloudwatch-observability \
    --region us-west-2
```

#### 2. Checking Agent Logs

```bash
kubectl logs -n amazon-cloudwatch -l k8s-app=cloudwatch-agent
```

#### 3. Checking Fluent Bit Logs

```bash
kubectl logs -n amazon-cloudwatch -l k8s-app=fluent-bit
```

#### 4. Common Issues and Solutions

1. **Pods not showing in Container Insights**:
   - Check that the CloudWatch agent is running
   - Verify the service account has the correct permissions

2. **Logs not appearing in CloudWatch**:
   - Check that Fluent Bit pods are running
   - Verify the `fluentbit.io/parser: cri` annotation is present in your pod template
   - Check Fluent Bit logs for errors

3. **Permission errors**:
   - Verify the IAM policy has all required permissions
   - Check that the service account is properly configured with the IAM role

4. **Pod Identity issues**:
   - Ensure your EKS cluster version is 1.24 or later
   - Verify the Pod Identity association exists
   - Check that the IAM role trust policy is correctly configured
