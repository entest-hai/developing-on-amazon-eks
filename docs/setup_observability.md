<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Setting Up Observability for Amazon EKS

This guide provides instructions for setting up observability and logging for your Amazon EKS cluster and applications (go-bedrock-app and go-book-app) using AWS observability solutions.

## Comparing AWS Observability Solutions

### AWS Distro for OpenTelemetry (ADOT)

**Overview:**
AWS Distro for OpenTelemetry is AWS's distribution of the OpenTelemetry project, which provides a single set of APIs, libraries, agents, and collector services to capture distributed traces and metrics from your applications.

**Key Features:**
- Open-source and vendor-neutral
- Supports multiple backends (AWS services and third-party tools)
- Highly customizable collection and processing pipeline
- Supports traces, metrics, and logs
- Follows OpenTelemetry standards for instrumentation

**Pros:**
- Flexibility to send data to multiple destinations (CloudWatch, Prometheus, X-Ray, etc.)
- Future-proof with open standards
- More granular control over data collection and sampling
- Better for multi-cloud environments
- Extensive instrumentation options for various programming languages

**Cons:**
- More complex setup and configuration
- Requires more knowledge to optimize
- Additional components to manage

### Amazon CloudWatch Observability

**Overview:**
Amazon CloudWatch Observability is an integrated solution that combines CloudWatch with Container Insights and Application Insights to provide monitoring and operational data for your EKS clusters.

**Key Features:**
- Tightly integrated with AWS services
- Automatic dashboards for container metrics
- Built-in alerting capabilities
- Log aggregation and insights
- Application performance monitoring

**Pros:**
- Simpler setup with EKS add-on
- Unified AWS console experience
- Automatic dashboards and visualizations
- Built-in alerting and anomaly detection
- Lower operational overhead

**Cons:**
- Less flexible than ADOT
- Primarily focused on AWS services
- Limited customization options
- Potentially higher costs for high-volume data

## Recommendation

**For most AWS-centric deployments: Amazon CloudWatch Observability**
- Easier to set up and maintain
- Provides good out-of-the-box experience
- Integrated with other AWS services
- Sufficient for most monitoring needs

**For complex, multi-cloud, or specialized requirements: AWS Distro for OpenTelemetry**
- More flexibility and control
- Better for hybrid or multi-cloud environments
- Supports more advanced use cases
- Follows open standards

For your EKS cluster with go-bedrock-app and go-book-app, **Amazon CloudWatch Observability** is recommended for getting started quickly with comprehensive monitoring. You can later add ADOT if you need more specialized capabilities.

## Setting Up Amazon CloudWatch Observability

### Prerequisites

- An Amazon EKS cluster
- AWS CLI configured with appropriate permissions
- kubectl configured to access your cluster
- IAM permissions to create and manage CloudWatch resources

### Step 1: Create IAM Policy for CloudWatch

Create an IAM policy that grants permissions for CloudWatch:

```bash
cat <<EOF > /tmp/cloudwatch-policy.json
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
        "logs:CreateLogGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
    }
  ]
}
EOF

# REPLACE: Update with your AWS account ID
aws iam create-policy \
    --policy-name CloudWatchAgentServerPolicy-EKS \
    --policy-document file:///tmp/cloudwatch-policy.json
```

### Step 2: Create IAM Role for Service Account

Create an IAM role and Kubernetes service account for CloudWatch:

```bash
# REPLACE: Update with your cluster name, region, and account ID
eksctl create iamserviceaccount \
    --name cloudwatch-agent \
    --namespace amazon-cloudwatch \
    --cluster your-cluster-name \
    --attach-policy-arn arn:aws:iam::your-account-id:policy/CloudWatchAgentServerPolicy-EKS \
    --approve \
    --override-existing-serviceaccounts \
    --region your-region
```

### Step 3: Install CloudWatch Observability Add-on

```bash
# REPLACE: Update with your cluster name and region
aws eks create-addon \
    --cluster-name your-cluster-name \
    --addon-name amazon-cloudwatch-observability \
    --region your-region
```

Verify the add-on installation:

```bash
aws eks describe-addon \
    --cluster-name your-cluster-name \
    --addon-name amazon-cloudwatch-observability \
    --region your-region
```

### Step 4: Verify CloudWatch Agent Deployment

Check that the CloudWatch agent pods are running:

```bash
kubectl get pods -n amazon-cloudwatch
```

You should see pods like `cloudwatch-agent-*` running.

### Step 5: Configure Application Logging

#### For go-book-app and go-bedrock-app

Update your application deployments to use the Fluent Bit for log forwarding. Add these annotations to your pod specifications:

```yaml
annotations:
  fluentbit.io/parser: cri
```

Example for go-bedrock-app:

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
        fluentbit.io/parser: cri  # Add this annotation
    spec:
      serviceAccountName: go-bedrock-service-account
      containers:
      - name: go-bedrock-app
        # REPLACE: Update with your actual AWS account ID in the image URL
        image: your-account-id.dkr.ecr.us-west-2.amazonaws.com/go-bedrock-app:v4
        # Rest of your container spec...
```

Apply the updated deployment:

```bash
kubectl apply -f yaml/go-bedrock-app-deployment-fixed.yaml
kubectl apply -f yaml/book-pod.yaml
```

## Setting Up AWS Distro for OpenTelemetry (Alternative Approach)

If you prefer using ADOT for more flexibility, follow these steps:

### Step 1: Create IAM Policy for ADOT

```bash
cat <<EOF > /tmp/adot-collector-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:GetSamplingStatisticSummaries",
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# REPLACE: Update with your AWS account ID
aws iam create-policy \
    --policy-name ADOTCollectorPolicy \
    --policy-document file:///tmp/adot-collector-policy.json
```

### Step 2: Create IAM Role for ADOT Service Account

```bash
# REPLACE: Update with your cluster name, region, and account ID
eksctl create iamserviceaccount \
    --name adot-collector \
    --namespace opentelemetry \
    --cluster your-cluster-name \
    --attach-policy-arn arn:aws:iam::your-account-id:policy/ADOTCollectorPolicy \
    --approve \
    --region your-region
```

### Step 3: Install ADOT Operator

```bash
# Create the opentelemetry namespace
kubectl create namespace opentelemetry

# Install the ADOT Operator using Helm
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm install my-adot-operator open-telemetry/opentelemetry-operator \
    --namespace opentelemetry
```

### Step 4: Create ADOT Collector Configuration

Create a file named `adot-collector.yaml`:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: adot-collector
  namespace: opentelemetry
spec:
  mode: deployment
  serviceAccount: adot-collector
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      prometheus:
        config:
          scrape_configs:
          - job_name: 'kubernetes-pods'
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              regex: ([^:]+)(?::\d+)?;(\d+)
              replacement: $1:$2
              target_label: __address__
      filelog:
        include: [ /var/log/pods/*/*/*.log ]
        exclude: [ /var/log/pods/*/kube-proxy/*.log ]
        start_at: beginning
        include_file_path: true
        include_file_name: false
        operators:
          - type: router
            id: get-format
            routes:
              - output: parser-docker
                expr: 'body matches "^\\{"'
              - output: parser-cri
                expr: 'body matches "^[^ Z]+ "'
              - output: parser-cri
                expr: 'body matches "^[^ Z]+Z"'
          - type: regex_parser
            id: parser-cri
            regex: '^(?P<time>[^ ^Z]+Z) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) ?(?P<log>.*)$'
            output: extract_metadata_from_filepath
            timestamp:
              parse_from: time
              layout_type: gotime
              layout: '2006-01-02T15:04:05.000000000Z'
          - type: regex_parser
            id: parser-docker
            regex: '^(?P<time>[^ ^Z]+Z) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) ?(?P<log>.*)$'
            output: extract_metadata_from_filepath
            timestamp:
              parse_from: time
              layout_type: gotime
              layout: '2006-01-02T15:04:05.000000000Z'
          - type: regex_parser
            id: extract_metadata_from_filepath
            regex: '^.*\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[a-f0-9\-]{36})\/(?P<container_name>[^\._]+)\/(?P<restart_count>\d+)\.log$'
            parse_from: attributes["file.path"]
            cache:
              size: 1000
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      memory_limiter:
        check_interval: 1s
        limit_mib: 1000
      resourcedetection:
        detectors: [eks]
        timeout: 2s
      k8sattributes:
        extract:
          metadata:
            - k8s.namespace.name
            - k8s.pod.name
            - k8s.deployment.name
            - k8s.node.name
          annotations:
            - tag_name: app
              key: app
            - tag_name: app.kubernetes.io/name
              key: app.kubernetes.io/name
          labels:
            - tag_name: app
              key: app
            - tag_name: app.kubernetes.io/name
              key: app.kubernetes.io/name
    exporters:
      awsxray:
        region: your-region
      awsemf:
        region: your-region
        namespace: EKSContainerInsights
        log_group_name: '/aws/containerinsights/{ClusterName}/performance'
        dimension_rollup_option: NoDimensionRollup
        metric_declarations:
          - dimensions: [[PodName, Namespace, ClusterName]]
            metric_name_selectors:
              - container_cpu_usage_seconds_total
              - container_memory_usage_bytes
          - dimensions: [[Service, Namespace, ClusterName]]
            metric_name_selectors:
              - request_count
              - latency
      awscloudwatchlogs:
        region: your-region
        log_group_name: '/aws/containerinsights/{ClusterName}/application'
        log_stream_name: '{PodName}.{ContainerName}'
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, batch]
          exporters: [awsxray]
        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [awsemf]
        logs:
          receivers: [filelog]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [awscloudwatchlogs]
```

Apply the collector configuration:

```bash
# REPLACE: Update the region in the YAML file before applying
kubectl apply -f adot-collector.yaml
```

### Step 5: Instrument Your Applications

For Go applications like go-bedrock-app and go-book-app, you'll need to add OpenTelemetry instrumentation to your code.

#### Example Go Instrumentation

Add these dependencies to your Go application:

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)
```

Initialize the tracer:

```go
func initTracer() (*sdktrace.TracerProvider, error) {
    ctx := context.Background()
    
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceNameKey.String("go-bedrock-app"),
            semconv.ServiceVersionKey.String("v1.0.0"),
        ),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to create resource: %w", err)
    }

    // Create OTLP exporter
    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithInsecure(),
        otlptracegrpc.WithEndpoint("adot-collector.opentelemetry:4317"),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to create exporter: %w", err)
    }

    // Create trace provider
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithSampler(sdktrace.AlwaysSample()),
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
    )
    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ))
    
    return tp, nil
}
```

Use the tracer in your HTTP handlers:

```go
func main() {
    tp, err := initTracer()
    if err != nil {
        log.Fatalf("Failed to initialize tracer: %v", err)
    }
    defer func() {
        if err := tp.Shutdown(context.Background()); err != nil {
            log.Printf("Error shutting down tracer provider: %v", err)
        }
    }()
    
    // Your HTTP server setup
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        ctx := r.Context()
        tracer := otel.Tracer("go-bedrock-app")
        ctx, span := tracer.Start(ctx, "handleRequest")
        defer span.End()
        
        // Your handler logic
        // ...
    })
    
    log.Fatal(http.ListenAndServe(":3000", nil))
}
```

## Viewing Observability Data

### CloudWatch Dashboards

1. Open the CloudWatch console: https://console.aws.amazon.com/cloudwatch/
2. Navigate to "Dashboards" > "Container Insights"
3. Select your EKS cluster from the dropdown
4. View performance metrics, logs, and traces

### CloudWatch Logs

1. Open the CloudWatch console
2. Navigate to "Logs" > "Log groups"
3. Find the log groups:
   - `/aws/containerinsights/your-cluster-name/application` (for application logs)
   - `/aws/containerinsights/your-cluster-name/performance` (for performance metrics)

### X-Ray Traces (if using ADOT)

1. Open the X-Ray console: https://console.aws.amazon.com/xray/
2. Navigate to "Traces" to view distributed traces
3. Use the service map to visualize service dependencies

## Setting Up Alerts

### CloudWatch Alarms

Create alarms for critical metrics:

```bash
# Example: Create an alarm for high CPU usage
aws cloudwatch put-metric-alarm \
    --alarm-name HighCPUUsage-go-bedrock-app \
    --alarm-description "Alarm when CPU exceeds 80%" \
    --metric-name pod_cpu_utilization \
    --namespace ContainerInsights \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=ClusterName,Value=your-cluster-name Name=Namespace,Value=default Name=PodName,Value=go-bedrock-app \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:your-region:your-account-id:your-sns-topic
```

## Best Practices

1. **Start with essential metrics**: Focus on the Four Golden Signals:
   - Latency
   - Traffic
   - Errors
   - Saturation

2. **Use meaningful log levels**: Ensure your applications use appropriate log levels (INFO, WARN, ERROR)

3. **Add context to logs**: Include request IDs, user IDs, and other contextual information

4. **Set up alerts for critical conditions**: Don't alert on everything; focus on actionable issues

5. **Implement distributed tracing**: For complex microservice architectures

6. **Regularly review and optimize**: Adjust collection, retention, and alerting based on actual needs

7. **Consider costs**: Monitor data ingestion and storage costs, especially for high-volume applications

## Conclusion

This guide has provided instructions for setting up observability for your EKS cluster and applications using either Amazon CloudWatch Observability (recommended for simplicity) or AWS Distro for OpenTelemetry (recommended for flexibility).

For most use cases, starting with CloudWatch Observability provides a good balance of features and ease of setup. As your observability needs grow more complex, you can consider adding ADOT for more specialized use cases.

Remember to replace placeholder values (your-cluster-name, your-region, your-account-id) with your actual values before running the commands.
