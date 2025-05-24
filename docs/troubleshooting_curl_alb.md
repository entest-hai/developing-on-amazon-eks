<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Troubleshooting ALB Access with Host Headers

This document explains how to troubleshoot and access applications deployed behind an AWS Application Load Balancer (ALB) when using host-based routing.

## Problem

When deploying applications with the AWS Load Balancer Controller in Kubernetes, you might encounter a 404 error when trying to access your application using the ALB's DNS name directly. This happens because:

1. The ALB is configured with host-based routing rules
2. The default action for requests that don't match any rules is to return a 404 error

## Solution: Using the Host Header

You can access your application by specifying the correct `Host` header in your requests, which tells the ALB which routing rule to apply.

### Example for the Bedrock Application

To access the Bedrock application deployed at `eks-bedrock.entest.io` before DNS propagation is complete:

```bash
curl -k -H "Host: eks-bedrock.entest.io" https://k8s-default-gobedroc-aec1cd97fb-1269645029.us-west-2.elb.amazonaws.com
```

Breaking down this command:

- `-k`: Allows insecure connections (ignores SSL certificate validation)
- `-H "Host: eks-bedrock.entest.io"`: Sets the Host header to match the host rule in the ALB
- The URL is the ALB's DNS name

## Verifying ALB Configuration

You can verify the ALB's listener rules with:

```bash
# Get the ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --region us-west-2 --query "LoadBalancers[?starts_with(LoadBalancerName, 'k8s-default-gobedroc')].LoadBalancerArn" --output text)

# Get the listener ARN
LISTENER_ARN=$(aws elbv2 describe-listeners --region us-west-2 --load-balancer-arn $ALB_ARN --query "Listeners[?Port==\`443\`].ListenerArn" --output text)

# Check the rules
aws elbv2 describe-rules --region us-west-2 --listener-arn $LISTENER_ARN
```

## Browser Access

For browser access before DNS propagation:

1. Install a header modification extension like "ModHeader" for Chrome or Firefox
2. Add a header rule with:
   - Name: `Host`
   - Value: `eks-bedrock.entest.io`
3. Navigate to the ALB DNS URL (https://k8s-default-gobedroc-aec1cd97fb-1269645029.us-west-2.elb.amazonaws.com)

## Permanent Solution: DNS Configuration

To resolve this permanently, create a CNAME record in your DNS settings:

- Record type: CNAME
- Name: eks-bedrock.entest.io
- Value: k8s-default-gobedroc-aec1cd97fb-1269645029.us-west-2.elb.amazonaws.com

Once DNS propagation is complete (which can take up to 48 hours depending on TTL settings), you can access the application directly at `https://eks-bedrock.entest.io`.

## Checking DNS Propagation

You can check if DNS has propagated with:

```bash
dig eks-bedrock.entest.io
```

Look for the CNAME record pointing to the ALB in the answer section.
