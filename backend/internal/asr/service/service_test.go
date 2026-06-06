package service

import (
	"context"
	"encoding/base64"
	"testing"

	"xiguang/backend/internal/asr/domain"
	"xiguang/backend/internal/asr/provider"
)

type fakeProvider struct {
	called bool
	req    provider.RecognizeRequest
}

func (p *fakeProvider) Recognize(ctx context.Context, req provider.RecognizeRequest) (provider.RecognizeResponse, error) {
	p.called = true
	p.req = req
	return provider.RecognizeResponse{Text: "你好"}, nil
}

func TestRecognizeRejectsInvalidAudio(t *testing.T) {
	fake := &fakeProvider{}
	svc := New("tencent", fake)
	_, err := svc.Recognize(context.Background(), domain.RecognizeRequest{
		AudioBase64: "not-base64",
		Format:      "wav",
	})
	if err != ErrInvalidAudio {
		t.Fatalf("expected ErrInvalidAudio, got %v", err)
	}
	if fake.called {
		t.Fatal("provider should not be called for invalid audio")
	}
}

func TestRecognizePassesDecodedLengthToProvider(t *testing.T) {
	fake := &fakeProvider{}
	svc := New("tencent", fake)
	result, err := svc.Recognize(context.Background(), domain.RecognizeRequest{
		AudioBase64: base64.StdEncoding.EncodeToString([]byte("audio")),
		Format:      "WAV",
		SampleRate:  16000,
	})
	if err != nil {
		t.Fatalf("recognize: %v", err)
	}
	if result.Text != "你好" || result.Provider != "tencent" {
		t.Fatalf("unexpected result: %+v", result)
	}
	if !fake.called {
		t.Fatal("provider was not called")
	}
	if fake.req.DataLen != 5 || fake.req.Format != "wav" || fake.req.SampleRate != 16000 {
		t.Fatalf("unexpected provider request: %+v", fake.req)
	}
}
