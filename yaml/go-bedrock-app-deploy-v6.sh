#!/bin/bash

# Make script executable
chmod +x $(dirname "$0")/go-bedrock-app-deploy-v6.sh

# Apply the deployment with new image version
echo "Deploying the application with v6 image (updated UI)..."
kubectl apply -f yaml/go-bedrock-app-deployment-v6.yaml

# Wait for the deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/go-bedrock-app

# Get the service URL
echo "Getting service URL..."
kubectl get service go-bedrock-service

echo "Deployment complete. You can access the application at the URL above."
echo "The updated UI is available at the root endpoint and /converse endpoint"
