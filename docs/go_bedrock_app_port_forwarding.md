<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Deploying and Accessing the Go Bedrock App on Amazon EKS

This guide explains how to deploy the Go Bedrock App to an Amazon EKS cluster and access it using port forwarding.

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Access to an Amazon EKS cluster
- The `bedrock-service-account` service account must exist in the cluster

## Deploying the Application

1. **Update your kubeconfig to connect to your EKS cluster**

   ```bash
   aws eks update-kubeconfig --name <your-cluster-name> --region <your-region>
   # Example:
   aws eks update-kubeconfig --name esk-stack-eks-cluster --region us-west-2
   ```

2. **Verify the required service account exists**

   ```bash
   kubectl get serviceaccount bedrock-service-account
   ```

   If it doesn't exist, you'll need to create it first.

3. **Deploy the application using the deployment YAML file**

   ```bash
   kubectl apply -f /path/to/go-bedrock-deployment.yaml
   # Example:
   kubectl apply -f app/go-bedrock-app/deploy/go-bedrock-deployment.yaml
   ```

4. **Verify the deployment**

   Check if the pods are running:
   ```bash
   kubectl get pods -l app=go-bedrock-app
   ```

   You should see output similar to:
   ```
   NAME                             READY   STATUS    RESTARTS   AGE
   go-bedrock-app-6fbd88bfc-sxbx7   1/1     Running   0          8s
   go-bedrock-app-6fbd88bfc-zgkcp   1/1     Running   0          8s
   ```

   Wait until the pods status shows `1/1` in the READY column.

## Accessing the Application with Port Forwarding

Port forwarding creates a secure tunnel between your local machine and the pods running in your EKS cluster.

### Method 1: Foreground Port Forwarding

This method runs in the foreground, and you'll need to keep the terminal window open:

```bash
kubectl port-forward deployment/go-bedrock-app 8081:3000
```

### Method 2: Background Port Forwarding

This method runs in the background, allowing you to continue using the terminal:

```bash
nohup kubectl port-forward deployment/go-bedrock-app 8081:3000 > /tmp/bedrock-port-forward.log 2>&1 &
```

To verify the port forwarding is running:
```bash
ps aux | grep "port-forward" | grep "go-bedrock-app" | grep -v grep
```

### Accessing the Application

Once port forwarding is set up, you can access the application at:
```
http://localhost:8081
```

### Stopping Port Forwarding

To stop the port forwarding process running in the background:
```bash
pkill -f "kubectl port-forward deployment/go-bedrock-app"
```

## Troubleshooting

If you encounter issues with port forwarding:

1. **Check if the pods are running**
   ```bash
   kubectl get pods -l app=go-bedrock-app
   ```

2. **Check pod logs**
   ```bash
   kubectl logs deployment/go-bedrock-app
   ```

3. **Verify port availability**
   ```bash
   netstat -tulpn | grep 8081
   ```

4. **Test connectivity**
   ```bash
   curl -I http://localhost:8081
   ```

5. **Check service account permissions**
   ```bash
   kubectl describe serviceaccount bedrock-service-account
   ```

## Additional Options

### Port Forwarding to a Specific Pod

If you need to target a specific pod instead of the deployment:

```bash
# Get pod name
kubectl get pods -l app=go-bedrock-app

# Port forward to specific pod
kubectl port-forward pod/go-bedrock-app-6fbd88bfc-sxbx7 8081:3000
```

### Using a Different Local Port

If port 8081 is already in use, you can specify a different local port:

```bash
kubectl port-forward deployment/go-bedrock-app 9091:3000
```

Then access the application at `http://localhost:9091`.

## Exposing the Application with a Load Balancer

The deployment file includes a commented-out Service definition for exposing the application with a Network Load Balancer. To use it:

1. Uncomment the Service section in the YAML file
2. Replace `<SUBNET_ID_1>,<SUBNET_ID_2>,<SUBNET_ID_3>` with your actual subnet IDs
3. Apply the updated YAML file

```bash
kubectl apply -f app/go-bedrock-app/deploy/go-bedrock-deployment.yaml
```

After applying, you can get the Load Balancer URL with:
```bash
kubectl get service go-bedrock-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
