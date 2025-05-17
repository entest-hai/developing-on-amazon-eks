# Deploying the Go Book Application to Kubernetes

This document provides detailed instructions on how to deploy the Go Book application to a Kubernetes cluster (EKS) and expose it using AWS Load Balancers.

## Prerequisites

- Access to an Amazon EKS cluster
- `kubectl` CLI tool installed and configured to access your cluster
- Docker image pushed to Amazon ECR (as described in `build_ecr_image.md`)
- AWS Load Balancer Controller installed in the EKS cluster (for NLB/ALB support)

## Deployment Files

The deployment uses several YAML files:

1. **Deployment Manifest** (`yaml/book-pod.yaml`): Defines the application deployment
2. **Classic Load Balancer Service** (`yaml/book-service.yaml`): Exposes the application via a Classic Load Balancer
3. **Network Load Balancer Service** (`yaml/book-service-new.yaml`): Exposes the application via an AWS Network Load Balancer

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
        image: 535915401024.dkr.ecr.us-west-2.amazonaws.com/go-book-app:latest
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

## Service Options

### Option 1: Classic Load Balancer Service

The service manifest (`yaml/book-service.yaml`) exposes the application using a Classic Load Balancer:

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

### Option 2: Network Load Balancer Service (AWS Load Balancer Controller)

The NLB service manifest (`yaml/book-service-new.yaml`) uses the AWS Load Balancer Controller to create a Network Load Balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-book-app-nlb
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "http"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "3000"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
spec:
  selector:
    app: go-book-app
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
```

### Key Annotations for NLB:

- `aws-load-balancer-type: "external"`: Uses the AWS Load Balancer Controller
- `aws-load-balancer-nlb-target-type: "instance"`: Uses instance targets (EC2 instances)
- `aws-load-balancer-scheme: "internet-facing"`: Makes the NLB accessible from the internet
- `aws-load-balancer-backend-protocol: "tcp"`: Uses TCP protocol for backend communication
- `aws-load-balancer-cross-zone-load-balancing-enabled: "true"`: Enables cross-zone load balancing
- Health check configurations for the NLB

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

### 4. Apply the Service Manifest (Choose one option)

#### For Classic Load Balancer:
```bash
kubectl apply -f yaml/book-service.yaml
```

#### For Network Load Balancer (using AWS Load Balancer Controller):
```bash
kubectl apply -f yaml/book-service-new.yaml
```

### 5. Verify the Service

#### For Classic Load Balancer:
```bash
kubectl get service go-book-app-service
```

Expected output:
```
NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)        AGE
go-book-app-service   LoadBalancer   172.20.123.100   a823e0da9bb864ecf847884d95f8a65a-150988925.us-west-2.elb.amazonaws.com   80:32306/TCP   <age>
```

#### For Network Load Balancer:
```bash
kubectl get service go-book-app-nlb
```

Expected output:
```
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
go-book-app-nlb   LoadBalancer   172.20.128.252   k8s-default-gobookap-60b64009f1-57901afec9b43a8d.elb.us-west-2.amazonaws.com   80:32683/TCP   <age>
```

## Accessing the Application

Once the LoadBalancer is provisioned (which may take a few minutes), you can access the application using the EXTERNAL-IP:

### Classic Load Balancer:
```
http://a823e0da9bb864ecf847884d95f8a65a-150988925.us-west-2.elb.amazonaws.com
```

### Network Load Balancer:
```
http://k8s-default-gobookap-60b64009f1-57901afec9b43a8d.elb.us-west-2.amazonaws.com
```

## AWS Load Balancer Details

### Classic Load Balancer
- **Type**: Classic Load Balancer
- **Listeners**: HTTP on port 80
- **Target Group**: EC2 instances in the EKS node group
- **Health Check**: HTTP on the specified path (/)
- **Security Group**: Automatically configured to allow inbound traffic on port 80

### Network Load Balancer (AWS Load Balancer Controller)
- **Type**: Network Load Balancer
- **Listeners**: TCP on port 80
- **Target Group**: EC2 instances in the EKS node group
- **Health Check**: HTTP on the specified path (/)
- **Cross-Zone Load Balancing**: Enabled
- **Scheme**: Internet-facing

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
# Remove Classic Load Balancer Service
kubectl delete -f yaml/book-service.yaml

# Remove Network Load Balancer Service
kubectl delete -f yaml/book-service-new.yaml

# Remove Deployment
kubectl delete -f yaml/book-pod.yaml
```

Note that deleting the services will also delete their respective AWS Load Balancers.

## Troubleshooting

### Pod Not Starting

Check the pod logs:
```bash
kubectl logs -l app=go-book-app
```

### Service Not Creating Load Balancer

Check the service events:
```bash
kubectl describe service go-book-app-nlb
```

### Application Not Accessible

1. Verify the pod is running:
   ```bash
   kubectl get pods -l app=go-book-app
   ```

2. Check if the service has an external IP:
   ```bash
   kubectl get service go-book-app-nlb
   ```

3. Check if the pod is passing health checks:
   ```bash
   kubectl describe pod -l app=go-book-app
   ```

### AWS Load Balancer Controller Issues

If the AWS Load Balancer Controller is not creating the NLB correctly:

1. Check the AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

2. Verify the AWS Load Balancer Controller has the necessary IAM permissions


# Using AWS Application Load Balancer (ALB) Controller with Kubernetes Ingress

This document provides information about using the AWS Application Load Balancer (ALB) Controller with Kubernetes Ingress resources to expose applications.

## Using Ingress with AWS ALB Controller

The `yaml/book-ingress.yaml` file demonstrates how to use Kubernetes Ingress resources with the AWS ALB Controller to create an Application Load Balancer (ALB) for the Go Book application.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: go-book-app-ingress
  namespace: default
  annotations:
    # Use AWS Load Balancer Controller
    kubernetes.io/ingress.class: "alb"
    # Internet facing
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    # Use IP targets
    alb.ingress.kubernetes.io/target-type: "ip"
    # Health check settings
    alb.ingress.kubernetes.io/healthcheck-protocol: "HTTP"
    alb.ingress.kubernetes.io/healthcheck-port: "3000"
    alb.ingress.kubernetes.io/healthcheck-path: "/"
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
    # SSL settings (optional)
    # alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    # alb.ingress.kubernetes.io/ssl-redirect: '443'
    # alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:region:account-id:certificate/certificate-id"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: go-book-app-service-internal
            port:
              number: 80
---
# Internal service for the Ingress to route to
apiVersion: v1
kind: Service
metadata:
  name: go-book-app-service-internal
  namespace: default
spec:
  selector:
    app: go-book-app
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP
```

## Advantages of Using Ingress with ALB Controller

The Ingress approach offers several advantages over using a simple Service of type LoadBalancer:

1. **Advanced Routing Capabilities**: Ingress resources support path-based routing, allowing different URLs to be directed to different services.

2. **Host-Based Routing**: You can implement virtual hosting, routing traffic based on the hostname in the request.

3. **SSL/TLS Termination**: Built-in support for SSL/TLS termination with certificate management.

4. **Centralized Management**: Multiple services can be exposed through a single ALB, reducing costs and simplifying management.

5. **Advanced Features**: Access to ALB-specific features like authentication, redirects, and rewrite rules.

## When to Use Ingress with ALB Controller

The Ingress approach is particularly useful in the following scenarios:

- When you need to expose multiple services through a single load balancer
- When you want to implement complex routing rules based on paths or hostnames
- When you need features specific to Application Load Balancers
- When you want to centralize SSL/TLS termination
- When you need to implement authentication at the load balancer level

## Deploying the Ingress Resource

To deploy the Ingress resource and create an ALB:

```bash
kubectl apply -f yaml/book-ingress.yaml
```

## Verifying the Ingress Deployment

Check the status of the Ingress resource:

```bash
kubectl get ingress go-book-app-ingress
```

Expected output:
```
NAME                  CLASS    HOSTS   ADDRESS                                                                  PORTS   AGE
go-book-app-ingress   <none>   *       k8s-default-gobookap-xxxxxxxxxx.us-west-2.elb.amazonaws.com             80      <age>
```

## Accessing the Application

Once the ALB is provisioned (which may take a few minutes), you can access the application using the ADDRESS shown in the Ingress resource:

```
http://k8s-default-gobookap-xxxxxxxxxx.us-west-2.elb.amazonaws.com
```

## Troubleshooting ALB Ingress Controller Issues

If you encounter issues with the ALB Ingress Controller:

1. Check the Ingress resource status:
   ```bash
   kubectl describe ingress go-book-app-ingress
   ```

2. Check the AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

3. Verify the AWS Load Balancer Controller has the necessary IAM permissions

4. Check if the target groups are healthy in the AWS Management Console
