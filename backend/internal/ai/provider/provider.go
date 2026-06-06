package provider

import "context"

type Provider interface {
	Chat(ctx context.Context, systemPrompt, userMessage string) (response string, tokensUsed int, err error)
}
