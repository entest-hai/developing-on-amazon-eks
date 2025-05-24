<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

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

### Security Considerations

1. **Restrict access to your applications**

   Consider implementing security groups or network policies to restrict access to your applications.

2. **Use IAM roles for service accounts**

   Ensure that service accounts have the minimum necessary permissions.

3. **Enable AWS WAF (optional)**

   For additional protection, consider setting up AWS WAF in front of your NLB.

4. **Monitor access logs**

   Enable access logs for your NLB to monitor traffic patterns and detect potential security issues.
