package provider

import (
	"context"

	"xiguang/backend/internal/infra/config"
)

type DeepSeek struct {
	baseURL string
	apiKey  string
}

func NewDeepSeek(cfg config.Config) *DeepSeek {
	return &DeepSeek{baseURL: cfg.DeepSeekBaseURL, apiKey: cfg.DeepSeekAPIKey}
}

func (p *DeepSeek) Chat(ctx context.Context, prompt, model string) (string, int, error) {
	return "", 0, ErrNotConfigured
}
