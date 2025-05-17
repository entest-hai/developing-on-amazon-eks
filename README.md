# Developing on Amazon EKS

This repository contains resources for developing and deploying applications on Amazon Elastic Kubernetes Service (EKS). It includes a sample Go web application, Kubernetes deployment configurations, and comprehensive documentation.

## Repository Structure

```
.
├── app/
│   └── go-web-demo/         # Sample Go web application
│       ├── docs/            # Application-specific documentation
│       ├── static/          # Static assets for the web app
│       ├── build.sh         # Script to build and push Docker image to ECR
│       ├── Dockerfile       # Docker configuration for the application
│       └── main.go          # Main Go application code
├── docs/                    # General EKS and deployment documentation
├── template/                # CloudFormation templates for EKS setup
└── yaml/                    # Kubernetes deployment YAML files
```

## Sample Application

The repository includes a Go web application that demonstrates:
- Building a simple web server in Go
- Containerizing the application with Docker
- Pushing the container to Amazon ECR
- Deploying the application to Amazon EKS

### Building and Deploying the Application

1. Build and push the Docker image to ECR:
   ```bash
   cd app/go-web-demo
   ./build.sh --repository-name go-book-app --region us-west-2
   ```

2. Deploy the application to EKS:
   ```bash
   kubectl apply -f yaml/book-pod.yaml
   ```

3. Expose the application with different load balancer options:
   ```bash
   # Classic Load Balancer
   kubectl apply -f yaml/book-service.yaml
   
   # Network Load Balancer (AWS Load Balancer Controller)
   kubectl apply -f yaml/book-service-new.yaml
   
   # Application Load Balancer (AWS Load Balancer Controller with Ingress)
   kubectl apply -f yaml/book-ingress.yaml
   ```

## Documentation

The repository includes detailed documentation on various aspects of working with Amazon EKS:

### Application Documentation

- [Setting up the Go Application](app/go-web-demo/docs/setup_app.md)
- [Building and Pushing Docker Images to ECR](app/go-web-demo/docs/build_ecr_image.md)

### EKS and Kubernetes Documentation

- [Deploying an EKS Cluster](docs/deploy_eks_cluster.md)
- [Setting up kubectl](docs/setup_kubectl.md)
- [kubectl Authentication](docs/kubectl_authentication.md)
- [Deploying Applications to EKS](docs/deploy_book_app.md)
- [Setting up AWS Load Balancer Controller](docs/setup_alb_controller.md)
- [Using AWS ALB Controller with Ingress](docs/deploy_book_app_alb_controller.md)

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Docker installed for building container images
- Access to an Amazon EKS cluster

## Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/entest-hai/developing-on-amazon-eks.git
   cd developing-on-amazon-eks
   ```

2. Follow the documentation in the `docs` directory to set up your EKS environment.

3. Build and deploy the sample application following the instructions above.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
