# Implementing Bedrock Converse API for Claude 3 Haiku

This document details the implementation of the Bedrock Converse API for the Claude 3 Haiku model in our go-bedrock-app application.

## Overview

We've added a new endpoint `/converse` to our application that uses Amazon Bedrock's InvokeModel API (non-streaming) instead of the streaming API used in the original implementation. This allows us to:

1. Get complete responses at once
2. Log detailed metrics about API calls
3. Measure and track latency for each request
4. Provide a better user experience for certain use cases

## Implementation Details

### 1. New Backend Function

We created a new function `HandleBedrockClaude3HaikuChatConverse` in `bedrock/bedrock_converse.go` that:

- Uses the InvokeModel API instead of InvokeModelWithResponseStream
- Logs detailed information about each request and response
- Measures and reports latency for each API call
- Returns a structured JSON response with the text and latency information

```go
func HandleBedrockClaude3HaikuChatConverse(w http.ResponseWriter, r *http.Request, BedrockClient *bedrockruntime.Client) {
    // Start timing for latency measurement
    startTime := time.Now()
    
    // Process request...
    
    // Invoke Bedrock InvokeModel API (non-streaming)
    output, err := BedrockClient.InvokeModel(
        context.Background(),
        &bedrockruntime.InvokeModelInput{
            ModelId:     aws.String("anthropic.claude-3-haiku-20240307-v1:0"),
            ContentType: aws.String("application/json"),
            Accept:      aws.String("application/json"),
            Body:        payloadBytes,
        },
    )
    
    // Calculate and log latency
    latency := time.Since(startTime).Milliseconds()
    
    // Log detailed response information for CloudWatch Insights queries
    log.Printf("Bedrock InvokeModel API response received - ID: %s, Model: %s, InputTokens: %d, OutputTokens: %d, StopReason: %s, Latency: %dms",
        response.ID,
        response.Model,
        response.Usage.InputTokens,
        response.Usage.OutputTokens,
        response.StopReason,
        latency)
        
    // Return response...
}
```

### 2. New Frontend Page

We created a new HTML page `static/claude-haiku-converse.html` that:

- Provides a chat interface similar to the original
- Displays latency information for each response
- Handles the non-streaming response format
- Shows loading indicators during API calls

### 3. Routes Added

We added two new routes in `main.go`:

```go
// frontend claude haiku converse
mux.HandleFunc("/converse", func(w http.ResponseWriter, r *http.Request) {
    content, error := os.ReadFile("./static/claude-haiku-converse.html")
    if error != nil {
        fmt.Println(error)
    }
    w.Write(content)
})

// backend claude haiku converse
mux.HandleFunc("/bedrock-haiku-converse", func(w http.ResponseWriter, r *http.Request) {
    if r.Method == "POST" {
        gobedrock.HandleBedrockClaude3HaikuChatConverse(w, r, BedrockClient)
    }
})
```

## Deployment Process

1. Built and pushed a new Docker image with tag v5:
   ```bash
   ./deploy/build_push_image_v5.sh
   ```

2. Created a new deployment YAML file with the updated image and CloudWatch logging:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: go-bedrock-app
     # ...
   spec:
     # ...
     template:
       metadata:
         annotations:
           fluentbit.io/parser: cri  # For CloudWatch logging
       spec:
         containers:
         - name: go-bedrock-app
           image: 535915401024.dkr.ecr.us-west-2.amazonaws.com/go-bedrock-app:v5
           # ...
   ```

3. Deployed the updated application to EKS:
   ```bash
   kubectl apply -f yaml/go-bedrock-app-deployment-v5-fixed.yaml
   ```

## CloudWatch Logging

The new implementation includes detailed logging that can be queried in CloudWatch Logs Insights:

### Sample Queries

#### Query for Bedrock API Latency
```
fields @timestamp, @message
| filter @message like "Bedrock InvokeModel API response received"
| parse @message "Latency: *ms" as latency
| stats avg(latency) as avg_latency_ms, min(latency) as min_latency_ms, max(latency) as max_latency_ms
```

#### Query for Token Usage
```
fields @timestamp, @message
| filter @message like "Bedrock InvokeModel API response received"
| parse @message "InputTokens: *, OutputTokens: *," as input_tokens, output_tokens
| stats avg(input_tokens) as avg_input_tokens, avg(output_tokens) as avg_output_tokens, sum(input_tokens) as total_input_tokens, sum(output_tokens) as total_output_tokens
```

## Accessing the Application

The application is now accessible at:
- Main URL: https://k8s-default-gobedroc-29ca929843-a6e0fe1b6942ceef.elb.us-west-2.amazonaws.com
- Converse endpoint: https://k8s-default-gobedroc-29ca929843-a6e0fe1b6942ceef.elb.us-west-2.amazonaws.com/converse

## Next Steps

1. Implement streaming version of the Converse API
2. Add more detailed metrics and logging
3. Create CloudWatch dashboards for monitoring API usage and performance
4. Set up alerts for high latency or error rates
