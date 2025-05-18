// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package bedrock

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
)

// Claude3 Converse request data type
type ConverseRequestBodyClaude3 struct {
	MaxTokens        int       `json:"max_tokens"`
	Temperature      float64   `json:"temperature,omitempty"`
	System           string    `json:"system,omitempty"`
	Messages         []Message `json:"messages"`
	AnthropicVersion string    `json:"anthropic_version"`
}

// Claude3 Converse response data type
type ConverseResponseClaude3 struct {
	ID           string    `json:"id"`
	Type         string    `json:"type"`
	Role         string    `json:"role"`
	Content      []Content `json:"content"`
	Model        string    `json:"model"`
	StopReason   string    `json:"stop_reason"`
	StopSequence string    `json:"stop_sequence"`
	Usage        struct {
		InputTokens  int `json:"input_tokens"`
		OutputTokens int `json:"output_tokens"`
	} `json:"usage"`
}

func HandleBedrockClaude3HaikuChatConverse(w http.ResponseWriter, r *http.Request, BedrockClient *bedrockruntime.Client) {
	// Start timing for latency measurement
	startTime := time.Now()

	// List of messages sent from frontend client
	var request FrontEndRequest

	// Parse message from request
	err := json.NewDecoder(r.Body).Decode(&request)
	if err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, "Error decoding request", http.StatusBadRequest)
		return
	}

	messages := request.Messages
	log.Printf("Received request with %d messages", len(messages))

	// Create payload for Bedrock InvokeModel API (non-streaming)
	payload := ConverseRequestBodyClaude3{
		MaxTokens:        2048,
		Temperature:      0.9,
		Messages:         messages,
		AnthropicVersion: "bedrock-2023-05-31",
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		log.Printf("Error marshaling payload: %v", err)
		http.Error(w, "Error preparing request", http.StatusInternalServerError)
		return
	}

	// Log the request being sent to Bedrock
	log.Printf("Sending request to Bedrock InvokeModel API")

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
	
	if err != nil {
		log.Printf("Error invoking Bedrock InvokeModel API: %v (latency: %dms)", err, latency)
		http.Error(w, "Error from Bedrock service", http.StatusInternalServerError)
		return
	}

	// Parse the response
	var response ConverseResponseClaude3
	err = json.Unmarshal(output.Body, &response)
	if err != nil {
		log.Printf("Error unmarshaling response: %v (latency: %dms)", err, latency)
		http.Error(w, "Error processing response", http.StatusInternalServerError)
		return
	}

	// Log detailed response information for CloudWatch Insights queries
	log.Printf("Bedrock InvokeModel API response received - ID: %s, Model: %s, InputTokens: %d, OutputTokens: %d, StopReason: %s, Latency: %dms",
		response.ID,
		response.Model,
		response.Usage.InputTokens,
		response.Usage.OutputTokens,
		response.StopReason,
		latency)

	// Extract the text content from the response
	var responseText string
	for _, content := range response.Content {
		if content.Type == "text" {
			responseText += content.Text
		}
	}

	// Create a simple response structure
	simpleResponse := struct {
		Text    string `json:"text"`
		Latency int64  `json:"latency_ms"`
	}{
		Text:    responseText,
		Latency: latency,
	}

	// Set content type and send response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(simpleResponse)
}
