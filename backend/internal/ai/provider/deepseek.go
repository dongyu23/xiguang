package provider

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"xiguang/backend/internal/infra/config"
)

type DeepSeek struct {
	baseURL    string
	apiKey     string
	model      string
	maxTokens  int
	httpClient *http.Client
}

func NewDeepSeek(cfg config.Config) *DeepSeek {
	return &DeepSeek{
		baseURL:   cfg.DeepSeekBaseURL,
		apiKey:    cfg.DeepSeekAPIKey,
		model:     cfg.DeepSeekModel,
		maxTokens: 4096,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatRequest struct {
	Model          string        `json:"model"`
	Messages       []chatMessage `json:"messages"`
	Temperature    float64       `json:"temperature"`
	MaxTokens      int           `json:"max_tokens"`
	ResponseFormat *struct {
		Type string `json:"type"`
	} `json:"response_format,omitempty"`
}

type chatChoice struct {
	Message chatMessage `json:"message"`
}

type chatUsage struct {
	TotalTokens int `json:"total_tokens"`
}

type chatResponse struct {
	Choices []chatChoice `json:"choices"`
	Usage   chatUsage    `json:"usage"`
	Error   *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

func (p *DeepSeek) Chat(ctx context.Context, systemPrompt, userMessage string) (string, int, error) {
	return p.chat(ctx, systemPrompt, userMessage, true)
}

func (p *DeepSeek) TextChat(ctx context.Context, systemPrompt, userMessage string) (string, int, error) {
	return p.chat(ctx, systemPrompt, userMessage, false)
}

func (p *DeepSeek) chat(ctx context.Context, systemPrompt, userMessage string, jsonResponse bool) (string, int, error) {
	if p.apiKey == "" {
		return "", 0, ErrNotConfigured
	}

	reqBody := chatRequest{
		Model: p.model,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userMessage},
		},
		Temperature: 0.7,
		MaxTokens:   p.maxTokens,
	}
	if jsonResponse {
		reqBody.ResponseFormat = &struct {
			Type string `json:"type"`
		}{Type: "json_object"}
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", 0, fmt.Errorf("marshal request: %w", err)
	}

	url := p.baseURL + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", 0, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+p.apiKey)

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return "", 0, fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", 0, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", 0, fmt.Errorf("deepseek api returned status %d: %s", resp.StatusCode, string(respBytes))
	}

	var cr chatResponse
	if err := json.Unmarshal(respBytes, &cr); err != nil {
		return "", 0, fmt.Errorf("unmarshal response: %w", err)
	}

	if cr.Error != nil {
		return "", 0, fmt.Errorf("deepseek api error: %s", cr.Error.Message)
	}

	if len(cr.Choices) == 0 {
		return "", 0, fmt.Errorf("no choices in response")
	}

	return cr.Choices[0].Message.Content, cr.Usage.TotalTokens, nil
}
