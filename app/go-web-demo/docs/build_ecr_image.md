# Building and Pushing Docker Images to Amazon ECR

This document provides instructions for setting up Docker, building the Go web application Docker image, and pushing it to Amazon Elastic Container Registry (ECR).

## Prerequisites

- AWS CLI configured with appropriate permissions
- Access to an AWS account
- Basic knowledge of Docker and container concepts

## Installing Docker

Docker is required to build and manage container images. Follow these steps to install Docker on your system:

### For Amazon Linux / RHEL / CentOS

```bash
# Install Docker
sudo yum install -y docker

# Start the Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Add your user to the docker group (to run Docker without sudo)
sudo usermod -aG docker $(whoami)

# Verify Docker installation
docker --version
```

### For Ubuntu / Debian

```bash
# Update package lists
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io

# Start the Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Add your user to the docker group
sudo usermod -aG docker $(whoami)

# Verify Docker installation
docker --version
```

**Note:** After adding your user to the docker group, you may need to log out and log back in for the changes to take effect.

## Using the Build Script

The repository includes a build script (`build.sh`) that automates the process of building the Docker image and pushing it to Amazon ECR.

### Script Parameters

The build script accepts the following parameters:

- `--repository-name`: Name of the ECR repository (default: "go-book-app")
- `--region`: AWS region for the ECR repository (default: "us-west-2")

### Running the Build Script

```bash
# With default parameters
./build.sh

# With custom parameters
./build.sh --repository-name my-custom-app --region us-east-1
```

### What the Build Script Does

1. **Cleans up Docker system**: Removes unused Docker resources
2. **Builds the Docker image**: Uses the Dockerfile in the current directory
3. **Logs in to AWS ECR**: Authenticates with the ECR registry
4. **Tags the image**: Prepares the image with the appropriate ECR repository URI
5. **Creates ECR repository**: Creates the repository if it doesn't exist
6. **Pushes the image to ECR**: Uploads the image to the ECR repository

## Manual Process (Without the Script)

If you prefer to perform these steps manually, follow these instructions:

### 1. Build the Docker Image

```bash
# Navigate to the application directory
cd /path/to/go-web-demo

# Build the image
docker build -t go-web-app .
```

### 2. Create an ECR Repository

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create the repository
aws ecr create-repository --repository-name go-book-app --region us-west-2
```

### 3. Tag the Docker Image

```bash
# Tag the image for ECR
docker tag go-web-app:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/go-book-app:latest
```

### 4. Log in to ECR

```bash
# Authenticate Docker with ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com
```

### 5. Push the Image to ECR

```bash
# Push the image
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/go-book-app:latest
```

## Verifying the Image in ECR

After pushing the image, you can verify it was uploaded successfully:

```bash
# List images in the repository
aws ecr describe-images --repository-name go-book-app --region us-west-2
```

## Troubleshooting

- **Docker login fails**: Ensure your AWS CLI is configured correctly and you have permissions to access ECR
- **Push fails**: Check your network connection and ECR permissions
- **Build fails**: Verify that your Dockerfile is correct and all required files are present
- **Permission denied**: Make sure you've added your user to the docker group and logged out/in

## Next Steps

After successfully pushing your image to ECR, you can:

1. Deploy the image to Amazon ECS, EKS, or other container services
2. Set up CI/CD pipelines to automate the build and push process
3. Implement image scanning and vulnerability assessment
4. Configure lifecycle policies to manage image retention
