#!/bin/bash
set -e

# Default parameters
REPOSITORY_NAME="go-bedrock-app"
REGION="us-west-2"
TAG="latest"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --repository-name)
      REPOSITORY_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--repository-name NAME] [--region REGION] [--tag TAG]"
      exit 1
      ;;
  esac
done

echo "Building and pushing Docker image with the following settings:"
echo "Repository Name: $REPOSITORY_NAME"
echo "Region: $REGION"
echo "Tag: $TAG"

# Get AWS account ID
ACCOUNT=$(aws sts get-caller-identity | jq -r '.Account')
if [ -z "$ACCOUNT" ]; then
  echo "Error: Failed to get AWS account ID. Make sure AWS CLI is configured properly."
  exit 1
fi

# Clean up Docker system (optional, uncomment if needed)
# echo "Cleaning up Docker system..."
# sudo docker system prune -a -f

# Build application image
echo "Building Docker image..."
sudo docker build -t $REPOSITORY_NAME:$TAG .

# AWS ECR login
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# Get image ID
IMAGE_ID=$(sudo docker images -q $REPOSITORY_NAME:$TAG)
if [ -z "$IMAGE_ID" ]; then
  echo "Error: Failed to get Docker image ID. Build may have failed."
  exit 1
fi

# Tag image
echo "Tagging Docker image..."
sudo docker tag $IMAGE_ID $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:$TAG

# Create ECR repository if it doesn't exist
echo "Creating ECR repository if it doesn't exist..."
aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creating new ECR repository: $REPOSITORY_NAME"
  aws ecr create-repository --registry-id $ACCOUNT --repository-name $REPOSITORY_NAME --region $REGION
else
  echo "Repository $REPOSITORY_NAME already exists"
fi

# Push image to ECR
echo "Pushing image to ECR..."
sudo docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:$TAG

echo "Build and push completed successfully!"
echo "Image: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:$TAG"

# Uncomment to run locally for testing
# echo "Running container locally on port 3000..."
# sudo docker run -d -p 3000:3000 $REPOSITORY_NAME:$TAG

# Update deployment YAML with the new image (optional)
# If you want to automatically update the deployment YAML, uncomment and modify the following lines
# DEPLOYMENT_FILE="deploy/go-bedrock-deployment.yaml"
# if [ -f "$DEPLOYMENT_FILE" ]; then
#   echo "Updating deployment file with new image..."
#   sed -i "s|image: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:.*|image: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:$TAG|g" $DEPLOYMENT_FILE
#   echo "Deployment file updated."
# fi
