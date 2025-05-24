<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# Deploying and Accessing the Go Book App on Amazon EKS

This guide explains how to deploy the Go Book App to an Amazon EKS cluster and access it using port forwarding.

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Access to an Amazon EKS cluster

## Deploying the Application

1. **Update your kubeconfig to connect to your EKS cluster**

   ```bash
   aws eks update-kubeconfig --name <your-cluster-name> --region <your-region>
   # Example:
   aws eks update-kubeconfig --name esk-stack-eks-cluster --region us-west-2
   ```

2. **Deploy the application using the deployment YAML file**

   ```bash
   kubectl apply -f /path/to/book-pod.yaml
   # Example:
   kubectl apply -f app/go-web-demo/deploy/book-pod.yaml
   ```

3. **Verify the deployment**

   Check if the pod is running:
   ```bash
   kubectl get pods -l app=go-book-app
   ```

   You should see output similar to:
   ```
   NAME                           READY   STATUS    RESTARTS   AGE
   go-book-app-768bcc67db-zqrzr   1/1     Running   0          26s
   ```

   Wait until the pod status shows `1/1` in the READY column.

## Accessing the Application with Port Forwarding

Port forwarding creates a secure tunnel between your local machine and the pod running in your EKS cluster.

### Method 1: Foreground Port Forwarding

This method runs in the foreground, and you'll need to keep the terminal window open:

```bash
kubectl port-forward deployment/go-book-app 8080:3000
```

### Method 2: Background Port Forwarding

This method runs in the background, allowing you to continue using the terminal:

```bash
nohup kubectl port-forward deployment/go-book-app 8080:3000 > /tmp/port-forward.log 2>&1 &
```

To verify the port forwarding is running:
```bash
ps aux | grep "port-forward" | grep -v grep
```

### Accessing the Application

Once port forwarding is set up, you can access the application at:
```
http://localhost:8080
```

### Stopping Port Forwarding

To stop the port forwarding process running in the background:
```bash
pkill -f "kubectl port-forward deployment/go-book-app"
```

## Troubleshooting

If you encounter issues with port forwarding:

1. **Check if the pod is running**
   ```bash
   kubectl get pods -l app=go-book-app
   ```

2. **Check pod logs**
   ```bash
   kubectl logs deployment/go-book-app
   ```

3. **Verify port availability**
   ```bash
   netstat -tulpn | grep 8080
   ```

4. **Test connectivity**
   ```bash
   curl -I http://localhost:8080
   ```

## Additional Options

### Port Forwarding to a Specific Pod

If you need to target a specific pod instead of the deployment:

```bash
# Get pod name
kubectl get pods -l app=go-book-app

# Port forward to specific pod
kubectl port-forward pod/go-book-app-768bcc67db-zqrzr 8080:3000
```

### Using a Different Local Port

If port 8080 is already in use, you can specify a different local port:

```bash
kubectl port-forward deployment/go-book-app 9090:3000
```

Then access the application at `http://localhost:9090`.
