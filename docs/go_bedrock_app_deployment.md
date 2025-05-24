<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Go Bedrock Application Deployment Guide

This document outlines the process of deploying the Go Bedrock application on Amazon EKS with HTTPS support using the AWS Load Balancer Controller.

## Prerequisites

- An EKS cluster named `esk-stack-eks-cluster` in the `us-west-2` region
- AWS Load Balancer Controller installed on the cluster
- An ECR image for the application: `YOUR_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/go-bedrock-app:v6`
- An ACM certificate for the domain: `arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID`

## Deployment Steps

### 1. Create IAM Policy for Bedrock Access

Create a policy file named `bedrock-policy.json`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": "arn:aws:bedrock:us-west-2::foundation-model/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:ListFoundationModels"
            ],
            "Resource": "*"
        }
    ]
}
```

Create the IAM policy:

```bash
aws iam create-policy \
  --policy-name BedrockAccessPolicy \
  --policy-document file://bedrock-policy.json
```

### 2. Create IAM Service Account

Create a Kubernetes service account with the necessary IAM permissions:

```bash
eksctl create iamserviceaccount \
  --cluster=esk-stack-eks-cluster \
  --namespace=default \
  --name=bedrock-service-account \
  --attach-policy-arn=arn:aws:iam::YOUR_ACCOUNT_ID:policy/BedrockAccessPolicy \
  --override-existing-serviceaccounts \
  --region us-west-2 \
  --approve
```

### 3. Create Kubernetes Deployment and Service

Create a file named `go-bedrock-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-bedrock-app
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
    spec:
      serviceAccountName: bedrock-service-account
      containers:
      - name: go-bedrock-app
        image: YOUR_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/go-bedrock-app:v6
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        env:
        - name: AWS_REGION
          value: "us-west-2"
---
apiVersion: v1
kind: Service
metadata:
  name: go-bedrock-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-0264e34386cf1651f,subnet-0cd2ba3b40b67a9e5,subnet-0446289a0e1f8dbbd"
spec:
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
  selector:
    app: go-bedrock-app
```

Apply the deployment and service:

```bash
kubectl apply -f go-bedrock-deployment.yaml
```

### 4. Create Ingress Resource for HTTPS

Create a file named `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: go-bedrock-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    external-dns.alpha.kubernetes.io/hostname: eks-bedrock.entest.io
    alb.ingress.kubernetes.io/subnets: subnet-0264e34386cf1651f,subnet-0cd2ba3b40b67a9e5,subnet-0446289a0e1f8dbbd
spec:
  rules:
  - host: eks-bedrock.entest.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: go-bedrock-service
            port:
              number: 80
```

Apply the ingress resource:

```bash
kubectl apply -f ingress.yaml
```

## Verification

### Check Deployment Status

```bash
kubectl get deployment go-bedrock-app
kubectl get pods -l app=go-bedrock-app
```

### Check Service and Ingress Status

```bash
kubectl get service go-bedrock-service
kubectl get ingress go-bedrock-ingress
```

### Access the Application

Once the ALB is provisioned, you can access the application using:

1. The domain name (after DNS propagation):
   ```
   https://eks-bedrock.entest.io
   ```

2. The ALB DNS with Host header (immediate access):
   ```
   curl -k -H "Host: eks-bedrock.entest.io" https://k8s-default-gobedroc-aec1cd97fb-1269645029.us-west-2.elb.amazonaws.com
   ```

For more details on accessing the application using the Host header, see [Troubleshooting ALB Access with Host Headers](troubleshooting_curl_alb.md).

## DNS Configuration

Create a CNAME record for `eks-bedrock.entest.io` pointing to the ALB DNS name:
```
eks-bedrock.entest.io CNAME k8s-default-gobedroc-aec1cd97fb-1269645029.us-west-2.elb.amazonaws.com
```

## Troubleshooting

If you encounter issues accessing the application, check:

1. Pod logs:
   ```bash
   kubectl logs -l app=go-bedrock-app
   ```

2. Service endpoints:
   ```bash
   kubectl get endpoints go-bedrock-service
   ```

3. ALB target group health:
   ```bash
   aws elbv2 describe-target-health --region us-west-2 --target-group-arn $(aws elbv2 describe-target-groups --region us-west-2 --query "TargetGroups[?starts_with(TargetGroupName, 'k8s-default-gobedroc')].TargetGroupArn" --output text | head -1)
   ```

For more troubleshooting tips, refer to [Troubleshooting ALB Access with Host Headers](troubleshooting_curl_alb.md).
