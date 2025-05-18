# Setting Up Amazon CloudWatch Observability for EKS

This document details the successful setup of Amazon CloudWatch Observability for our EKS cluster and applications (go-bedrock-app and go-book-app).

## Implementation Details

### 1. CloudWatch Setup Status

The CloudWatch Observability add-on has been successfully installed and is running:

```bash
$ kubectl get pods -n amazon-cloudwatch
NAME                                                              READY   STATUS    RESTARTS   AGE
amazon-cloudwatch-observability-controller-manager-6b6c8cbqgr6l   1/1     Running   0          80s
cloudwatch-agent-4qg94                                            1/1     Running   0          75s
cloudwatch-agent-9jwtc                                            1/1     Running   0          75s
cloudwatch-agent-xqvcf                                            1/1     Running   0          75s
fluent-bit-46sb2                                                  1/1     Running   0          80s
fluent-bit-klflx                                                  1/1     Running   0          80s
fluent-bit-mmp4v                                                  1/1     Running   0          80s
```

### 2. Components Installed

1. **CloudWatch Agent**: Collects metrics from the cluster
2. **Fluent Bit**: Handles log collection and forwarding
3. **CloudWatch Observability Controller**: Manages the observability stack

### 3. Monitored Applications

Both applications have been configured with CloudWatch logging:
- go-bedrock-app
- go-book-app

## Accessing CloudWatch Data

### 1. Container Insights Dashboard

1. Open the CloudWatch console: https://console.aws.amazon.com/cloudwatch/
2. Navigate to "Container Insights" in the left sidebar
3. Select the cluster "eks-stack-eks-cluster"

You can view:
- Cluster performance metrics
- Node metrics
- Pod metrics
- Service metrics

### 2. Log Groups

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

### 3. Metrics

Key metrics being collected:

1. **Cluster Metrics:**
   - Node count
   - Failed node count
   - CPU utilization
   - Memory utilization
   - Network I/O
   - Disk I/O

2. **Pod Metrics:**
   - CPU usage
   - Memory usage
   - Network I/O
   - Restart count
   - Status

3. **Service Metrics:**
   - Request count
   - Error count
   - Latency

## Viewing Application Logs

To view logs for specific applications:

1. Go to CloudWatch console
2. Navigate to "Log groups"
3. Select `/aws/containerinsights/eks-stack-eks-cluster/application`
4. Use the search feature with these filters:
   - For go-bedrock-app: `kubernetes.pod_name: go-bedrock-app`
   - For go-book-app: `kubernetes.pod_name: go-book-app`

## Setting Up Alarms

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
    --alarm-actions arn:aws:sns:us-west-2:your-account-id:your-sns-topic
```

## Maintenance and Troubleshooting

### 1. Checking Add-on Status

```bash
aws eks describe-addon \
    --cluster-name eks-stack-eks-cluster \
    --addon-name amazon-cloudwatch-observability \
    --region us-west-2
```

### 2. Checking Agent Logs

```bash
kubectl logs -n amazon-cloudwatch -l k8s-app=cloudwatch-agent
```

### 3. Checking Fluent Bit Logs

```bash
kubectl logs -n amazon-cloudwatch -l k8s-app=fluent-bit
```

## Cost Considerations

Monitor these CloudWatch costs:
1. Metric ingestion and storage
2. Log ingestion and storage
3. Dashboard usage
4. Alarm evaluations

Consider setting up:
- Log retention policies
- Metric filter policies
- Cost allocation tags

## Best Practices

1. **Log Levels:**
   - Use appropriate log levels (INFO, WARN, ERROR)
   - Include contextual information in logs

2. **Metrics:**
   - Focus on actionable metrics
   - Set up alerts only for critical conditions

3. **Retention:**
   - Configure appropriate retention periods
   - Archive logs to S3 for long-term storage

4. **Monitoring:**
   - Regularly review CloudWatch costs
   - Optimize metric collection based on usage

## Next Steps

1. Set up custom dashboards for your applications
2. Configure appropriate log retention periods
3. Set up alerts for critical metrics
4. Create cost allocation tags
5. Document application-specific metrics and logs

## Conclusion

Amazon CloudWatch Observability is now successfully set up and monitoring your EKS cluster and applications. You can access metrics, logs, and set up alerts through the CloudWatch console.


# Amazon CloudWatch Observability Setup Complete

I've successfully set up Amazon CloudWatch Observability for your EKS cluster and applications. Here's a summary of what was accomplished:

## 1. Setup Process Completed

✅ Created IAM policy for CloudWatch permissions  
✅ Created dedicated namespace for CloudWatch components  
✅ Set up IAM service account with necessary permissions  
✅ Installed the Amazon CloudWatch Observability add-on  
✅ Verified all CloudWatch components are running properly  
✅ Updated application deployments with logging annotations  

## 2. Components Installed and Running

The following components are now running in your cluster:
• CloudWatch Agent (3 pods)
• Fluent Bit log forwarder (3 pods)
• CloudWatch Observability controller

All pods are in the Running state and ready to collect metrics and logs.

## 3. Application Monitoring Configured

I've updated both of your applications to work with CloudWatch:
• Added fluentbit.io/parser: cri annotation to go-bedrock-app
• Added fluentbit.io/parser: cri annotation to go-book-app

These annotations ensure that logs from your applications are properly parsed and sent to CloudWatch.

## 4. Documentation Created

I've created a comprehensive documentation file at /home/ec2-user/eks/docs/setup_amazon_cloudwatch_observability.md that includes:

• Current setup status and components
• How to access CloudWatch dashboards and logs
• Available metrics and log groups
• Instructions for setting up alarms
• Maintenance and troubleshooting guidance
• Cost considerations and best practices
• Next steps for further optimization

## 5. All Changes Committed to GitHub

All configuration files and documentation have been committed to your GitHub repository:
• YAML files for updated application deployments
• CloudWatch Observability setup documentation

## Next Steps

You can now access your cluster and application metrics in the CloudWatch console:
1. Go to https://console.aws.amazon.com/cloudwatch/
2. Navigate to "Container Insights" in the left sidebar
3. Select your cluster "eks-stack-eks-cluster"

For application logs, go to the Log Groups section and look for:
/aws/containerinsights/eks-stack-eks-cluster/application


The setup is complete and your EKS cluster now has comprehensive observability through Amazon CloudWatch!