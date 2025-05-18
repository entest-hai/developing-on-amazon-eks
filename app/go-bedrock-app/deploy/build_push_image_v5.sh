#!/bin/bash
set -e

# Default values
REGION="us-west-2"
REPOSITORY_NAME="go-bedrock-app"
TAG="v5"  # New version tag for the image with Converse API support

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --region)
      REGION="$2"
      shift 2
      ;;
    --repository-name)
      REPOSITORY_NAME="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $key"
      echo "Usage: $0 [--repository-name REPOSITORY_NAME] [--region REGION] [--tag TAG]"
      exit 1
      ;;
  esac
done

# Get AWS account ID
ACCOUNT=$(aws sts get-caller-identity | jq -r '.Account')

# Navigate to the project root directory
cd "$(dirname "$0")/.."

echo "Using AWS region: $REGION"
echo "Using ECR repository name: $REPOSITORY_NAME"
echo "Using image tag: $TAG"
echo "Building Docker image: $REPOSITORY_NAME:$TAG"

# Update the Dockerfile timestamp to force a rebuild
sed -i "s/# Adding a timestamp to force rebuild:.*/# Adding a timestamp to force rebuild: $(date '+%Y-%m-%d %H:%M:%S')/" Dockerfile

# Build the Docker image
sudo docker build -t $REPOSITORY_NAME:$TAG .

echo "Logging in to AWS ECR in region $REGION"
aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# Check if repository exists, if not create it
aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION || aws ecr create-repository --repository-name $REPOSITORY_NAME --region $REGION

# Get docker image ID
IMAGE_ID=$(sudo docker images -q $REPOSITORY_NAME:$TAG)

echo "Tagging image with ECR repository"
sudo docker tag $IMAGE_ID $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:$TAG
sudo docker tag $IMAGE_ID $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:latest

echo "Pushing image to ECR"
sudo docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:$TAG
sudo docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:latest

echo "Successfully built and pushed $REPOSITORY_NAME:$TAG to ECR"
echo "Image URI: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:$TAG"
