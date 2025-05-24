<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Configuring HTTPS for Network Load Balancer (NLB) with AWS Load Balancer Controller

This document explains how to configure HTTPS for a Network Load Balancer (NLB) using the AWS Load Balancer Controller in Kubernetes.

## Overview

When deploying applications on Amazon EKS, you can use either an Application Load Balancer (ALB) or a Network Load Balancer (NLB) for external access. This guide focuses on configuring an NLB with HTTPS support.

## NLB vs ALB for HTTPS

While ALBs are commonly used for HTTPS traffic due to their Layer 7 capabilities, NLBs can also terminate SSL/TLS connections. NLBs offer:

- Lower latency
- Static IP addresses
- Preservation of source IP addresses
- Support for both TCP and TLS listeners

## Configuration Steps

### 1. Update Service Configuration

To configure an NLB with HTTPS support, use the following annotations in your Kubernetes Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-bedrock-service
  annotations:
    # Specify external NLB managed by AWS Load Balancer Controller
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    
    # Use IP targets (pods) instead of instance targets (nodes)
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    
    # Make the NLB internet-facing
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    
    # Specify the ACM certificate ARN for SSL/TLS termination
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID"
    
    # Specify which ports should use SSL/TLS
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    
    # Specify the backend protocol (http or tcp)
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    
    # Specify the subnets for the NLB
    service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-0264e34386cf1651f,subnet-0cd2ba3b40b67a9e5,subnet-0446289a0e1f8dbbd"
    
    # Set the hostname for DNS (if using ExternalDNS)
    external-dns.alpha.kubernetes.io/hostname: "eks-bedrock.entest.io"
spec:
  ports:
  - name: http
    port: 80
    targetPort: 3000
    protocol: TCP
  - name: https
    port: 443
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
  selector:
    app: go-bedrock-app
```

### 2. Apply the Configuration

```bash
kubectl apply -f updated-go-bedrock-deployment.yaml
```

### 3. Delete the ALB Ingress (if exists)

If you previously had an ALB Ingress, you can delete it:

```bash
kubectl delete ingress go-bedrock-ingress
```

## Key Annotations Explained

| Annotation | Description |
|------------|-------------|
| `service.beta.kubernetes.io/aws-load-balancer-type: "external"` | Specifies that the AWS Load Balancer Controller should manage this NLB |
| `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"` | Configures the NLB to route traffic directly to pods (IP mode) rather than to nodes |
| `service.beta.kubernetes.io/aws-load-balancer-ssl-cert` | Specifies the ARN of the ACM certificate for SSL/TLS termination |
| `service.beta.kubernetes.io/aws-load-balancer-ssl-ports` | Specifies which ports should use SSL/TLS (comma-separated list) |
| `service.beta.kubernetes.io/aws-load-balancer-backend-protocol` | Specifies the protocol used by the backend (http or tcp) |

## Verification

After applying the configuration, verify that the NLB is properly configured:

```bash
# Check the service status
kubectl get service go-bedrock-service

# Get the NLB DNS name
NLB_DNS=$(kubectl get service go-bedrock-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $NLB_DNS

# Test HTTPS access
curl -k https://$NLB_DNS
```

## DNS Configuration

Create a CNAME record for your domain pointing to the NLB DNS name:

```
eks-bedrock.entest.io CNAME <NLB_DNS_NAME>
```

## Troubleshooting

If you encounter issues:

1. Check the AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

2. Verify the NLB configuration in the AWS Console:
   - Check that listeners are configured for both ports 80 and 443
   - Verify that the target group health checks are passing
   - Confirm that the SSL certificate is properly attached

3. Test connectivity:
   ```bash
   # Test HTTP
   curl http://$NLB_DNS
   
   # Test HTTPS (with -k to ignore certificate validation)
   curl -k https://$NLB_DNS
   ```

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
- [NLB Annotations Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/annotations/)
- [AWS NLB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html)
