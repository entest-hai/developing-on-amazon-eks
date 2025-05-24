<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# NLB HTTPS Configuration Results

This document summarizes the changes made to configure HTTPS on the Network Load Balancer (NLB) and remove the Application Load Balancer (ALB) for the Go Bedrock application.

## Changes Implemented

1. **Deleted the ALB Ingress Resource**
   ```bash
   kubectl delete ingress go-bedrock-ingress
   ```

2. **Updated the Service with HTTPS Configuration**
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: Service
   metadata:
     name: go-bedrock-service
     annotations:
       service.beta.kubernetes.io/aws-load-balancer-type: "external"
       service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
       service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
       service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID"
       service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
       service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
       service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-0264e34386cf1651f,subnet-0cd2ba3b40b67a9e5,subnet-0446289a0e1f8dbbd"
       external-dns.alpha.kubernetes.io/hostname: "eks-bedrock.entest.io"
   spec:
     ports:
     - name: https
       port: 443
       targetPort: 3000
       protocol: TCP
     type: LoadBalancer
     selector:
       app: go-bedrock-app
   EOF
   ```

3. **Removed Port 80 Listener from NLB**
   ```bash
   # Get the listener ARN
   LISTENER_ARN=$(aws elbv2 describe-listeners --region us-west-2 --load-balancer-arn "arn:aws:elasticloadbalancing:us-west-2:YOUR_ACCOUNT_ID:loadbalancer/net/k8s-default-gobedroc-7797753aed/47551f52435427ac" --query "Listeners[?Port==\`80\`].ListenerArn" --output text)
   
   # Delete the listener
   aws elbv2 delete-listener --region us-west-2 --listener-arn $LISTENER_ARN
   ```

## Current Configuration

### NLB Details

- **Name**: k8s-default-gobedroc-7797753aed
- **ARN**: arn:aws:elasticloadbalancing:us-west-2:YOUR_ACCOUNT_ID:loadbalancer/net/k8s-default-gobedroc-7797753aed/47551f52435427ac
- **DNS Name**: k8s-default-gobedroc-7797753aed-47551f52435427ac.elb.us-west-2.amazonaws.com

### NLB Listeners

| Port | Protocol |
|------|----------|
| 443  | TLS      |

### Service Status

```
NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)         AGE
go-bedrock-service   LoadBalancer   172.20.189.151   k8s-default-gobedroc-7797753aed-47551f52435427ac.elb.us-west-2.amazonaws.com   443:31252/TCP   46m
```

## Verification

HTTPS access to the NLB has been successfully configured and tested. The application is accessible via:

- HTTPS: https://k8s-default-gobedroc-7797753aed-47551f52435427ac.elb.us-west-2.amazonaws.com

The ALB has been completely removed, and the NLB is now handling only HTTPS traffic on port 443.

## Next Steps

1. **Update DNS Records**
   Create or update the CNAME record for `eks-bedrock.entest.io` to point to the NLB DNS name:
   ```
   eks-bedrock.entest.io CNAME k8s-default-gobedroc-7797753aed-47551f52435427ac.elb.us-west-2.amazonaws.com
   ```

2. **Verify DNS Propagation**
   After updating the DNS records, verify that the domain resolves correctly:
   ```bash
   dig eks-bedrock.entest.io
   ```

3. **Test Access via Domain**
   Once DNS has propagated, test accessing the application via the domain:
   ```bash
   curl -k https://eks-bedrock.entest.io
   ```

## Benefits of the Final Configuration

1. **Simplified Infrastructure**: Single load balancer with a single listener
2. **Enhanced Security**: HTTPS-only access, eliminating unencrypted HTTP traffic
3. **Cost Reduction**: Eliminated redundant ALB and unnecessary HTTP listener
4. **Improved Performance**: NLBs typically have lower latency than ALBs
5. **Static IP Addresses**: NLBs provide static IP addresses, which can be useful for firewall rules
