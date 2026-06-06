package handler

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"xiguang/backend/internal/asr/provider"
	"xiguang/backend/internal/asr/service"
)

type unavailableProvider struct{}

func (p unavailableProvider) Recognize(ctx context.Context, req provider.RecognizeRequest) (provider.RecognizeResponse, error) {
	return provider.RecognizeResponse{}, provider.ErrNotConfigured
}

func TestRecognizeRejectsBadRequest(t *testing.T) {
	h := New(service.New("tencent", unavailableProvider{}), nil)
	req := httptest.NewRequest(http.MethodPost, "/recognize", bytes.NewBufferString(`{"audio_base64":""}`))
	rec := httptest.NewRecorder()

	h.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestRecognizeReportsMissingProviderConfig(t *testing.T) {
	h := New(service.New("tencent", unavailableProvider{}), nil)
	req := httptest.NewRequest(http.MethodPost, "/recognize", bytes.NewBufferString(`{"audio_base64":"YXVkaW8=","format":"wav"}`))
	rec := httptest.NewRecorder()

	h.Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d: %s", rec.Code, rec.Body.String())
	}
}
