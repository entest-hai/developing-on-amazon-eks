# Deploying Go Bedrock Application with HTTPS

This document provides instructions for configuring the Go Bedrock application to use HTTPS with a custom domain and AWS Certificate Manager (ACM) certificate.

## Prerequisites

- An existing Go Bedrock application deployed on Amazon EKS
- A registered domain name
- An ACM certificate for your domain
- AWS Load Balancer Controller installed on your EKS cluster
- (Optional) ExternalDNS controller for automatic DNS record management

## Overview

To enable HTTPS for your Go Bedrock application, you'll need to:

1. Create or obtain an ACM certificate for your domain
2. Configure the Kubernetes service to use the ACM certificate
3. Update DNS settings to point your domain to the load balancer

## ACM Certificate

Before configuring HTTPS, you need a valid ACM certificate for your domain. The certificate should be created in the same region as your EKS cluster.

```bash
# Verify your ACM certificate
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:region:account-id:certificate/certificate-id \
  --region region
```

Make sure the certificate status is "ISSUED" before proceeding.

## Service Configuration for HTTPS

Create a Kubernetes service manifest that includes the necessary annotations for HTTPS:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-bedrock-service
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
    # SSL certificate configuration
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account-id:certificate/certificate-id"
    # SSL ports
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    # Custom domain name (for ExternalDNS)
    external-dns.alpha.kubernetes.io/hostname: "your-domain.example.com"
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

### Key Annotations Explained

1. **SSL Certificate Configuration**:
   ```yaml
   service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account-id:certificate/certificate-id"
   ```
   This annotation specifies the ARN of your ACM certificate. The AWS Load Balancer Controller will configure the load balancer to use this certificate for SSL termination.

2. **SSL Ports**:
   ```yaml
   service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
   ```
   This annotation specifies which ports should use SSL. In this case, port 443 (HTTPS).

3. **Custom Domain Name**:
   ```yaml
   external-dns.alpha.kubernetes.io/hostname: "your-domain.example.com"
   ```
   This annotation is used by ExternalDNS to automatically create a DNS record pointing your domain to the load balancer.

## Applying the Configuration

Save the above YAML to a file (e.g., `go-bedrock-app-service-https.yaml`) and apply it:

```bash
kubectl apply -f go-bedrock-app-service-https.yaml
```

## Verifying the Service

Check that the service has been created with the correct configuration:

```bash
kubectl get service go-bedrock-service
```

You should see output similar to:
```
NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP                                                  PORT(S)         AGE
go-bedrock-service   LoadBalancer   172.20.186.119   k8s-default-gobedroc-xxxx.region.elb.amazonaws.com          443:31562/TCP   10m
```

## DNS Configuration

### Option 1: Using ExternalDNS (Automatic)

If you have ExternalDNS installed in your cluster, it will automatically create a DNS record based on the `external-dns.alpha.kubernetes.io/hostname` annotation. No additional steps are required.

To verify that ExternalDNS has created the record:

```bash
# For Route 53
aws route53 list-resource-record-sets \
  --hosted-zone-id your-hosted-zone-id \
  --query "ResourceRecordSets[?Name=='your-domain.example.com.']"
```

### Option 2: Manual DNS Configuration

If you're not using ExternalDNS, you'll need to manually create a CNAME record in your DNS settings:

1. Get the load balancer's DNS name:
   ```bash
   kubectl get service go-bedrock-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. Create a CNAME record in your DNS provider's console:
   - Record type: CNAME
   - Name: your subdomain (e.g., `bedrock` for `bedrock.example.com`)
   - Value: The load balancer DNS name from the previous step
   - TTL: 300 seconds (or as appropriate for your setup)

## Testing the HTTPS Configuration

Once the DNS changes have propagated, you can test your HTTPS configuration:

```bash
curl -v https://your-domain.example.com
```

You should see that the connection is secure and the certificate is valid.

### Testing with the NLB Endpoint Directly

If you need to test the HTTPS configuration before DNS propagation or to troubleshoot issues, you can access the NLB endpoint directly:

```bash
# Using the -k flag to skip certificate validation
curl -v -k https://k8s-default-gobedroc-29ca929843-a6e0fe1b6942ceef.elb.us-west-2.amazonaws.com
```

The `-k` flag is necessary because:
1. The certificate is issued for your custom domain (e.g., eks-bedrock.entest.io)
2. You're accessing the load balancer using its AWS-assigned DNS name
3. This causes a certificate name mismatch error without the `-k` flag

Note that this approach is only for testing and troubleshooting. In production, users should access your application through the custom domain name.

### Testing HTTP Traffic

If you need to test the application without HTTPS, you can create a separate ClusterIP service that exposes the application internally, then use port-forwarding:

```bash
# Create an internal service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: go-bedrock-internal
  namespace: default
spec:
  selector:
    app: go-bedrock-app
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF

# Set up port forwarding
kubectl port-forward svc/go-bedrock-internal 3000:3000
```

Then in another terminal:
```bash
curl http://localhost:3000
```

## Troubleshooting

### Certificate Issues

If you encounter certificate issues:

1. Verify that the certificate is valid and issued:
   ```bash
   aws acm describe-certificate \
     --certificate-arn arn:aws:acm:region:account-id:certificate/certificate-id \
     --region region
   ```

2. Make sure the certificate includes the domain you're using.

3. Check that the certificate is in the same region as your EKS cluster.

### DNS Issues

If your domain is not resolving to the load balancer:

1. Verify that the DNS record exists:
   ```bash
   dig your-domain.example.com
   ```

2. Check that the CNAME record points to the correct load balancer DNS name.

3. Allow time for DNS propagation (can take up to 48 hours, but typically much less).

### Load Balancer Issues

If the load balancer is not properly configured:

1. Check the load balancer configuration in the AWS Console.

2. Verify that the target group health checks are passing.

3. Check the AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

## Security Considerations

1. **TLS Version**: By default, the AWS Load Balancer Controller configures the load balancer to use TLS 1.2. If you need to specify a different TLS policy, you can use the `service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy` annotation.

2. **HTTP to HTTPS Redirection**: The configuration above only exposes HTTPS (port 443). If you also want to support HTTP and redirect to HTTPS, you would need to use an Application Load Balancer with an Ingress resource instead of a Network Load Balancer.

3. **Certificate Renewal**: ACM automatically handles certificate renewal for certificates issued through ACM. No additional configuration is needed.

## Conclusion

By following these steps, you've configured your Go Bedrock application to use HTTPS with a custom domain and ACM certificate. This provides secure, encrypted communication between clients and your application, protecting sensitive data and building trust with your users.
