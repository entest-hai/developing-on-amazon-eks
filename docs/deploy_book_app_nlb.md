# Using AWS Network Load Balancer (NLB) with EKS

This document provides guidance on using AWS Network Load Balancer (NLB) with Amazon EKS to expose your applications, with a focus on the Go Book application.

## Overview

Network Load Balancers provide several advantages over Classic Load Balancers:
- Ultra-low latency
- Ability to handle millions of requests per second
- Static IP addresses
- Preservation of client IP addresses
- Support for both TCP and UDP protocols

## NLB Service Manifest

The NLB service manifest (`yaml/go-book-app-nlb-fixed.yaml`) exposes the application using an AWS Network Load Balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-book-app-nlb
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
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
spec:
  selector:
    app: go-book-app
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
```

## Key Annotations for NLB

| Annotation | Description |
|------------|-------------|
| `aws-load-balancer-type: "external"` | Uses the AWS Load Balancer Controller instead of the in-tree controller |
| `aws-load-balancer-nlb-target-type: "ip"` | Targets pods directly by their IP addresses |
| `aws-load-balancer-scheme: "internet-facing"` | Makes the NLB accessible from the internet |
| `aws-load-balancer-backend-protocol: "tcp"` | Specifies the protocol for backend communication |
| `aws-load-balancer-cross-zone-load-balancing-enabled: "true"` | Enables cross-zone load balancing |
| `aws-load-balancer-healthcheck-protocol: "http"` | Sets the health check protocol |
| `aws-load-balancer-healthcheck-port: "3000"` | Sets the health check port (container port) |
| `aws-load-balancer-healthcheck-path: "/"` | Sets the health check path |
| `aws-load-balancer-healthcheck-interval: "10"` | Sets the health check interval in seconds |
| `aws-load-balancer-healthcheck-timeout: "5"` | Sets the health check timeout in seconds |
| `aws-load-balancer-healthcheck-healthy-threshold: "2"` | Number of consecutive successful health checks |
| `aws-load-balancer-healthcheck-unhealthy-threshold: "2"` | Number of consecutive failed health checks |

## Deploying with NLB

```bash
kubectl apply -f yaml/go-book-app-nlb-fixed.yaml
```

## Verifying the NLB Service

```bash
kubectl get service go-book-app-nlb
```

Expected output:
```
NAME             TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
go-book-app-nlb  LoadBalancer   172.20.128.252   k8s-default-gobookap-xxxxxxxx-xxxxxxxxxxxxxxxx.elb.region.amazonaws.com        80:32683/TCP   <age>
```

## Target Types: IP vs Instance

The AWS Load Balancer Controller supports two target types for NLBs:

### IP Target Type (Recommended)

```yaml
service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
```

**Advantages:**
- Targets pods directly by their IP addresses
- Bypasses the extra hop through NodePort
- Simplifies health check configuration
- Improves performance
- Works better with pod autoscaling

**Health Check Configuration:**
- Health check port should be the container port (e.g., 3000)

### Instance Target Type

```yaml
service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
```

**Characteristics:**
- Targets nodes in the cluster
- Traffic goes through NodePort to reach pods
- Additional network hop
- Less efficient with pod autoscaling

**Health Check Configuration:**
- Health check port should be the NodePort (e.g., 32683)

## Troubleshooting NLB Health Checks

If your NLB targets show as unhealthy in the AWS console, there are two common issues:

### Issue 1: Target Type Mismatch

When using `instance` as the target type, the health check port must be the NodePort, not the container port.

**Symptoms:**
- Targets show as unhealthy in AWS console
- Error: "Target.FailedHealthChecks"
- Health checks are configured to use container port but target type is "instance"

**Solution:**
Change the target type to `ip` to target pods directly:

```yaml
service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
```

### Issue 2: Health Check Path Issues

If your application doesn't respond properly to the health check path:

**Solution:**
- Verify the application responds correctly to the health check path
- Test directly with: `kubectl exec -it <pod-name> -- curl -v http://localhost:3000/`
- Adjust the health check path if needed

### Checking Target Health

To check the health of your NLB targets:

```bash
# REPLACE: Update 'gobookap' with your actual target group name prefix if different
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, 'gobookap')].TargetGroupArn" --output text)
```

## Comparing Classic Load Balancer vs. Network Load Balancer

| Feature | Classic Load Balancer | Network Load Balancer |
|---------|----------------------|----------------------|
| Layer | Layer 4 & 7 | Layer 4 |
| Performance | Good | Excellent (millions of requests per second) |
| Latency | Higher | Ultra-low |
| Static IP | No | Yes |
| Preserve Client IP | No | Yes |
| Connection Draining | Yes | Yes (Target Group setting) |
| Cross-zone Load Balancing | Optional | Optional |
| Health Check Protocol | HTTP, HTTPS, TCP | HTTP, HTTPS, TCP |
| Target Type | Instance | Instance or IP |

Choose NLB when you need higher performance, ultra-low latency, or static IP addresses.

## Security Considerations

- NLBs do not have security groups; security must be handled at the node/pod level
- Consider using Network Policies for pod-level security
- For TLS termination, you'll need to use an Application Load Balancer or implement TLS in your application
