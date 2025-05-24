<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Go Bedrock Application Deployment with NLB and HTTPS

This comprehensive guide outlines the process of deploying the Go Bedrock application on Amazon EKS with HTTPS support using a Network Load Balancer (NLB).

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

### 3. Deploy the Application with NLB and HTTPS

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
```

Apply the deployment and service:

```bash
kubectl apply -f go-bedrock-deployment.yaml
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

### Check Deployment Status

```bash
kubectl get deployment go-bedrock-app
kubectl get pods -l app=go-bedrock-app
```

### Check Service Status

```bash
kubectl get service go-bedrock-service
```

### Check NLB Listeners

```bash
# Get the NLB ARN
NLB_ARN=$(aws elbv2 describe-load-balancers --region us-west-2 --query "LoadBalancers[?starts_with(LoadBalancerName, 'k8s-default-gobedroc')].LoadBalancerArn" --output text)

# Check listeners
aws elbv2 describe-listeners --region us-west-2 --load-balancer-arn $NLB_ARN --query "Listeners[].{Port:Port,Protocol:Protocol}" --output table
```

### Test HTTPS Access

```bash
# Get the NLB DNS name
NLB_DNS=$(kubectl get service go-bedrock-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test HTTPS access
curl -k https://$NLB_DNS
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

## DNS Configuration

Create a CNAME record for `eks-bedrock.entest.io` pointing to the NLB DNS name:
```
eks-bedrock.entest.io CNAME k8s-default-gobedroc-7797753aed-47551f52435427ac.elb.us-west-2.amazonaws.com
```

After updating the DNS records, verify that the domain resolves correctly:
```bash
dig eks-bedrock.entest.io
```

Once DNS has propagated, test accessing the application via the domain:
```bash
curl -k https://eks-bedrock.entest.io
```

## Troubleshooting

If you encounter issues:

1. Check the pod logs:
   ```bash
   kubectl logs -l app=go-bedrock-app
   ```

2. Check service endpoints:
   ```bash
   kubectl get endpoints go-bedrock-service
   ```

3. Check the AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

4. Verify the NLB target group health:
   ```bash
   aws elbv2 describe-target-health --region us-west-2 --target-group-arn $(aws elbv2 describe-target-groups --region us-west-2 --query "TargetGroups[?starts_with(TargetGroupName, 'k8s-default-gobedroc')].TargetGroupArn" --output text | head -1)
   ```

## Benefits of This Configuration

1. **Simplified Infrastructure**: Single load balancer with a single listener
2. **Enhanced Security**: HTTPS-only access, eliminating unencrypted HTTP traffic
3. **Cost Reduction**: Eliminated redundant load balancers and unnecessary listeners
4. **Improved Performance**: NLBs typically have lower latency than ALBs
5. **Static IP Addresses**: NLBs provide static IP addresses, which can be useful for firewall rules

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
- [NLB Annotations Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/annotations/)
- [AWS NLB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html)
