# AWS Certificate Manager (ACM) Documentation

## Certificate Request Details

A TLS/SSL certificate was requested from AWS Certificate Manager (ACM) with the following specifications:

- **Domain Name**: eks-bedrock.entest.io
- **AWS Region**: us-west-2
- **Validation Method**: Email (to parent domain entest.io)
- **Certificate ARN**: arn:aws:acm:us-west-2:535915401024:certificate/eb302b0a-8690-47ad-8605-7a9d59e4f656
- **Request Date**: May 18, 2025

## Validation Process

The certificate was configured for email validation to the parent domain. AWS sends validation emails to the following addresses associated with the domain:
- admin@entest.io
- administrator@entest.io
- hostmaster@entest.io
- postmaster@entest.io
- webmaster@entest.io

The domain owner must click the approval link in the validation email to complete the certificate issuance process.

## Certificate Usage

Once validated, this certificate can be used with various AWS services including:
- Amazon EKS (for securing Kubernetes ingress)
- Elastic Load Balancers
- API Gateway
- CloudFront distributions

## AWS CLI Command Used

```bash
aws acm request-certificate \
    --domain-name eks-bedrock.entest.io \
    --validation-method EMAIL \
    --domain-validation-options "[{\"ValidationDomain\": \"entest.io\", \"DomainName\": \"eks-bedrock.entest.io\"}]" \
    --region us-west-2
```

## Certificate Management

To check the status of the certificate:
```bash
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:us-west-2:535915401024:certificate/eb302b0a-8690-47ad-8605-7a9d59e4f656 \
    --region us-west-2
```

To delete the certificate if needed:
```bash
aws acm delete-certificate \
    --certificate-arn arn:aws:acm:us-west-2:535915401024:certificate/eb302b0a-8690-47ad-8605-7a9d59e4f656 \
    --region us-west-2
```

## Notes
- The certificate is managed in a different AWS account than the one where the domain (entest.io) is registered
- Certificate renewals are handled automatically by AWS if the domain continues to be validated
- Email validation is sent to the parent domain (entest.io) addresses rather than the subdomain
