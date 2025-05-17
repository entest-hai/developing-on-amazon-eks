---
title: kubectl authentication cluster access 
author: haimtran
date: 19/07/2024
---

## Config File

Command to get the CA certificate.

```bash
aws eks describe-cluster \
--region=us-west-2 \
--name=eks-cluster-stack-eks-cluster \
--output=text \
--query 'cluster.{certificateAuthorityData: certificateAuthority.data}' | base64 -D
```

Save the CA into a file.

```bash
aws eks describe-cluster --name eks-cluster-stack-eks-cluster \
--query "cluster.certificateAuthority.data" \
--output text| base64 --decode > eks.crt
```

Decode the X-509 certificate online and get below information.

```bash
Issued To: CN=kubernetes
Issued By: CN=kubernetes
Serial Number: 14 b9 d8 f0 f9 e4 3e 45
Issued On: Thu Jul 18 2024 13:01:03 GMT+0700 (Indochina Time)
Expires On: Sun Jul 16 2034 13:06:03 GMT+0700 (Indochina Time)
SHA-256 Fingerprint: a5 01 18 a4 e1 ea 52 53 03 25 74 c0 5a d2 01 a0 11 16 fb 27 1e a6 9c e4 55 4c 60 70 b0 c5 5f b4
SHA-1 Fingerprint: 8b 5e 05 7a e0 8f 5b 2e 65 8b 5d ed e9 6b 5f 13 03 e1 bc 35
```

Get token.

```bash
aws eks get-token --cluster-name eks-cluster-stack-eks-cluster
```

Received token.

```json
{
  "kind": "ExecCredential",
  "apiVersion": "client.authentication.k8s.io/v1beta1",
  "spec": {},
  "status": {
    "expirationTimestamp": "2024-07-19T06:26:17Z",
    "token": "k8s-aws-v1.aHR0cHM6Ly9zdHMudXMtd2VzdC0yLmFtYXpvbmF3cy5jb20vP0FjdGlvbj1HZXRDYWxsZXJJZGVudGl0eSZWZXJzaW9uPTIwMTEtMDYtMTUmWC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BU0lBVjJNWU80QUI2SDMzSkhQRSUyRjIwMjQwNzE5JTJGdXMtd2VzdC0yJTJGc3RzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNDA3MTlUMDYxMjE3WiZYLUFtei1FeHBpcmVzPTYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCUzQngtazhzLWF3cy1pZCZYLUFtei1TZWN1cml0eS1Ub2tlbj1JUW9KYjNKcFoybHVYMlZqRUV3YUNYVnpMV1ZoYzNRdE1TSklNRVlDSVFDbVV6VVZZWTFPT1c3a3VrcWh6JTJGeEJEWWxWVkZ6dUlPcklsRDBSWDZrcGZ3SWhBTVI4YlZpSFdhRWZjJTJGMkVzUmQlMkJVcG40Zkg3ejI3JTJCUHl6U1hSa1F3Q2ttTUtwRUNDQ1FRQWhvTU5EQXdNamc0TlRjeE16azFJZ3l1R0hEVkl0S1hrVXdleHpJcTdnR243UldFbUltUXlnalB4Z3pXVXZ0QklkdlVLdkdqWlNzMFkzVzBwQ3VmbGVWaXFzRm5OMGhnckRSTlNiOW9NNjFEeHVDWHVxbWZnUGlPd3hyaGl5MlRGWEU3OWZpcnVJbSUyRnBsc1dOQjdBQ09wSXZ6T25xRSUyQkJ2ZHp1WmpuVEMlMkZaZklkbmpCRnJUZGZkWEhWc0l5aUhzdDNuN3F1SVpMYVhhMDllNVprMG96eFZDcjcwaHFTNVpFcVJRRkpiMlpabTdkd1FkTlpNblg2ZXU0QlBnZW1SOE9xeHJNeHNheUZ1MXBNRUNOWnJRdlhla3RiMGd5TVBENDhyTiUyRmlYWDVsVkp1czRhaWZheWdhSEY1RjBvRUVMaDNicGxUbk8zUUxNYmVyZTFVTXQ2UG1TY3N4aHRYVkxLNWhwT3dhTUNNUCUyQng1N1FHT3B3QjNvNXFFZDlFTkFmc2R0eXlFUnhpRlA5bEJMdUw1ODBQMGlWeDdNOWpYVzZ0eG41dkU2bVQ5ZEMxdHd0UGxFTGt3REd5aUExaXhlNHU1MG96QWRlJTJGQXZkZ21JJTJCZ2hWWHJQelU3V1NnSHRGRUtoJTJGNkZ6YiUyRmlYaEdLVmptQnlYR2drVmYlMkJJaHFsblRIenF5WFNUdGVnbEFaTWk2N3B0SXdKYjRVUTZtQW5mY3RsbUVhU1ZQb2lNTDlFS0N6azVjVmZQMGY3cCUyRlh5ZjFnVm5xb0kmWC1BbXotU2lnbmF0dXJlPWEyNjg5MWE5MTRlNTVlZDU2NWI2M2Y0N2FlMmYwZWQyMzNmYjYzODY1ZDA0YmJjMzZjODkxNTQ4OTBhOTFiZmU"
  }
}
```

Exclude k8s-aws-v1 and decode the token.

```bash
aHR0cHM6Ly9zdHMudXMtd2VzdC0yLmFtYXpvbmF3cy5jb20vP0FjdGlvbj1HZXRDYWxsZXJJZGVudGl0eSZWZXJzaW9uPTIwMTEtMDYtMTUmWC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BU0lBVjJNWU80QUI2SDMzSkhQRSUyRjIwMjQwNzE5JTJGdXMtd2VzdC0yJTJGc3RzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNDA3MTlUMDYxMjE3WiZYLUFtei1FeHBpcmVzPTYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCUzQngtazhzLWF3cy1pZCZYLUFtei1TZWN1cml0eS1Ub2tlbj1JUW9KYjNKcFoybHVYMlZqRUV3YUNYVnpMV1ZoYzNRdE1TSklNRVlDSVFDbVV6VVZZWTFPT1c3a3VrcWh6JTJGeEJEWWxWVkZ6dUlPcklsRDBSWDZrcGZ3SWhBTVI4YlZpSFdhRWZjJTJGMkVzUmQlMkJVcG40Zkg3ejI3JTJCUHl6U1hSa1F3Q2ttTUtwRUNDQ1FRQWhvTU5EQXdNamc0TlRjeE16azFJZ3l1R0hEVkl0S1hrVXdleHpJcTdnR243UldFbUltUXlnalB4Z3pXVXZ0QklkdlVLdkdqWlNzMFkzVzBwQ3VmbGVWaXFzRm5OMGhnckRSTlNiOW9NNjFEeHVDWHVxbWZnUGlPd3hyaGl5MlRGWEU3OWZpcnVJbSUyRnBsc1dOQjdBQ09wSXZ6T25xRSUyQkJ2ZHp1WmpuVEMlMkZaZklkbmpCRnJUZGZkWEhWc0l5aUhzdDNuN3F1SVpMYVhhMDllNVprMG96eFZDcjcwaHFTNVpFcVJRRkpiMlpabTdkd1FkTlpNblg2ZXU0QlBnZW1SOE9xeHJNeHNheUZ1MXBNRUNOWnJRdlhla3RiMGd5TVBENDhyTiUyRmlYWDVsVkp1czRhaWZheWdhSEY1RjBvRUVMaDNicGxUbk8zUUxNYmVyZTFVTXQ2UG1TY3N4aHRYVkxLNWhwT3dhTUNNUCUyQng1N1FHT3B3QjNvNXFFZDlFTkFmc2R0eXlFUnhpRlA5bEJMdUw1ODBQMGlWeDdNOWpYVzZ0eG41dkU2bVQ5ZEMxdHd0UGxFTGt3REd5aUExaXhlNHU1MG96QWRlJTJGQXZkZ21JJTJCZ2hWWHJQelU3V1NnSHRGRUtoJTJGNkZ6YiUyRmlYaEdLVmptQnlYR2drVmYlMkJJaHFsblRIenF5WFNUdGVnbEFaTWk2N3B0SXdKYjRVUTZtQW5mY3RsbUVhU1ZQb2lNTDlFS0N6azVjVmZQMGY3cCUyRlh5ZjFnVm5xb0kmWC1BbXotU2lnbmF0dXJlPWEyNjg5MWE5MTRlNTVlZDU2NWI2M2Y0N2FlMmYwZWQyMzNmYjYzODY1ZDA0YmJjMzZjODkxNTQ4OTBhOTFiZmU
```

Got STS URL.

```bash
aHR0cHM6Ly9zdHMudXMtd2VzdC0yLmFtYXpvbmF3cy5jb20vP0FjdGlvbj1HZXRDYWxsZXJJZGVudGl0eSZWZXJzaW9uPTIwMTEtMDYtMTUmWC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BU0lBVjJNWU80QUI2SDMzSkhQRSUyRjIwMjQwNzE5JTJGdXMtd2VzdC0yJTJGc3RzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNDA3MTlUMDYxMjE3WiZYLUFtei1FeHBpcmVzPTYwJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCUzQngtazhzLWF3cy1pZCZYLUFtei1TZWN1cml0eS1Ub2tlbj1JUW9KYjNKcFoybHVYMlZqRUV3YUNYVnpMV1ZoYzNRdE1TSklNRVlDSVFDbVV6VVZZWTFPT1c3a3VrcWh6JTJGeEJEWWxWVkZ6dUlPcklsRDBSWDZrcGZ3SWhBTVI4YlZpSFdhRWZjJTJGMkVzUmQlMkJVcG40Zkg3ejI3JTJCUHl6U1hSa1F3Q2ttTUtwRUNDQ1FRQWhvTU5EQXdNamc0TlRjeE16azFJZ3l1R0hEVkl0S1hrVXdleHpJcTdnR243UldFbUltUXlnalB4Z3pXVXZ0QklkdlVLdkdqWlNzMFkzVzBwQ3VmbGVWaXFzRm5OMGhnckRSTlNiOW9NNjFEeHVDWHVxbWZnUGlPd3hyaGl5MlRGWEU3OWZpcnVJbSUyRnBsc1dOQjdBQ09wSXZ6T25xRSUyQkJ2ZHp1WmpuVEMlMkZaZklkbmpCRnJUZGZkWEhWc0l5aUhzdDNuN3F1SVpMYVhhMDllNVprMG96eFZDcjcwaHFTNVpFcVJRRkpiMlpabTdkd1FkTlpNblg2ZXU0QlBnZW1SOE9xeHJNeHNheUZ1MXBNRUNOWnJRdlhla3RiMGd5TVBENDhyTiUyRmlYWDVsVkp1czRhaWZheWdhSEY1RjBvRUVMaDNicGxUbk8zUUxNYmVyZTFVTXQ2UG1TY3N4aHRYVkxLNWhwT3dhTUNNUCUyQng1N1FHT3B3QjNvNXFFZDlFTkFmc2R0eXlFUnhpRlA5bEJMdUw1ODBQMGlWeDdNOWpYVzZ0eG41dkU2bVQ5ZEMxdHd0UGxFTGt3REd5aUExaXhlNHU1MG96QWRlJTJGQXZkZ21JJTJCZ2hWWHJQelU3V1NnSHRGRUtoJTJGNkZ6YiUyRmlYaEdLVmptQnlYR2drVmYlMkJJaHFsblRIenF5WFNUdGVnbEFaTWk2N3B0SXdKYjRVUTZtQW5mY3RsbUVhU1ZQb2lNTDlFS0N6azVjVmZQMGY3cCUyRlh5ZjFnVm5xb0kmWC1BbXotU2lnbmF0dXJlPWEyNjg5MWE5MTRlNTVlZDU2NWI2M2Y0N2FlMmYwZWQyMzNmYjYzODY1ZDA0YmJjMzZjODkxNTQ4OTBhOTFiZmU
```

This is content of ~/.kube/config file.

```py
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJRkxuWThQbmtQa1V3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TkRBM01UZ3dOakF4TUROYUZ3MHpOREEzTVRZd05qQTJNRE5hTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUUN6UnVWbk92eFdPcSt6ZEo2dTNwVm93endEdFlzY3A3N1ZwRVVyeDg1bllZUlB5aUI3amlRaHJtNzcKc1A2UVhaUXhhcDZ5RmRFTlZ4TGtmNmhBVFV3QUdIa2lxMVgyWmJqYlFaSEYrMjNTM1ZNWjBOVDJPaHJGQVlWYwpYUVEzM0wwbkFYR05BTzlyZDFHYXFudmJRaEpya3puMWhRL21UYnVJa212UXNMdE9BSno1T0c3c3diZjBPMzNWCkhnUG5DeGlPUjBIRjZpV0g1YVFyNFZaRy9lWnNQNDJDR2VoT3dtSS9ENzRHaXpGWTBDQmk5MXBmRGlkSUVFY20KSEh5YXNXam1URTJ6TVhqTXBabjhaL3ZUMjRFazZzOU9kQ3VScnB5Z1RsanVwaWwyUlBSZ3BZY1orRW9USjZoNwpKNmJXbXZDSTc3SmV3ZXQyaVV6eDQxdUZkM3E5QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJUQWhId2o5Q2twdmdsa1BBeG1BeUVNRlkrRU9EQVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1dZR2xyd0xNNAo5OElGbGE1dW1Tcmk3ZlQ3T1hiYzQ3K0VhdmxTRTRHQTRQTEEwVVI0QjIrcm95SUx3MnBkQ2c4L0FZc3VFRWxaCmx2QWxkWXFtUVBNaUJ1bXh6ZDVHS2xNVHBkN2E1VGduVnJKZE5aejBwZ2dpV0ZvL0Y1dFpzU29xcW5YbkxjZTUKR3lMMmYxOVdMTW5MamxzNlF4NHE3dzlOcVExNlFuYUdlMU1yMEZWRjRZRytyZzVjaktaZWdIcTlDcUZOVUFXNwpYS2J3M1VkRDR6b2w5Z2dwSER2OUhubU1udDJJUVM5YTkxS2p1aFhobXh2WmJqNGp6aWZJeU5xMVB4akdiVTQ4CkRKcTdIaG12dzBZSFg0OFBwaHdHbjRJckNuRzArM2s3ZTZYbkMzdlF2a0VuN1czcGFJTi9qV3RIRXFxaWxtNmwKWFdUc1RwNVVEY25nCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://E04442A3459AAE327123D1F747729D69.gr7.us-west-2.eks.amazonaws.com
  name: arn:aws:eks:us-west-2:400288571395:cluster/eks-cluster-stack-eks-cluster
contexts:
- context:
    cluster: arn:aws:eks:us-west-2:400288571395:cluster/eks-cluster-stack-eks-cluster
    user: arn:aws:eks:us-west-2:400288571395:cluster/eks-cluster-stack-eks-cluster
  name: arn:aws:eks:us-west-2:400288571395:cluster/eks-cluster-stack-eks-cluster
current-context: arn:aws:eks:us-west-2:400288571395:cluster/eks-cluster-stack-eks-cluster
kind: Config
preferences: {}
users:
- name: arn:aws:eks:us-west-2:400288571395:cluster/eks-cluster-stack-eks-cluster
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - --region
      - us-west-2
      - eks
      - get-token
      - --cluster-name
      - eks-cluster-stack-eks-cluster
      - --output
      - json
      command: aws
```

## Reference

- [kubeconfig cluster, user, context](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)

- [server and client certificates in kubernetes](https://everythingdevops.dev/securing-your-kubernetes-environment-a-comprehensive-guide-to-server-and-client-certificates-in-kubernetes/)

## Authentication Process Summary

The existing documentation above shows how to extract and examine the certificate authority data and token used for authentication. Here's a summary of how kubectl authentication works with EKS:

1. The kubeconfig file contains:
   - Cluster endpoint information
   - Certificate authority data for TLS verification
   - Authentication method configuration (AWS CLI exec plugin)

2. When kubectl makes a request:
   - It executes the AWS CLI to get a token
   - The token is a signed URL for AWS STS GetCallerIdentity
   - This token proves the identity of the caller

3. The EKS API server:
   - Validates the token
   - Maps the IAM identity to Kubernetes RBAC permissions via the aws-auth ConfigMap

## Practical Examples

### 1. Examining the Current Authentication Configuration

```bash
# View your kubeconfig file
cat ~/.kube/config
```

Output (anonymized):
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3...
    server: https://1C7E354E68A5D70F613DDA4637C1F647.gr7.us-west-2.eks.amazonaws.com
  name: arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
contexts:
- context:
    cluster: arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
    user: arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
  name: arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
current-context: arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
kind: Config
preferences: {}
users:
- name: arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - --region
      - us-west-2
      - eks
      - get-token
      - --cluster-name
      - eks-stack-eks-cluster
      - --output
      - json
      command: aws
```

### 2. Generating an Authentication Token

```bash
# Generate a token for EKS authentication
aws eks get-token --cluster-name eks-stack-eks-cluster --region us-west-2
```

Output (truncated):
```json
{
    "kind": "ExecCredential",
    "apiVersion": "client.authentication.k8s.io/v1beta1",
    "spec": {},
    "status": {
        "expirationTimestamp": "2025-05-17T11:21:33Z",
        "token": "k8s-aws-v1.aHR0cHM6Ly9zdHMudXMtd2VzdC0yLmFtYXpvbmF3cy5jb20vP0FjdGlvbj..."
    }
}
```

### 3. Checking IAM Identity Used for Authentication

```bash
# Check which IAM identity is being used
aws sts get-caller-identity
```

Output:
```json
{
    "UserId": "AROAXZRYMB5AGMOUZW2AO:i-0ca47f0a1128139cf",
    "Account": "535915401024",
    "Arn": "arn:aws:sts::535915401024:assumed-role/code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk/i-0ca47f0a1128139cf"
}
```

### 4. Examining the aws-auth ConfigMap

```bash
# View the aws-auth ConfigMap that maps IAM roles to Kubernetes permissions
kubectl get configmap aws-auth -n kube-system -o yaml
```

Output:
```yaml
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::535915401024:role/eks-stack-ManagedNodeGroupRole-tRCa203jPzj9
      username: system:node:{{EC2PrivateDNSName}}
kind: ConfigMap
metadata:
  creationTimestamp: "2025-05-17T10:24:00Z"
  name: aws-auth
  namespace: kube-system
  resourceVersion: "749"
  uid: 143aab91-79da-4e4f-99db-baf12bddc93e
```

## Authentication Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                       kubectl Authentication Flow                               │
│                                                                                 │
├───────────────────┐          ┌───────────────────┐          ┌───────────────────┤
│                   │          │                   │          │                   │
│  kubectl command  │──────────►  AWS CLI          │──────────►  AWS STS          │
│                   │  1. Run  │  get-token        │  2. Call │  GetCallerIdentity│
│                   │          │                   │          │                   │
└───────────┬───────┘          └─────────┬─────────┘          └─────────┬─────────┘
            │                            │                              │
            │                            │                              │
            │                            │                              │
            │                            │                              ▼
            │                            │                    ┌───────────────────┐
            │                            │                    │                   │
            │                            │                    │  Signed token     │
            │                            │                    │                   │
            │                            │                    └─────────┬─────────┘
            │                            │                              │
            │                            │                              │
            │                            ▼                              │
            │                  ┌───────────────────┐                    │
            │                  │                   │                    │
            │                  │  Token added to   │◄───────────────────┘
            │                  │  HTTP headers     │  3. Return
            │                  │                   │
            │                  └─────────┬─────────┘
            │                            │
            │                            │
            ▼                            ▼
┌───────────────────┐          ┌───────────────────┐
│                   │          │                   │
│  EKS API Server   │◄─────────┤  Request with     │
│                   │  4. Send │  token            │
│                   │          │                   │
└───────────┬───────┘          └───────────────────┘
            │
            │
            ▼
┌───────────────────┐          ┌───────────────────┐
│                   │          │                   │
│  Validate token   │──────────►  Check aws-auth   │
│  5. Verify        │  6. Map  │  ConfigMap        │
│                   │          │                   │
└───────────┬───────┘          └─────────┬─────────┘
            │                            │
            │                            │
            ▼                            ▼
┌───────────────────┐          ┌───────────────────┐
│                   │          │                   │
│  Apply RBAC       │◄─────────┤  Map IAM role to  │
│  permissions      │  7. Use  │  K8s permissions  │
│                   │          │                   │
└───────────┬───────┘          └───────────────────┘
            │
            │
            ▼
┌───────────────────┐
│                   │
│  Execute command  │
│  or deny access   │
│                   │
└───────────────────┘
```

## Important Notes

1. **IAM Role Mapping**: The EC2 instance role (`code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk`) is not explicitly listed in the aws-auth ConfigMap. This suggests one of two possibilities:
   - The role has been granted permissions at the AWS IAM level to access the EKS API
   - The cluster is using the EKS access entry feature (newer EKS clusters) which doesn't require explicit ConfigMap entries

2. **Token Expiration**: The authentication token has a short expiration time (typically 15 minutes). kubectl automatically refreshes the token when needed.

3. **Security Best Practices**:
   - Always use the principle of least privilege when granting IAM permissions
   - Regularly audit the aws-auth ConfigMap for unnecessary or overly permissive role mappings
   - Consider using IAM Roles for Service Accounts (IRSA) for workloads running in the cluster

4. **Troubleshooting Authentication Issues**:
   - Check IAM permissions of the role being used
   - Verify the role is properly mapped in the aws-auth ConfigMap if needed
   - Ensure the EC2 instance has network connectivity to the EKS API server endpoint
