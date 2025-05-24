<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Setting up AWS Load Balancer Controller for EKS

## Introduction

The AWS Load Balancer Controller (formerly known as AWS ALB Ingress Controller) is a controller that helps manage Elastic Load Balancers for a Kubernetes cluster. It satisfies Kubernetes Ingress resources by provisioning Application Load Balancers (ALBs) and Network Load Balancers (NLBs).

## How AWS Load Balancer Controller Works

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                       AWS Load Balancer Controller Architecture                 │
│                                                                                 │
├───────────────────┐          ┌───────────────────┐          ┌───────────────────┤
│                   │          │                   │          │                   │
│  Kubernetes       │          │  AWS Load         │          │  AWS API          │
│  API Server       │◄────────►│  Balancer         │◄────────►│  (ALB/NLB)        │
│                   │  Watch   │  Controller       │  Create  │                   │
│                   │          │                   │          │                   │
└───────────────────┘          └─────────┬─────────┘          └───────────────────┘
                                         │
                                         │ Reconcile
                                         │
                                         ▼
┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐
│                   │          │                   │          │                   │
│  Ingress          │          │  Service          │          │  Target Groups    │
│  Resources        │          │  Resources        │          │  & Listeners      │
│                   │          │                   │          │                   │
└───────────────────┘          └───────────────────┘          └───────────────────┘
```

The AWS Load Balancer Controller:

1. **Watches for Resources**: Monitors Kubernetes resources like Ingress, Service of type LoadBalancer, and custom resources.

2. **Translates Configuration**: Converts Kubernetes resource specifications into AWS Load Balancer configurations.

3. **Provisions AWS Resources**: Creates and manages AWS resources including:
   - Application Load Balancers (ALBs)
   - Network Load Balancers (NLBs)
   - Target Groups
   - Listeners
   - Rules

4. **Updates Status**: Reports back the status of the provisioned resources to the Kubernetes API.

5. **Manages Lifecycle**: Handles updates and deletions of load balancers when Kubernetes resources change.

## Installation Steps (Completed)

The AWS Load Balancer Controller has been successfully installed on your EKS cluster. Here's what was done:

### Step 1: Created IAM Policy for the Controller

```bash
# Downloaded the IAM policy document
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Created the IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json
```

Output:
```json
{
    "Policy": {
        "PolicyName": "AWSLoadBalancerControllerIAMPolicy",
        "PolicyId": "ANPAXZRYMB5AKJ2EGEP76",
        "Arn": "arn:aws:iam::535915401024:policy/AWSLoadBalancerControllerIAMPolicy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2025-05-17T11:48:11+00:00",
        "UpdateDate": "2025-05-17T11:48:11+00:00"
    }
}
```

### Step 2: Associated IAM OIDC Provider with the Cluster

```bash
# Associated IAM OIDC provider with the cluster
eksctl utils associate-iam-oidc-provider --region=us-west-2 --cluster=eks-stack-eks-cluster --approve
```

Output:
```
2025-05-17 11:49:51 [ℹ]  will create IAM Open ID Connect provider for cluster "eks-stack-eks-cluster" in "us-west-2"
2025-05-17 11:49:51 [✔]  created IAM Open ID Connect provider for cluster "eks-stack-eks-cluster" in "us-west-2"
```

### Step 3: Created IAM Service Account for the Controller

```bash
# Created IAM service account for AWS Load Balancer Controller
eksctl create iamserviceaccount \
    --cluster=eks-stack-eks-cluster \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::535915401024:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve \
    --region us-west-2
```

Output:
```
2025-05-17 11:50:01 [ℹ]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was included (based on the include/exclude rules)
2025-05-17 11:50:01 [!]  serviceaccounts that exist in Kubernetes will be excluded, use --override-existing-serviceaccounts to override
2025-05-17 11:50:01 [ℹ]  1 task: { 
    2 sequential sub-tasks: { 
        create IAM role for serviceaccount "kube-system/aws-load-balancer-controller",
        create serviceaccount "kube-system/aws-load-balancer-controller",
    } }
2025-05-17 11:50:01 [ℹ]  building iamserviceaccount stack "eksctl-eks-stack-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2025-05-17 11:50:01 [ℹ]  deploying stack "eksctl-eks-stack-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2025-05-17 11:50:01 [ℹ]  waiting for CloudFormation stack "eksctl-eks-stack-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2025-05-17 11:50:31 [ℹ]  waiting for CloudFormation stack "eksctl-eks-stack-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2025-05-17 11:50:31 [ℹ]  created serviceaccount "kube-system/aws-load-balancer-controller"
```

### Step 4: Installed AWS Load Balancer Controller using Helm

```bash
# Added the EKS chart repository
helm repo add eks https://aws.github.io/eks-charts

# Updated the repository
helm repo update eks

# Installed the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=eks-stack-eks-cluster \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
```

Output:
```
NAME: aws-load-balancer-controller
LAST DEPLOYED: Sat May 17 11:51:16 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
AWS Load Balancer controller installed!
```

### Step 5: Verified the Installation

```bash
# Verified the controller deployment
kubectl get deployment -n kube-system aws-load-balancer-controller
```

Output:
```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           29s
```

```bash
# Checked the controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

Output:
```
NAME                                            READY   STATUS    RESTARTS   AGE
aws-load-balancer-controller-5dcbc478cc-75zvs   1/1     Running   0          37s
aws-load-balancer-controller-5dcbc478cc-8mr96   1/1     Running   0          37s
```

## Using the AWS Load Balancer Controller

### Example 1: Creating an ALB using Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-service
                port:
                  number: 80
```

### Example 2: Creating an NLB using Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
  type: LoadBalancer
  selector:
    app: example-app
```

## Key Annotations for Customization

The AWS Load Balancer Controller supports many annotations to customize the behavior:

### ALB Annotations

- `alb.ingress.kubernetes.io/scheme`: Specifies whether the ALB is internet-facing or internal
- `alb.ingress.kubernetes.io/target-type`: Specifies how to route traffic (ip or instance)
- `alb.ingress.kubernetes.io/listen-ports`: JSON array of ports the ALB will listen on
- `alb.ingress.kubernetes.io/actions.${action-name}`: Configures custom actions
- `alb.ingress.kubernetes.io/ssl-policy`: Specifies the SSL policy
- `alb.ingress.kubernetes.io/certificate-arn`: ARN of ACM certificate
- `alb.ingress.kubernetes.io/security-groups`: Security groups to attach to the ALB

### NLB Annotations

- `service.beta.kubernetes.io/aws-load-balancer-type`: Set to "external" for NLB
- `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type`: Target type (ip or instance)
- `service.beta.kubernetes.io/aws-load-balancer-scheme`: Whether NLB is internet-facing or internal

## Troubleshooting

Common issues and how to resolve them:

1. **Controller not starting**: Check IAM permissions and service account configuration
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

2. **ALB/NLB not being created**: Check if subnets are properly tagged
   ```bash
   # For public subnets
   aws ec2 create-tags --resources subnet-xxxx --tags Key=kubernetes.io/role/elb,Value=1
   
   # For private subnets
   aws ec2 create-tags --resources subnet-xxxx --tags Key=kubernetes.io/role/internal-elb,Value=1
   ```

3. **Target registration issues**: Ensure security groups allow traffic from the ALB to the targets

## Best Practices

1. **Security**: Use the principle of least privilege for IAM roles
2. **Cost Optimization**: Delete unused load balancers and consider using internal ALBs where possible
3. **Monitoring**: Set up CloudWatch alarms for your load balancers
4. **Logging**: Enable access logs for your ALBs to debug issues
5. **High Availability**: Deploy the controller with multiple replicas (already done in our setup)

## Additional Resources

- [Official Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
- [GitHub Repository](https://github.com/kubernetes-sigs/aws-load-balancer-controller)
- [AWS EKS Workshop](https://www.eksworkshop.com/beginner/180_fargate/fargate-alb/)
- [Helm Chart Repository](https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller)

## Conclusion

The AWS Load Balancer Controller has been successfully installed on your EKS cluster. It's now ready to provision and manage AWS Application Load Balancers and Network Load Balancers based on your Kubernetes Ingress and Service resources.
