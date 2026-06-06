package provider

import "context"

type Provider interface {
	Chat(ctx context.Context, prompt, model string) (response string, tokensUsed int, err error)
}
