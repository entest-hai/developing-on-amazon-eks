# Setting up kubectl on Amazon Linux 2023

This guide provides step-by-step instructions for installing and configuring kubectl on an Amazon Linux 2023 EC2 instance to interact with your EKS cluster.

## Prerequisites

- An Amazon Linux 2023 EC2 instance
- IAM permissions to access the EKS cluster
- AWS CLI already installed and configured

## Installation Process

### 1. Install kubectl

```bash
# Download the latest kubectl binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Download the kubectl checksum file
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# Verify the kubectl binary against the checksum file
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Make the kubectl binary executable
chmod +x kubectl

# Move the kubectl binary to a directory in your PATH
sudo mv kubectl /usr/local/bin/

# Verify the installation
kubectl version --client
```

The installation should complete successfully with output similar to:
```
Client Version: v1.33.1
Kustomize Version: v5.6.0
```

### 2. AWS IAM Authenticator (Optional)

While modern EKS clusters can authenticate using the AWS CLI directly, the AWS IAM Authenticator is still useful in certain scenarios:
- Older EKS clusters
- Custom authentication workflows
- Environments where AWS CLI integration is restricted

```bash
# Download the AWS IAM Authenticator
curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64

# Make it executable
chmod +x ./aws-iam-authenticator

# Move to a directory in your PATH
sudo mv aws-iam-authenticator /usr/local/bin/

# Verify the installation
aws-iam-authenticator version
```

#### How AWS IAM Authenticator Works

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                       AWS IAM Authentication Flow                               │
│                                                                                 │
├─────────────────────────┐                        ┌───────────────────────────────┤
│                         │                        │                               │
│    kubectl              │                        │         Kubernetes API        │
│                         │                        │                               │
└────────────┬────────────┘                        └────────────┬──────────────────┘
             │                                                  │
             │ 1. Request with                                 │
             │    token                                        │
             ▼                                                 │
┌─────────────────────────┐                                    │
│                         │                                    │
│  aws-iam-authenticator  │                                    │
│                         │                                    │
└────────────┬────────────┘                                    │
             │                                                 │
             │ 2. Call STS                                     │
             │    GetCallerIdentity                            │
             ▼                                                 │
┌─────────────────────────┐                                    │
│                         │                                    │
│     AWS STS Service     │                                    │
│                         │                                    │
└────────────┬────────────┘                                    │
             │                                                 │
             │ 3. Return signed                                │
             │    identity                                     │
             ▼                                                 │
┌─────────────────────────┐                                    │
│                         │                                    │
│  aws-iam-authenticator  │                                    │
│                         │                                    │
└────────────┬────────────┘                                    │
             │                                                 │
             │ 4. Forward identity                             │
             │    to API server                                │
             └────────────────────────────────────────────────►│
                                                               │
                                                               │
┌─────────────────────────┐                                    │
│                         │                                    │
│     aws-auth ConfigMap  │◄───────────┐                       │
│                         │            │                       │
└─────────────────────────┘            │ 5. Check identity     │
                                       │    against ConfigMap  │
                                       │                       │
                                       └───────────────────────┘
```

#### Authentication Methods Comparison

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                       Authentication Methods Comparison                         │
│                                                                                 │
├─────────────────────────────────┬───────────────────────────────────────────────┤
│                                 │                                               │
│     AWS CLI Integration         │     AWS IAM Authenticator                     │
│                                 │                                               │
├─────────────────────────────────┼───────────────────────────────────────────────┤
│ + Built into kubectl            │ + Works with older EKS versions               │
│ + Simpler setup                 │ + More customization options                  │
│ + Uses existing AWS credentials │ + Can be used in air-gapped environments      │
│ - Requires AWS CLI              │ - Additional binary to install and maintain   │
│ - Less customizable             │ - More complex setup                          │
│                                 │                                               │
└─────────────────────────────────┴───────────────────────────────────────────────┘
```

#### How AWS IAM Authenticator Integrates with EKS

1. **Token Generation**: When you run a kubectl command, the authenticator generates a token using your AWS credentials.

2. **AWS STS Call**: The authenticator calls the AWS Security Token Service (STS) GetCallerIdentity API to verify your identity.

3. **Signature Verification**: The EKS API server validates the STS response signature to confirm it came from AWS.

4. **Role Mapping**: The EKS cluster's aws-auth ConfigMap maps your IAM role to Kubernetes RBAC permissions.

5. **Access Decision**: Based on the mapping, the Kubernetes API server grants or denies access to the requested resources.

The aws-auth ConfigMap example:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::XXXXXXXXXXXX:role/EKSNodeRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::XXXXXXXXXXXX:role/AdminRole
      username: admin
      groups:
        - system:masters
```

### 3. Configure kubectl for your EKS Cluster

```bash
# Update your kubeconfig file to include your EKS cluster
# Important: Use the actual cluster name from CloudFormation outputs, not the stack name
aws eks update-kubeconfig --name eks-stack-eks-cluster --region us-west-2

# Verify the configuration
kubectl config get-contexts
```

Expected output:
```
CURRENT   NAME                                                               CLUSTER                                                            AUTHINFO                                                           NAMESPACE
*         arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster   arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster   arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
```

### 4. Verify Access to the Cluster

```bash
# Check cluster information
kubectl cluster-info
```

Expected output:
```
Kubernetes control plane is running at https://XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.gr7.us-west-2.eks.amazonaws.com
CoreDNS is running at https://XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.gr7.us-west-2.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

```bash
# List all nodes in the cluster
kubectl get nodes
```

Expected output:
```
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-0-122.us-west-2.compute.internal   Ready    <none>   31m   v1.30.11-eks-473151a
ip-10-0-1-211.us-west-2.compute.internal   Ready    <none>   31m   v1.30.11-eks-473151a
ip-10-0-2-220.us-west-2.compute.internal   Ready    <none>   31m   v1.30.11-eks-473151a
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Authentication Issues

If you encounter authentication errors:

```bash
# Verify your AWS credentials
aws sts get-caller-identity

# Ensure your IAM role/user has appropriate EKS permissions
# You may need to add your role to the aws-auth ConfigMap:
kubectl edit configmap aws-auth -n kube-system
```

Add your role to the `mapRoles` section:

```yaml
- rolearn: arn:aws:iam::XXXXXXXXXXXX:role/YourRoleName
  username: your-username
  groups:
    - system:masters
```

#### 2. Connection Issues

If kubectl cannot connect to the cluster:

```bash
# Check if the EKS cluster endpoint is accessible
curl -k <cluster-endpoint>

# Verify security group rules allow access from your EC2 instance
# Ensure your VPC has proper connectivity to the EKS control plane
```

#### 3. Context Issues

If you have multiple contexts and need to switch between them:

```bash
# List all available contexts
kubectl config get-contexts

# Switch to a specific context
kubectl config use-context <context-name>

# View current context
kubectl config current-context
```

## Useful kubectl Commands

```bash
# Get detailed information about the cluster
kubectl cluster-info dump

# Get all resources in the cluster
kubectl get all --all-namespaces

# Describe a specific resource
kubectl describe <resource-type> <resource-name>

# View logs for a pod
kubectl logs <pod-name>

# Execute a command in a container
kubectl exec -it <pod-name> -- /bin/bash

# Apply a configuration file
kubectl apply -f <filename.yaml>

# Delete a resource
kubectl delete <resource-type> <resource-name>
```

## Best Practices

1. **Use namespaces** to organize your resources and avoid naming conflicts
2. **Set resource limits** on your deployments to prevent resource exhaustion
3. **Use RBAC** to control access to your cluster resources
4. **Regularly update kubectl** to the latest version compatible with your cluster
5. **Use kubectl aliases** to simplify common commands
6. **Consider using a kubectl plugin manager** like krew for extended functionality

## Additional Resources

- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
## Authentication Flow Between kubectl and EKS

### How kubectl on EC2 Authenticates with EKS

When you run kubectl commands from your EC2 instance to interact with your EKS cluster, the authentication process follows these steps:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                     │
│                       EC2 Instance to EKS Authentication Flow                                       │
│                                                                                                     │
├───────────────────┐          ┌───────────────────┐          ┌───────────────────┐                   │
│                   │          │                   │          │                   │                   │
│  kubectl command  │──────────►  AWS SDK/CLI      │──────────►  AWS STS          │                   │
│  on EC2           │  1       │  credentials      │  2       │  service          │                   │
│                   │          │                   │          │                   │                   │
└───────────┬───────┘          └─────────┬─────────┘          └─────────┬─────────┘                   │
            │                            │                              │                             │
            │                            │                              │                             │
            │                            │                              │ 3                           │
            │                            │                              │                             │
            │                            │                              ▼                             │
            │                            │                    ┌───────────────────┐                   │
            │                            │                    │                   │                   │
            │                            │                    │  Signed token     │                   │
            │                            │                    │  with IAM         │                   │
            │                            │                    │  identity         │                   │
            │                            │                    │                   │                   │
            │                            │                    └─────────┬─────────┘                   │
            │                            │                              │                             │
            │                            │                              │ 4                           │
            │                            │                              │                             │
            │                            │                              ▼                             │
┌───────────▼───────┐          ┌─────────▼─────────┐          ┌───────────────────┐                   │
│                   │          │                   │          │                   │                   │
│  kubectl sends    │◄─────────┤  Token included   │◄─────────┤  Token added to   │                   │
│  request to EKS   │  6       │  in HTTP headers  │  5       │  kubeconfig       │                   │
│                   │          │                   │          │                   │                   │
└───────────┬───────┘          └───────────────────┘          └───────────────────┘                   │
            │                                                                                         │
            │ 7                                                                                       │
            ▼                                                                                         │
┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐                   │
│                   │          │                   │          │                   │                   │
│  EKS API Server   │──────────►  Token validation │──────────►  aws-auth         │                   │
│                   │  8       │  & verification   │  9       │  ConfigMap check  │                   │
│                   │          │                   │          │                   │                   │
└───────────┬───────┘          └─────────┬─────────┘          └─────────┬─────────┘                   │
            │                            │                              │                             │
            │                            │                              │                             │
            │                            │                              │ 10                          │
            │                            │                              │                             │
            │                            │                              ▼                             │
            │                            │                    ┌───────────────────┐                   │
            │                            │                    │                   │                   │
            │                            │                    │  RBAC permission  │                   │
            │                            │                    │  check            │                   │
            │                            │                    │                   │                   │
            │                            │                    └─────────┬─────────┘                   │
            │                            │                              │                             │
            │                            │                              │ 11                          │
            │                            │                              │                             │
            │                            │                              ▼                             │
┌───────────▼───────┐          ┌─────────▼─────────┐          ┌───────────────────┐                   │
│                   │          │                   │          │                   │                   │
│  Response sent    │◄─────────┤  Action allowed   │◄─────────┤  Permission       │                   │
│  back to kubectl  │  13      │  or denied        │  12      │  decision         │                   │
│                   │          │                   │          │                   │                   │
└───────────────────┘          └───────────────────┘          └───────────────────┘                   │
                                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Authentication Process

1. **EC2 Instance Role**: Your EC2 instance has an IAM role (`code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk`) attached as an instance profile.

2. **AWS Credentials**: When you run `aws eks update-kubeconfig`, the AWS CLI uses the EC2 instance's IAM role credentials automatically.

3. **Kubeconfig Generation**: The `update-kubeconfig` command:
   - Creates/updates the `~/.kube/config` file
   - Adds cluster endpoint information
   - Configures the authentication method (AWS IAM)
   - Sets up the exec plugin for authentication

4. **Token Generation**: When you run a kubectl command:
   - The AWS CLI exec plugin is invoked
   - It uses the EC2 instance's IAM role credentials
   - It calls AWS STS GetCallerIdentity to get a signed token
   - This token proves the identity of the IAM role

5. **Request to EKS**: kubectl sends the request to the EKS API server with:
   - The command you want to execute
   - The authentication token in the HTTP headers

6. **EKS Authentication**: The EKS API server:
   - Validates the token's signature
   - Extracts the IAM identity (role ARN)
   - Checks the aws-auth ConfigMap to map the IAM role to Kubernetes permissions

7. **Permission Check**: The Kubernetes API server:
   - Maps the IAM role to a Kubernetes user/group
   - Applies RBAC policies to determine if the action is allowed
   - Executes the command or denies access

### Examining the Authentication Configuration

You can see this configuration in your kubeconfig file:

```bash
cat ~/.kube/config
```

The relevant section will look similar to:

```yaml
users:
- name: arn:aws:eks:us-west-2:XXXXXXXXXXXX:cluster/eks-stack-eks-cluster
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - --region
        - us-west-2
        - eks
        - get-token
        - --cluster-name
        - eks-stack-eks-cluster
      env:
        - name: AWS_PROFILE
          value: default
```

This configuration tells kubectl to execute the AWS CLI to obtain a token whenever it needs to authenticate with the EKS cluster.

### EC2 Instance Role and EKS Access

The EC2 instance role (`code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk`) must have the following permissions to access the EKS cluster:

1. **eks:DescribeCluster**: To get cluster information
2. **eks:ListClusters**: To list available clusters
3. **eks:AccessKubernetesApi**: To access the Kubernetes API server

Additionally, the role must be mapped in the aws-auth ConfigMap to have Kubernetes RBAC permissions. You can check this with:

```bash
kubectl describe configmap aws-auth -n kube-system
```

If your role is not listed, you may need to add it:

```bash
kubectl edit configmap aws-auth -n kube-system
```

And add your role to the mapRoles section:

```yaml
mapRoles:
- rolearn: arn:aws:iam::XXXXXXXXXXXX:role/code-server-stack-CodeServerIAMRole-oM8ArslR4Gyk
  username: eks-admin
  groups:
  - system:masters
```
