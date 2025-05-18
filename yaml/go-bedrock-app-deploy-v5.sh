#!/bin/bash

# Make script executable
chmod +x $(dirname "$0")/go-bedrock-app-deploy-v5.sh

# Apply the deployment with new image version
echo "Deploying the application with v5 image..."
kubectl apply -f yaml/go-bedrock-app-deployment-v5.yaml

# Wait for the deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/go-bedrock-app

# Get the service URL
echo "Getting service URL..."
kubectl get service go-bedrock-service

echo "Deployment complete. You can access the application at the URL above."
echo "The new /converse endpoint is available at: https://<service-url>/converse"
