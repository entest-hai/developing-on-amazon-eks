<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Step-by-Step Guide to Configure DNS Manually in Route 53 (Cross-Account)

If your domain is registered in a different AWS account than where your EKS cluster is running, you'll need to follow these steps to configure DNS manually.

## Prerequisites
- Access to both AWS accounts:
  - Account A: Where your EKS cluster and NLB are running
  - Account B: Where your domain is registered in Route 53
- Appropriate IAM permissions in both accounts

## Step 1: Get the NLB DNS Name from Account A

1. Log in to Account A (where your EKS cluster is running)

2. Get the NLB DNS name using kubectl:
   ```bash
   kubectl get service go-bedrock-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
   
   Example output:
   ```
   k8s-default-gobedroc-29ca929843-a6e0fe1b6942ceef.elb.us-west-2.amazonaws.com
   ```

3. Make note of this DNS name as you'll need it in the next steps

## Step 2: Create a CNAME Record in Account B

1. Log in to Account B (where your domain is registered)

2. Open the AWS Management Console and navigate to Route 53

3. Click on "Hosted zones" in the left navigation panel

4. Select the hosted zone for your domain (e.g., entest.io)

5. Click the "Create record" button

6. Configure the record with the following settings:
   - Record name: Enter the subdomain (e.g., `eks-bedrock` for eks-bedrock.entest.io)
   - Record type: Select "CNAME"
   - Value: Paste the NLB DNS name from Step 1
   - TTL: 300 seconds (or your preferred value)
   - Routing policy: Simple routing (or your preferred policy)

7. Click "Create records"

## Step 3: Verify DNS Propagation

1. Wait for the DNS changes to propagate (this can take from a few minutes up to 48 hours, though typically it's much faster)

2. Check if the DNS record is resolving correctly:
   ```bash
   dig eks-bedrock.entest.io
   ```
   
   Look for the CNAME record pointing to your NLB DNS name in the ANSWER section

3. Once the DNS has propagated, test the connection:
   ```bash
   curl -v https://eks-bedrock.entest.io
   ```

## Step 4: Troubleshooting DNS Issues

If you encounter issues with the DNS configuration:

1. Verify the CNAME record was created correctly:
   ```bash
   dig eks-bedrock.entest.io CNAME
   ```

2. Check if the domain resolves to the correct IP addresses:
   ```bash
   dig eks-bedrock.entest.io A
   ```
   
   Compare these IP addresses with the ones for your NLB:
   ```bash
   dig k8s-default-gobedroc-29ca929843-a6e0fe1b6942ceef.elb.us-west-2.amazonaws.com A
   ```

3. If using a private hosted zone, ensure proper DNS resolution between accounts:
   - You might need to set up Route 53 Resolver endpoints
   - Or configure VPC peering between accounts

## Step 5: Certificate Validation

If you're using an ACM certificate with DNS validation:

1. Ensure all validation CNAME records are properly set up in your Route 53 hosted zone

2. Check the certificate status in ACM:
   ```bash
   aws acm describe-certificate \
     --certificate-arn arn:aws:acm:us-west-2:535915401024:certificate/eb302b0a-8690-47ad-8605-7a9d59e4f656 \
     --region us-west-2
   ```

## Alternative: Using Route 53 Cross-Account Access

For a more integrated approach, you can set up cross-account access for Route 53:

1. In Account B (domain account), create an IAM role with permissions to modify Route 53 records
2. Configure trust relationship to allow Account A to assume this role
3. In Account A, assume the role when making Route 53 changes

This approach is more complex but provides better automation if you're frequently making cross-account DNS changes.

## Security Considerations for Cross-Account DNS

1. **Least Privilege**: When creating IAM roles for cross-account access, follow the principle of least privilege
2. **Audit Logging**: Enable AWS CloudTrail in both accounts to track DNS changes
3. **Regular Review**: Periodically review cross-account permissions to ensure they're still necessary
