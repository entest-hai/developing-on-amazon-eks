# Understanding HTTPS Termination with Network Load Balancers

When using HTTPS with a Network Load Balancer (NLB) for your EKS application, it's important to understand where SSL/TLS termination occurs and how the traffic flows.

## SSL/TLS Termination with NLB

In the configuration we've implemented:

1. **The NLB Terminates SSL/TLS**: 
   - The Network Load Balancer is configured to terminate SSL/TLS connections
   - This is achieved through the `service.beta.kubernetes.io/aws-load-balancer-ssl-cert` annotation that references your ACM certificate
   - The NLB handles the SSL/TLS handshake with clients and decrypts the traffic

2. **Traffic Flow**:
   ```
   Client → HTTPS → NLB (SSL termination) → TCP → EKS Pods
   ```

3. **Key Differences from Application Load Balancer (ALB)**:
   - NLBs operate at Layer 4 (Transport Layer) of the OSI model
   - ALBs operate at Layer 7 (Application Layer)
   - NLBs can't inspect HTTP headers or perform content-based routing
   - NLBs provide lower latency and can handle millions of requests per second

## Configuration Details

The SSL termination is configured through these annotations in the Service manifest:

```yaml
# SSL certificate configuration
service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account-id:certificate/certificate-id"
# SSL ports
service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
```

These annotations instruct the AWS Load Balancer Controller to:
1. Configure the NLB with your ACM certificate
2. Set up a TLS listener on port 443
3. Forward decrypted traffic to your application pods on the target port (3000)

## Security Implications

1. **Encryption Boundary**:
   - Traffic is encrypted between the client and the NLB
   - Traffic between the NLB and the EKS pods is unencrypted (TCP)
   - This is typically acceptable within a VPC, but consider pod-to-pod encryption for highly sensitive workloads

2. **Certificate Management**:
   - The ACM certificate is managed by AWS and automatically renewed
   - The certificate is attached to the NLB, not to your application pods
   - Your application doesn't need to handle TLS certificates or keys

3. **Security Groups**:
   - The NLB security group should allow inbound HTTPS (port 443)
   - The node security group should allow traffic from the NLB to the node port

## End-to-End Encryption (Optional)

If you require encryption all the way to the pods (end-to-end encryption):

1. Configure the NLB for TCP passthrough instead of SSL termination:
   ```yaml
   # Remove the SSL certificate annotation
   # Don't specify SSL ports
   ```

2. Configure your application to handle TLS:
   - Mount certificates as Kubernetes secrets
   - Configure your application to use these certificates
   - Ensure your application listens on HTTPS

3. Update the service to use TCP passthrough:
   ```yaml
   ports:
   - port: 443
     targetPort: 443  # Your app must listen on HTTPS
     protocol: TCP
   ```

This approach is more complex but provides encryption throughout the entire path.

## Performance Considerations

1. **SSL Termination at NLB**:
   - Offloads cryptographic operations from your application
   - Reduces CPU load on your application pods
   - Simplifies certificate management

2. **Connection Handling**:
   - NLBs maintain TCP connections to your pods
   - This reduces connection establishment overhead
   - Provides better performance for long-lived connections

## Monitoring SSL/TLS

To monitor the SSL/TLS termination:

1. Check CloudWatch metrics for the NLB:
   - `ProcessedBytes_TLS`
   - `TLS_ClientHello_Received`
   - `TLS_Error`

2. Enable access logs for the NLB to audit TLS connections:
   ```yaml
   service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
   service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "your-log-bucket"
   service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix: "nlb-logs"
   ```

By understanding these aspects of HTTPS with Network Load Balancers, you can make informed decisions about your security architecture and troubleshoot any SSL/TLS-related issues effectively.

## Confirmation of SSL Termination at NLB

To confirm that SSL/HTTPS is indeed terminated by the Network Load Balancer (NLB) in this configuration:

1. The annotations in the service manifest explicitly configure SSL termination at the NLB:
   ```yaml
   service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account-id:certificate/certificate-id"
   service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
   ```

2. The traffic flow confirms this pattern:
   ```
   Client → HTTPS (443) → NLB (SSL termination) → TCP (3000) → EKS Pods
   ```

3. The application pods receive regular HTTP traffic on port 3000, not HTTPS traffic, indicating that the SSL termination happens before the traffic reaches the pods.

4. The AWS Load Balancer Controller configures the NLB with the specified ACM certificate, which is only possible if the NLB is handling the SSL termination.

This SSL termination at the NLB is a feature that AWS introduced specifically for Network Load Balancers to provide the performance benefits of NLBs while still supporting secure HTTPS connections.

## References

For more information about TLS termination for Network Load Balancers, see the official AWS announcement:
[New – TLS Termination for Network Load Balancers](https://aws.amazon.com/blogs/aws/new-tls-termination-for-network-load-balancers/)
