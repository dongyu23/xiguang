package provider

import (
	"context"
	"errors"
)

var ErrNotConfigured = errors.New("asr provider is not configured")

type Provider interface {
	Recognize(ctx context.Context, req RecognizeRequest) (RecognizeResponse, error)
}

type RecognizeRequest struct {
	AudioBase64 string
	Format      string
	DataLen     int
	SampleRate  int
}

type RecognizeResponse struct {
	Text string
}
