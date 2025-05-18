# Deploying the Go Book Application to Kubernetes

This document provides detailed instructions on how to deploy the Go Book application to a Kubernetes cluster (EKS) and expose it using an AWS Load Balancer.

## Prerequisites

- Access to an Amazon EKS cluster
- `kubectl` CLI tool installed and configured to access your cluster
- Docker image pushed to Amazon ECR (as described in `build_ecr_image.md`)

## Deployment Files

The deployment uses two main YAML files:

1. **Deployment Manifest** (`yaml/book-pod.yaml`): Defines the application deployment
2. **Service Manifest** (`yaml/book-service.yaml`): Exposes the application via a LoadBalancer

## Deployment Manifest Details

The deployment manifest (`yaml/book-pod.yaml`) creates a Kubernetes Deployment with the following specifications:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-book-app
  namespace: default
  labels:
    app: go-book-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-book-app
  template:
    metadata:
      labels:
        app: go-book-app
    spec:
      containers:
      - name: go-book-app
        # REPLACE: Update with your actual AWS account ID in the image URL
        image: your-account-id.dkr.ecr.us-west-2.amazonaws.com/go-book-app:latest
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
```

### Key Components:

- **Deployment Type**: Uses Kubernetes Deployment for better management capabilities
- **Replicas**: Starts with 1 replica (can be scaled as needed)
- **Container Image**: Uses the ECR image we built and pushed earlier
- **Resource Limits**: 
  - Requests: 64Mi memory, 100m CPU
  - Limits: 128Mi memory, 200m CPU
- **Health Checks**:
  - Liveness probe: Checks if the application is running
  - Readiness probe: Checks if the application is ready to receive traffic

## Service Manifest Details

The service manifest (`yaml/book-service.yaml`) exposes the application using a LoadBalancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-book-app-service
  namespace: default
spec:
  selector:
    app: go-book-app
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
```

### Key Components:

- **Service Type**: LoadBalancer (creates an AWS Classic Load Balancer)
- **Port Mapping**: Maps external port 80 to container port 3000
- **Selector**: Routes traffic to pods with the label `app: go-book-app`

## Deployment Process

### 1. Apply the Deployment Manifest

```bash
kubectl apply -f yaml/book-pod.yaml
```

This creates the Deployment in the default namespace. The Deployment controller then creates a ReplicaSet, which creates the Pod(s).

### 2. Verify the Deployment

```bash
kubectl get deployments go-book-app
```

Expected output:
```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
go-book-app   1/1     1            1           <age>
```

### 3. Check Pod Status

```bash
kubectl get pods -l app=go-book-app
```

Expected output:
```
NAME                           READY   STATUS    RESTARTS   AGE
go-book-app-546cf9bc49-lt854   1/1     Running   0          <age>
```

### 4. Apply the Service Manifest

```bash
kubectl apply -f yaml/book-service.yaml
```

This creates a Service of type LoadBalancer, which provisions an AWS Classic Load Balancer.

### 5. Verify the Service

```bash
kubectl get service go-book-app-service
```

Expected output:
```
NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)        AGE
go-book-app-service   LoadBalancer   172.20.123.100   your-load-balancer-id.region.elb.amazonaws.com                           80:32306/TCP   <age>
```

## Accessing the Application

Once the LoadBalancer is provisioned (which may take a few minutes), you can access the application using the EXTERNAL-IP:

```
http://your-load-balancer-id.region.elb.amazonaws.com
```

## AWS Load Balancer Details

The deployment creates an AWS Classic Load Balancer with the following characteristics:

- **Type**: Classic Load Balancer
- **Listeners**: HTTP on port 80
- **Target Group**: EC2 instances in the EKS node group
- **Health Check**: HTTP on the specified path (/)
- **Security Group**: Automatically configured to allow inbound traffic on port 80

## Scaling the Application

To scale the application to more replicas:

```bash
kubectl scale deployment go-book-app --replicas=3
```

## Updating the Application

When you push a new image to ECR with the same tag (latest), you can update the deployment:

```bash
kubectl rollout restart deployment go-book-app
```

## Cleaning Up

To remove the deployed resources:

```bash
kubectl delete -f yaml/book-service.yaml
kubectl delete -f yaml/book-pod.yaml
```

Note that deleting the service will also delete the AWS Load Balancer.

## Troubleshooting

### Pod Not Starting

Check the pod logs:
```bash
kubectl logs -l app=go-book-app
```

### Service Not Creating Load Balancer

Check the service events:
```bash
kubectl describe service go-book-app-service
```

### Application Not Accessible

1. Verify the pod is running:
   ```bash
   kubectl get pods -l app=go-book-app
   ```

2. Check if the service has an external IP:
   ```bash
   kubectl get service go-book-app-service
   ```

3. Check if the pod is passing health checks:
   ```bash
   kubectl describe pod -l app=go-book-app
   ```
