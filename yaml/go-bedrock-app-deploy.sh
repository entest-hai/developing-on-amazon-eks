#!/bin/bash

# Create IAM role for the service account
echo "Creating IAM role for service account..."
eksctl create iamserviceaccount -f yaml/go-bedrock-app-iam-role.yaml --approve

# Apply the service account
echo "Applying service account..."
kubectl apply -f yaml/go-bedrock-app-serviceaccount.yaml

# Apply the deployment
echo "Deploying the application..."
kubectl apply -f yaml/go-bedrock-app-deployment.yaml

# Apply the service
echo "Creating the service with AWS Load Balancer Controller..."
kubectl apply -f yaml/go-bedrock-app-service.yaml

# Wait for the deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/go-bedrock-app

# Get the service URL
echo "Getting service URL..."
kubectl get service go-bedrock-service
