<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Setting Up Amazon CloudWatch Observability for EKS

This document outlines the steps taken to set up Amazon CloudWatch Observability for the EKS cluster running the Go Bedrock application.

## Overview

Amazon CloudWatch Observability EKS Add-on provides comprehensive monitoring capabilities for your EKS cluster, including:

- Container metrics
- Pod metrics
- Node metrics
- Cluster metrics
- Container logs
- Application logs
- Performance monitoring

## Prerequisites

- An EKS cluster named `<CLUSTER_NAME>` in the `<REGION>` region
- AWS CLI configured with appropriate permissions
- kubectl configured to access your EKS cluster

## Implementation Steps

### 1. Create IAM Policy for CloudWatch Observability

Create a policy file named `cloudwatch-observability-policy.json`:

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

### 2. Create Namespace for CloudWatch Observability

```bash
kubectl create namespace amazon-cloudwatch
```

### 3. Create IAM Service Account

```bash
eksctl create iamserviceaccount \
    --name cloudwatch-observability \
    --namespace amazon-cloudwatch \
    --cluster <CLUSTER_NAME> \
    --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/CloudWatchObservabilityPolicy \
    --approve \
    --region <REGION>
```

### 4. Install CloudWatch Observability Add-on

```bash
eksctl create addon \
    --name amazon-cloudwatch-observability \
    --cluster <CLUSTER_NAME> \
    --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME> \
    --region <REGION>
```

### 5. Verify Installation

Check the add-on status:

```bash
eksctl get addon --cluster <CLUSTER_NAME> --region <REGION>
```

Output:
```
NAME                            VERSION             STATUS  ISSUES  IAMROLE                                                                                 UPDATE AVAILABLE  CONFIGURATION VALUES
amazon-cloudwatch-observability  v4.0.0-eksbuild.1  ACTIVE  0      arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>
```

Check the CloudWatch Observability pods:

```bash
kubectl get pods -n amazon-cloudwatch
```

Output:
```
NAME                                                              READY   STATUS    RESTARTS   AGE
amazon-cloudwatch-observability-controller-manager-6b6c8cbbhgzx   1/1     Running   0          68s
cloudwatch-agent-bpx68                                            1/1     Running   0          63s
cloudwatch-agent-v8qcz                                            1/1     Running   0          63s
cloudwatch-agent-vwczd                                            1/1     Running   0          63s
fluent-bit-9r7ft                                                  1/1     Running   0          68s
fluent-bit-thtfs                                                  1/1     Running   0          68s
fluent-bit-zm6vs                                                  1/1     Running   0          68s
```

## Accessing CloudWatch Container Insights

After the installation is complete, metrics and logs will start appearing in CloudWatch Container Insights. You can access them through the AWS Management Console:

1. Open the CloudWatch console: https://console.aws.amazon.com/cloudwatch/
2. In the left navigation pane, choose **Insights** > **Container Insights**
3. From the dropdown, select **Performance monitoring** or select **Container map** to view your cluster

## Available Metrics and Logs

### Container Insights Metrics

Container Insights collects metrics at multiple levels:

- **Cluster-level metrics**: CPU, memory, disk, and network usage for the entire cluster
- **Node-level metrics**: CPU, memory, disk, and network usage for each node
- **Pod-level metrics**: CPU, memory, disk, and network usage for each pod
- **Service-level metrics**: Request count, latency, and error rates for services

### Container Insights Logs

Container Insights creates the following log groups:

- `/aws/containerinsights/<CLUSTER_NAME>/application`: Application logs
- `/aws/containerinsights/<CLUSTER_NAME>/host`: Host logs
- `/aws/containerinsights/<CLUSTER_NAME>/performance`: Performance logs
- `/aws/containerinsights/<CLUSTER_NAME>/dataplane`: Data plane logs

## Creating CloudWatch Dashboards

You can create custom dashboards to monitor your Go Bedrock application:

1. In the CloudWatch console, go to **Dashboards** > **Create dashboard**
2. Add widgets for container metrics, logs, and alarms
3. Focus on key metrics like CPU usage, memory usage, and request latency

## Setting Up Alarms

Consider setting up alarms for:

1. High CPU or memory usage in your Go Bedrock pods
2. Error rates in your application logs
3. Latency spikes in your API requests

Example alarm creation command:

```bash
aws cloudwatch put-metric-alarm \
    --alarm-name "GoBedrock-HighCPU" \
    --alarm-description "Alarm when CPU exceeds 80%" \
    --metric-name pod_cpu_utilization \
    --namespace ContainerInsights \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=ClusterName,Value=<CLUSTER_NAME> Name=PodName,Value=go-bedrock-app \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:<REGION>:<ACCOUNT_ID>:your-sns-topic
```

## References

- [Amazon CloudWatch Observability EKS Add-on Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-EKS-addon.html)
- [CloudWatch Container Insights Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)
