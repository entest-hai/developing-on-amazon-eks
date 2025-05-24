<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Amazon EKS Deployment Runbook

This runbook provides step-by-step instructions for deploying and managing applications on Amazon EKS using this repository.

## Table of Contents

1. [Deploy EKS Cluster](#deploy-eks-cluster)
2. [Set Up kubectl](#set-up-kubectl)
3. [Deploy Go Web Demo Application](#deploy-go-web-demo-application)
4. [Deploy Go Bedrock Application](#deploy-go-bedrock-application)
5. [Expose Go Web App via HTTPS with NLB](#expose-go-web-app-via-https-with-nlb)
6. [Expose Go Bedrock App via HTTPS with NLB](#expose-go-bedrock-app-via-https-with-nlb)
7. [Deploy Amazon CloudWatch Observability Add-on](#deploy-amazon-cloudwatch-observability-add-on)

## Deploy EKS Cluster

The repository contains CloudFormation templates to set up a complete EKS environment including networking, cluster, and IAM resources.

### Prerequisites

- AWS CLI installed and configured with appropriate permissions
- AWS region set to your preferred region (default: us-west-2)

### Deployment Steps

1. **Clone the repository and navigate to the template directory**

   ```bash
   cd template
   ```

2. **Deploy the network stack**

   This creates the VPC, subnets, and other networking components:

   ```bash
   aws cloudformation create-stack \
     --stack-name eks-network-stack \
     --template-body file://1-network.yaml \
     --capabilities CAPABILITY_NAMED_IAM
   ```

3. **Deploy the EKS cluster stack**

   This creates the EKS cluster and node group:

   ```bash
   aws cloudformation create-stack \
     --stack-name eks-stack \
     --template-body file://2-eks.yaml \
     --capabilities CAPABILITY_NAMED_IAM
   ```

4. **Deploy the IAM stack**

   This creates the necessary IAM roles and policies for the EKS cluster:

   ```bash
   aws cloudformation create-stack \
     --stack-name iam-stack \
     --template-body file://3-iam.yaml \
     --capabilities CAPABILITY_NAMED_IAM
   ```

5. **Monitor stack creation**

   You can monitor the stack creation in the AWS CloudFormation console or using the AWS CLI:

   ```bash
   aws cloudformation describe-stacks --stack-name eks-network-stack
   aws cloudformation describe-stacks --stack-name eks-stack
   aws cloudformation describe-stacks --stack-name iam-stack
   ```

   Wait until all stacks show `CREATE_COMPLETE` status before proceeding.

### Stack Details

- **Network Stack**: Creates VPC with CIDR 10.0.0.0/16 and three public subnets
- **EKS Stack**: Creates an EKS cluster with version 1.30 and t3.medium node instances
- **IAM Stack**: Sets up OIDC provider and roles for EKS add-ons like the CSI driver

## Set Up kubectl

After deploying the EKS cluster, you need to configure kubectl to interact with it.

### Prerequisites

- kubectl installed on your local machine or EC2 instance
- AWS CLI installed and configured

### Configuration Steps

1. **Update kubeconfig to connect to your EKS cluster**

   ```bash
   aws eks update-kubeconfig --name eks-stack-eks-cluster --region us-west-2
   ```

2. **Verify the connection to the cluster**

   ```bash
   kubectl get nodes -A
   ```

   You should see the worker nodes that are part of your EKS cluster.

3. **Verify system pods are running**

   ```bash
   kubectl get pods -n kube-system
   ```

   This should show core Kubernetes system pods running.

### Troubleshooting kubectl Access

If you encounter authentication issues:

1. **Check AWS CLI credentials**

   ```bash
   aws sts get-caller-identity
   ```

2. **Verify IAM permissions**

   Ensure your IAM user or role has permissions to access the EKS cluster.

3. **Check kubeconfig**

   ```bash
   kubectl config view
   ```

## Deploy Go Web Demo Application

This section covers deploying the Go Web Demo application to your EKS cluster.

### Prerequisites

- EKS cluster deployed and kubectl configured
- ECR repository for the application images

### Build and Push the Docker Image

1. **Navigate to the application directory**

   ```bash
   cd app/go-web-demo
   ```

2. **Build and push the Docker image to ECR**

   ```bash
   ./build.sh --repository-name go-book-app --region us-west-2
   ```

   This script:
   - Builds the Docker image
   - Creates the ECR repository if it doesn't exist
   - Tags and pushes the image to ECR

### Deploy the Application

1. **Deploy the application to EKS**

   ```bash
   kubectl apply -f deploy/book-pod.yaml
   ```

2. **Verify the deployment**

   ```bash
   kubectl get pods -l app=go-book-app
   ```

   Wait until the pod status shows `1/1` in the READY column.

### Access the Application via Port Forwarding

1. **Set up port forwarding**

   ```bash
   kubectl port-forward deployment/go-book-app 8080:3000
   ```

   For background port forwarding:

   ```bash
   nohup kubectl port-forward deployment/go-book-app 8080:3000 > /tmp/port-forward.log 2>&1 &
   ```

2. **Access the application**

   Open a web browser and navigate to:
   ```
   http://localhost:8080
   ```

3. **Stop port forwarding when done**

   ```bash
   pkill -f "kubectl port-forward deployment/go-book-app"
   ```

## Deploy Go Bedrock Application

This section covers deploying the Go Bedrock application, which integrates with Amazon Bedrock.

### Prerequisites

- EKS cluster deployed and kubectl configured
- ECR repository for the application images
- Service account with appropriate permissions for Amazon Bedrock access

### Create Service Account for Bedrock Access

1. **Check if the service account exists**

   ```bash
   kubectl get serviceaccount bedrock-service-account || echo "Service account does not exist"
   ```

2. **If it doesn't exist, create it**

   ```bash
   kubectl create serviceaccount bedrock-service-account
   ```

3. **Create IAM role and attach policies for Amazon Bedrock access**

   The application requires permissions to invoke all foundation models in Amazon Bedrock in the us-west-2 region.

   a. **Create a trust policy for the IAM role**

   Create a file named `trust-policy.json`:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/YOUR_OIDC_PROVIDER_ID"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "oidc.eks.us-west-2.amazonaws.com/id/YOUR_OIDC_PROVIDER_ID:sub": "system:serviceaccount:default:bedrock-service-account"
           }
         }
       }
     ]
   }
   ```

   Replace:
   - `YOUR_ACCOUNT_ID`: Your AWS account ID
   - `YOUR_OIDC_PROVIDER_ID`: Your EKS cluster's OIDC provider ID

   b. **Create a Bedrock permissions policy**

   Create a file named `bedrock-policy.json`:

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
           "bedrock:ListFoundationModels",
           "bedrock:GetFoundationModel"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

   c. **Create the IAM role and attach the policy**

   ```bash
   # Create the IAM role with the trust policy
   aws iam create-role --role-name bedrock-eks-role --assume-role-policy-document file://trust-policy.json

   # Create the IAM policy for Bedrock access
   aws iam create-policy --policy-name bedrock-access-policy --policy-document file://bedrock-policy.json

   # Attach the policy to the role
   aws iam attach-role-policy --role-name bedrock-eks-role --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/bedrock-access-policy
   ```

   d. **Annotate the service account with the IAM role**

   ```bash
   kubectl annotate serviceaccount bedrock-service-account eks.amazonaws.com/role-arn=arn:aws:iam::YOUR_ACCOUNT_ID:role/bedrock-eks-role
   ```

   This setup enables the service account to assume the IAM role, which has permissions to invoke all foundation models in Amazon Bedrock in the us-west-2 region.

### Build and Push the Docker Image

1. **Navigate to the application directory**

   ```bash
   cd app/go-bedrock-app
   ```

2. **Build and push the Docker image to ECR**

   ```bash
   ./build.sh --repository-name go-bedrock-app --region us-west-2 --tag v7
   ```

   This script:
   - Builds the Docker image
   - Creates the ECR repository if it doesn't exist
   - Tags and pushes the image to ECR

### Deploy the Application

1. **Deploy the application to EKS**

   ```bash
   kubectl apply -f deploy/go-bedrock-deployment.yaml
   ```

2. **Verify the deployment**

   ```bash
   kubectl get pods -l app=go-bedrock-app
   ```

   Wait until the pods status shows `1/1` in the READY column.

### Access the Application via Port Forwarding

1. **Set up port forwarding**

   ```bash
   kubectl port-forward deployment/go-bedrock-app 8081:3000
   ```

   For background port forwarding:

   ```bash
   nohup kubectl port-forward deployment/go-bedrock-app 8081:3000 > /tmp/bedrock-port-forward.log 2>&1 &
   ```

2. **Access the application**

   Open a web browser and navigate to:
   ```
   http://localhost:8081
   ```

3. **Stop port forwarding when done**

   ```bash
   pkill -f "kubectl port-forward deployment/go-bedrock-app"
   ```

## Troubleshooting

### Common Issues with EKS Deployment

1. **CloudFormation stack creation fails**
   - Check the stack events in the AWS CloudFormation console
   - Verify IAM permissions
   - Check for resource limits in your AWS account

2. **Nodes not joining the cluster**
   - Check security groups and VPC settings
   - Verify node IAM role permissions
   - Check node bootstrap logs

### Common Issues with Application Deployment

1. **Image pull errors**
   - Verify ECR repository exists and contains the image
   - Check node IAM role has permissions to pull from ECR
   - Verify image tag in deployment YAML matches what's in ECR

2. **Application pod not starting**
   - Check pod logs: `kubectl logs deployment/go-book-app`
   - Describe the pod: `kubectl describe pod <pod-name>`
   - Verify resource requests and limits are appropriate

3. **Port forwarding issues**
   - Verify the pod is running
   - Check if the specified port is already in use
   - Try a different local port

### Amazon Bedrock Access Issues

If the Go Bedrock application cannot access Amazon Bedrock:

1. Verify the service account has the correct IAM role attached
2. Check the IAM role has the necessary permissions for Amazon Bedrock
3. Ensure the AWS_REGION environment variable in the deployment matches your Bedrock region

## Cleanup

To clean up resources when they're no longer needed:

1. **Delete application deployments**

   ```bash
   kubectl delete -f app/go-web-demo/deploy/book-pod.yaml
   kubectl delete -f app/go-bedrock-app/deploy/go-bedrock-deployment.yaml
   ```

2. **Delete CloudFormation stacks**

   Delete in reverse order of creation:

   ```bash
   aws cloudformation delete-stack --stack-name iam-stack
   aws cloudformation delete-stack --stack-name eks-stack
   aws cloudformation delete-stack --stack-name eks-network-stack
   ```

3. **Delete ECR repositories (optional)**

   ```bash
   aws ecr delete-repository --repository-name go-book-app --force
   aws ecr delete-repository --repository-name go-bedrock-app --force
   ```
## Expose Go Web App via HTTPS with NLB

This section covers exposing the Go Web Demo application to the internet using a Network Load Balancer (NLB) with HTTPS.

### Prerequisites

- Go Web Demo application deployed to EKS
- AWS Certificate Manager (ACM) certificate for your domain
- AWS Load Balancer Controller installed on your EKS cluster
- DNS management access for your domain

### Create an SSL Certificate in ACM

1. **Create or import an SSL certificate in AWS Certificate Manager**

   ```bash
   # Create a new certificate
   aws acm request-certificate \
     --domain-name your-domain.example.com \
     --validation-method DNS \
     --region us-west-2
   ```

   Note the certificate ARN from the output. You'll need this later.

2. **Complete DNS validation for the certificate**

   Follow the instructions in the AWS console to validate your domain ownership.

### Create a Network Load Balancer Service

1. **Create a service YAML file for the NLB**

   Create a file named `go-book-app-service-https.yaml` with the following content:

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: go-book-app-nlb-https
     namespace: default
     annotations:
       # Use AWS Load Balancer Controller
       service.beta.kubernetes.io/aws-load-balancer-type: "external"
       # Use NLB (Network Load Balancer)
       service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
       # Internet facing
       service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
       # Use TCP protocol
       service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
       # Enable cross-zone load balancing
       service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
       # Health check configuration
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "http"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "3000"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
       # REPLACE: Update with your actual AWS account ID and certificate ID
       service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID"
       # SSL ports
       service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
       # REPLACE: Update with your actual domain name
       external-dns.alpha.kubernetes.io/hostname: "your-domain.example.com"
   spec:
     selector:
       app: go-book-app
     ports:
     - name: https
       port: 443
       targetPort: 3000
       protocol: TCP
     type: LoadBalancer
   ```

   **Important**: Replace the following placeholders:
   - `YOUR_ACCOUNT_ID`: Your AWS account ID
   - `YOUR_CERTIFICATE_ID`: The ID of your ACM certificate
   - `your-domain.example.com`: Your actual domain name

2. **Apply the service configuration**

   ```bash
   kubectl apply -f go-book-app-service-https.yaml
   ```

3. **Verify the service creation**

   ```bash
   kubectl get service go-book-app-nlb-https
   ```

   Wait until an external IP (DNS name) is assigned.

### Configure DNS

1. **Get the NLB DNS name**

   ```bash
   kubectl get service go-book-app-nlb-https -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. **Create a CNAME record in your DNS provider**

   Create a CNAME record pointing your domain (e.g., `your-domain.example.com`) to the NLB DNS name.

   If you're using Route 53:

   ```bash
   # Get the Hosted Zone ID
   aws route53 list-hosted-zones --query "HostedZones[?Name=='example.com.'].Id" --output text

   # Create the record
   aws route53 change-resource-record-sets \
     --hosted-zone-id YOUR_HOSTED_ZONE_ID \
     --change-batch '{
       "Changes": [
         {
           "Action": "UPSERT",
           "ResourceRecordSet": {
             "Name": "your-domain.example.com",
             "Type": "CNAME",
             "TTL": 300,
             "ResourceRecords": [
               {
                 "Value": "NLB_DNS_NAME"
               }
             ]
           }
         }
       ]
     }'
   ```

   Replace:
   - `YOUR_HOSTED_ZONE_ID`: Your Route 53 hosted zone ID
   - `NLB_DNS_NAME`: The DNS name of your NLB

### Verify HTTPS Access

1. **Wait for DNS propagation**

   It may take some time for DNS changes to propagate.

2. **Access your application**

   Open a web browser and navigate to:
   ```
   https://your-domain.example.com
   ```

3. **Verify SSL certificate**

   Check that the connection is secure and the certificate is valid.

## Expose Go Bedrock App via HTTPS with NLB

This section covers exposing the Go Bedrock application to the internet using a Network Load Balancer (NLB) with HTTPS.

### Prerequisites

- Go Bedrock application deployed to EKS
- AWS Certificate Manager (ACM) certificate for your domain
- AWS Load Balancer Controller installed on your EKS cluster
- DNS management access for your domain
- Service account with appropriate permissions for Amazon Bedrock access

### Create an SSL Certificate in ACM

1. **Create or import an SSL certificate in AWS Certificate Manager**

   ```bash
   # Create a new certificate
   aws acm request-certificate \
     --domain-name bedrock-app.example.com \
     --validation-method DNS \
     --region us-west-2
   ```

   Note the certificate ARN from the output. You'll need this later.

2. **Complete DNS validation for the certificate**

   Follow the instructions in the AWS console to validate your domain ownership.

### Create a Network Load Balancer Service

1. **Create a service YAML file for the NLB**

   Create a file named `go-bedrock-app-service-https.yaml` with the following content:

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: go-bedrock-service-https
     namespace: default
     annotations:
       # Use AWS Load Balancer Controller
       service.beta.kubernetes.io/aws-load-balancer-type: "external"
       # Use NLB (Network Load Balancer)
       service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
       # Internet facing
       service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
       # Use TLS protocol
       service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
       # Enable cross-zone load balancing
       service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
       # Health check configuration
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "http"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "3000"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "15"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
       service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
       # REPLACE: Update with your actual AWS account ID and certificate ID
       service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID"
       # SSL ports
       service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
       # REPLACE: Update with your actual domain name
       external-dns.alpha.kubernetes.io/hostname: "bedrock-app.example.com"
     spec:
       selector:
         app: go-bedrock-app
       ports:
       - name: https
         port: 443
         targetPort: 3000
         protocol: TCP
       type: LoadBalancer
   ```

   **Important**: Replace the following placeholders:
   - `YOUR_ACCOUNT_ID`: Your AWS account ID
   - `YOUR_CERTIFICATE_ID`: The ID of your ACM certificate
   - `bedrock-app.example.com`: Your actual domain name

2. **Apply the service configuration**

   ```bash
   kubectl apply -f go-bedrock-app-service-https.yaml
   ```

3. **Verify the service creation**

   ```bash
   kubectl get service go-bedrock-service-https
   ```

   Wait until an external IP (DNS name) is assigned.

### Configure DNS

1. **Get the NLB DNS name**

   ```bash
   kubectl get service go-bedrock-service-https -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. **Create a CNAME record in your DNS provider**

   Create a CNAME record pointing your domain (e.g., `bedrock-app.example.com`) to the NLB DNS name.

   If you're using Route 53:

   ```bash
   # Get the Hosted Zone ID
   aws route53 list-hosted-zones --query "HostedZones[?Name=='example.com.'].Id" --output text

   # Create the record
   aws route53 change-resource-record-sets \
     --hosted-zone-id YOUR_HOSTED_ZONE_ID \
     --change-batch '{
       "Changes": [
         {
           "Action": "UPSERT",
           "ResourceRecordSet": {
             "Name": "bedrock-app.example.com",
             "Type": "CNAME",
             "TTL": 300,
             "ResourceRecords": [
               {
                 "Value": "NLB_DNS_NAME"
               }
             ]
           }
         }
       ]
     }'
   ```

   Replace:
   - `YOUR_HOSTED_ZONE_ID`: Your Route 53 hosted zone ID
   - `NLB_DNS_NAME`: The DNS name of your NLB

### Verify HTTPS Access

1. **Wait for DNS propagation**

   It may take some time for DNS changes to propagate.

2. **Access your application**

   Open a web browser and navigate to:
   ```
   https://bedrock-app.example.com
   ```

3. **Verify SSL certificate**

   Check that the connection is secure and the certificate is valid.

### Troubleshooting HTTPS Access

If you encounter issues with HTTPS access:

1. **Check certificate status**

   ```bash
   aws acm describe-certificate --certificate-arn arn:aws:acm:us-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID
   ```

2. **Verify NLB configuration**

   ```bash
   kubectl describe service go-bedrock-service-https
   ```

3. **Check for TLS handshake issues**

   ```bash
   openssl s_client -connect bedrock-app.example.com:443 -servername bedrock-app.example.com
   ```

4. **Verify that the service account has the necessary permissions**

   For the Go Bedrock application, ensure the service account has permissions to access Amazon Bedrock:

   ```bash
   kubectl describe serviceaccount bedrock-service-account
   ```

5. **Check Bedrock permissions**

   Verify that the IAM role has the necessary permissions to invoke all foundation models in Amazon Bedrock:

   ```bash
   aws iam get-role-policy --role-name bedrock-eks-role --policy-name bedrock-access-policy
   ```

   The policy should include permissions for:
   - `bedrock:InvokeModel`
   - `bedrock:InvokeModelWithResponseStream`
   - `bedrock:ListFoundationModels`
   - `bedrock:GetFoundationModel`

6. **Check pod logs for permission errors**

   ```bash
   kubectl logs deployment/go-bedrock-app
   ```

   Look for any errors related to Amazon Bedrock access or permission denied messages.

7. **Test Bedrock access from within the pod**

   ```bash
   kubectl exec -it $(kubectl get pod -l app=go-bedrock-app -o jsonpath='{.items[0].metadata.name}') -- /bin/sh -c "AWS_REGION=us-west-2 aws bedrock list-foundation-models"
   ```

   This command attempts to list foundation models from within the pod to verify that the service account has the correct permissions.

### Security Considerations

1. **Restrict access to your applications**

   Consider implementing security groups or network policies to restrict access to your applications.

2. **Use IAM roles for service accounts**

   Ensure that service accounts have the minimum necessary permissions.

3. **Enable AWS WAF (optional)**

   For additional protection, consider setting up AWS WAF in front of your NLB.

4. **Monitor access logs**

   Enable access logs for your NLB to monitor traffic patterns and detect potential security issues.
## Deploy Amazon CloudWatch Observability Add-on

This section covers deploying the Amazon CloudWatch Observability add-on to your EKS cluster to collect metrics and logs from your applications.

### Prerequisites

- EKS cluster deployed and kubectl configured
- AWS CLI installed and configured with appropriate permissions
- IAM permissions to create policies and roles

### Option 1: Deploy CloudWatch Observability Using IAM Roles for Service Accounts (IRSA)

This is the traditional method for providing AWS IAM permissions to pods in an EKS cluster.

#### 1. Create IAM Policy for CloudWatch Observability

Create a file named `cloudwatch-observability-policy.json` with the following content:

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

Note the ARN of the created policy for use in the next step.

#### 2. Create Namespace for CloudWatch Observability

```bash
kubectl create namespace amazon-cloudwatch
```

#### 3. Create IAM Service Account

```bash
eksctl create iamserviceaccount \
    --name cloudwatch-observability \
    --namespace amazon-cloudwatch \
    --cluster eks-stack-eks-cluster \
    --attach-policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/CloudWatchObservabilityPolicy \
    --approve \
    --region us-west-2
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

#### 4. Install CloudWatch Observability Add-on

```bash
eksctl create addon \
    --name amazon-cloudwatch-observability \
    --cluster eks-stack-eks-cluster \
    --service-account-role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/eksctl-eks-stack-eks-cluster-addon-iamserviceaccount-Role1-XXXXXXXXXXXX \
    --region us-west-2
```

Replace:
- `YOUR_ACCOUNT_ID` with your actual AWS account ID
- The role name with the actual role name created by eksctl in the previous step

#### 5. Verify Installation

Check the add-on status:

```bash
eksctl get addon --cluster eks-stack-eks-cluster --region us-west-2
```

Check the CloudWatch Observability pods:

```bash
kubectl get pods -n amazon-cloudwatch
```

You should see pods for the CloudWatch agent, Fluent Bit, and the controller manager.

### Option 2: Deploy CloudWatch Observability Using Pod Identity

This is a newer, more streamlined approach for EKS clusters version 1.24 or later.

#### 1. Create IAM Policy for CloudWatch Observability

Create a file named `cloudwatch-observability-policy.json` with the following content:

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

#### 2. Create IAM Role for Pod Identity

```bash
# Create IAM role
aws iam create-role \
  --role-name CloudWatchObservabilityPodIdentityRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "pods.eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach policy to role
aws iam attach-role-policy \
  --role-name CloudWatchObservabilityPodIdentityRole \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/CloudWatchObservabilityPolicy
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

#### 3. Create Namespace and Service Account

```bash
# Create namespace
kubectl create namespace amazon-cloudwatch

# Create service account (without any annotations)
kubectl create serviceaccount cloudwatch-observability -n amazon-cloudwatch
```

#### 4. Create Pod Identity Association

```bash
aws eks create-pod-identity-association \
  --cluster-name eks-stack-eks-cluster \
  --namespace amazon-cloudwatch \
  --service-account cloudwatch-observability \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/CloudWatchObservabilityPodIdentityRole
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

#### 5. Install CloudWatch Observability Add-on with Pod Identity

```bash
eksctl create addon \
  --name amazon-cloudwatch-observability \
  --cluster eks-stack-eks-cluster \
  --region us-west-2 \
  --configuration-values '{
    "serviceAccount": {
      "name": "cloudwatch-observability",
      "create": false
    }
  }'
```

#### 6. Verify Pod Identity Association

```bash
# List Pod Identity associations
aws eks list-pod-identity-associations --cluster-name eks-stack-eks-cluster

# Verify the CloudWatch agent pods are running
kubectl get pods -n amazon-cloudwatch
```

### Update Applications to Use CloudWatch Logging

#### 1. Update Go Web Demo Application

Create a file named `go-book-app-observability.yaml` with the following content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-book-app
  namespace: default
  labels:
    app: go-book-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-book-app
  template:
    metadata:
      labels:
        app: go-book-app
      annotations:
        fluentbit.io/parser: cri  # Add this annotation for CloudWatch logging
    spec:
      containers:
      - name: go-book-app
        # REPLACE: Update with your actual AWS account ID in the image URL
        image: YOUR_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/go-book-app:latest
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

Apply the updated deployment:

```bash
kubectl apply -f go-book-app-observability.yaml
```

#### 2. Update Go Bedrock Application

Create a file named `go-bedrock-app-observability.yaml` with the following content:

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
        fluentbit.io/parser: cri  # Add this annotation for CloudWatch logging
    spec:
      serviceAccountName: bedrock-service-account
      containers:
      - name: go-bedrock-app
        # REPLACE: Update with your actual AWS account ID in the image URL
        image: YOUR_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/go-bedrock-app:v7
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        env:
        - name: AWS_REGION
          value: "us-west-2"
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

Apply the updated deployment:

```bash
kubectl apply -f go-bedrock-app-observability.yaml
```

### Accessing CloudWatch Data

#### 1. Container Insights Dashboard

1. Open the CloudWatch console: https://console.aws.amazon.com/cloudwatch/
2. Navigate to "Container Insights" in the left sidebar
3. Select the cluster "eks-stack-eks-cluster"

You can view:
- Cluster performance metrics
- Node metrics
- Pod metrics
- Service metrics

#### 2. Log Groups

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

#### 3. Viewing Application Logs

To view logs for specific applications:

1. Go to CloudWatch console
2. Navigate to "Log groups"
3. Select `/aws/containerinsights/eks-stack-eks-cluster/application`
4. Use the search feature with these filters:
   - For go-bedrock-app: `kubernetes.pod_name: go-bedrock-app`
   - For go-book-app: `kubernetes.pod_name: go-book-app`

### Setting Up Alarms

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
    --alarm-actions arn:aws:sns:us-west-2:YOUR_ACCOUNT_ID:your-sns-topic
```

Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

### Troubleshooting CloudWatch Observability

#### 1. Checking Add-on Status

```bash
aws eks describe-addon \
    --cluster-name eks-stack-eks-cluster \
    --addon-name amazon-cloudwatch-observability \
    --region us-west-2
```

#### 2. Checking Agent Logs

```bash
kubectl logs -n amazon-cloudwatch -l k8s-app=cloudwatch-agent
```

#### 3. Checking Fluent Bit Logs

```bash
kubectl logs -n amazon-cloudwatch -l k8s-app=fluent-bit
```

#### 4. Common Issues and Solutions

1. **Pods not showing in Container Insights**:
   - Check that the CloudWatch agent is running
   - Verify the service account has the correct permissions

2. **Logs not appearing in CloudWatch**:
   - Check that Fluent Bit pods are running
   - Verify the `fluentbit.io/parser: cri` annotation is present in your pod template
   - Check Fluent Bit logs for errors

3. **Permission errors**:
   - Verify the IAM policy has all required permissions
   - Check that the service account is properly configured with the IAM role

4. **Pod Identity issues**:
   - Ensure your EKS cluster version is 1.24 or later
   - Verify the Pod Identity association exists
   - Check that the IAM role trust policy is correctly configured
