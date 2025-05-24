<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Go Bedrock Application Deployment with ALB and HTTPS

This guide outlines the process of deploying the Go Bedrock application on Amazon EKS with HTTPS support using an Application Load Balancer (ALB).

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

### 3. Deploy the Application

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
```

Apply the deployment:

```bash
kubectl apply -f go-bedrock-deployment.yaml
```

### 4. Create a ClusterIP Service

Create a file named `go-bedrock-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-bedrock-service
spec:
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  selector:
    app: go-bedrock-app
  type: ClusterIP
```

Apply the service:

```bash
kubectl apply -f go-bedrock-service.yaml
```

### 5. Create Ingress Resource for ALB with HTTPS

Create a file named `go-bedrock-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: go-bedrock-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/subnets: subnet-0264e34386cf1651f,subnet-0cd2ba3b40b67a9e5,subnet-0446289a0e1f8dbbd
    external-dns.alpha.kubernetes.io/hostname: eks-bedrock.entest.io
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
kubectl apply -f go-bedrock-ingress.yaml
```

## Key Annotations Explained

| Annotation | Description |
|------------|-------------|
| `kubernetes.io/ingress.class: alb` | Specifies that the AWS Load Balancer Controller should create an ALB |
| `alb.ingress.kubernetes.io/scheme: internet-facing` | Makes the ALB accessible from the internet |
| `alb.ingress.kubernetes.io/target-type: ip` | Routes traffic directly to pod IPs |
| `alb.ingress.kubernetes.io/listen-ports` | Configures the ALB to listen on both HTTP (80) and HTTPS (443) |
| `alb.ingress.kubernetes.io/certificate-arn` | Specifies the ACM certificate for HTTPS |
| `alb.ingress.kubernetes.io/ssl-redirect` | Redirects HTTP traffic to HTTPS |
| `alb.ingress.kubernetes.io/subnets` | Specifies which subnets to create the ALB in |

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

### Check Ingress Status

```bash
kubectl get ingress go-bedrock-ingress
```

Wait for the ALB to be provisioned. Once it's ready, you'll see an ADDRESS value in the ingress status:

```
NAME                 CLASS    HOSTS                   ADDRESS                                                                  PORTS   AGE
go-bedrock-ingress   <none>   eks-bedrock.entest.io   k8s-default-gobedroc-123456789.us-west-2.elb.amazonaws.com              80      2m
```

### Test HTTPS Access

Once the ALB is provisioned, you can access the application using:

1. The ALB DNS with Host header (immediate access):
   ```bash
   # Get the ALB DNS name
   ALB_DNS=$(kubectl get ingress go-bedrock-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   
   # Test with Host header
   curl -k -H "Host: eks-bedrock.entest.io" https://$ALB_DNS
   ```

2. The domain name (after DNS propagation):
   ```bash
   curl -k https://eks-bedrock.entest.io
   ```

## DNS Configuration

Create a CNAME record for `eks-bedrock.entest.io` pointing to the ALB DNS name:
```
eks-bedrock.entest.io CNAME <ALB_DNS_NAME>
```

After updating the DNS records, verify that the domain resolves correctly:
```bash
dig eks-bedrock.entest.io
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

4. Verify the ALB target group health:
   ```bash
   # Get the target group ARN
   TG_ARN=$(aws elbv2 describe-target-groups --region us-west-2 --query "TargetGroups[?starts_with(TargetGroupName, 'k8s-default-gobedroc')].TargetGroupArn" --output text | head -1)
   
   # Check target health
   aws elbv2 describe-target-health --region us-west-2 --target-group-arn $TG_ARN
   ```

5. If you get a 404 error when accessing the ALB directly, you need to use the Host header:
   ```bash
   curl -k -H "Host: eks-bedrock.entest.io" https://$ALB_DNS
   ```

## Benefits of ALB with HTTPS

1. **Advanced Routing**: ALBs support path-based routing, host-based routing, and other Layer 7 features
2. **HTTP/HTTPS Support**: Native support for HTTP and HTTPS protocols
3. **SSL Termination**: Handles SSL/TLS termination efficiently
4. **Authentication Integration**: Can integrate with authentication services
5. **Web Application Firewall**: Can be integrated with AWS WAF for additional security
6. **HTTP to HTTPS Redirection**: Built-in support for redirecting HTTP traffic to HTTPS

## Differences Between ALB and NLB

| Feature | ALB | NLB |
|---------|-----|-----|
| Layer | Layer 7 (Application) | Layer 4 (Transport) |
| Protocol Support | HTTP/HTTPS | TCP/TLS/UDP |
| Routing | Path-based, host-based | Port-based |
| Source IP Preservation | Not preserved by default | Preserved |
| Latency | Slightly higher | Lower |
| Static IP | No | Yes |
| Connection Draining | Yes | Yes |
| SSL Termination | Yes | Yes |
| WebSockets | Yes | Yes |
| gRPC | Yes | Yes |

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
- [ALB Ingress Controller Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
