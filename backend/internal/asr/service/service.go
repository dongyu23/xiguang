package service

import (
	"context"
	"encoding/base64"
	"errors"
	"strings"

	"xiguang/backend/internal/asr/domain"
	"xiguang/backend/internal/asr/provider"
)

var (
	ErrInvalidAudio = errors.New("invalid audio")
	ErrUnsupported  = errors.New("unsupported asr provider")
)

type Service struct {
	providerName string
	provider     provider.Provider
}

func New(providerName string, asrProvider provider.Provider) *Service {
	return &Service{providerName: strings.ToLower(providerName), provider: asrProvider}
}

func (s *Service) Recognize(ctx context.Context, req domain.RecognizeRequest) (domain.RecognizeResponse, error) {
	if s.provider == nil || s.providerName == "" || s.providerName == "none" {
		return domain.RecognizeResponse{}, ErrUnsupported
	}
	format := strings.ToLower(strings.TrimSpace(req.Format))
	if !isSupportedFormat(format) {
		return domain.RecognizeResponse{}, ErrInvalidAudio
	}
	audioBase64 := normalizeBase64(req.AudioBase64)
	if audioBase64 == "" {
		return domain.RecognizeResponse{}, ErrInvalidAudio
	}
	audioBytes, err := base64.StdEncoding.DecodeString(audioBase64)
	if err != nil || len(audioBytes) == 0 {
		return domain.RecognizeResponse{}, ErrInvalidAudio
	}
	if len(audioBytes) > 3*1024*1024 {
		return domain.RecognizeResponse{}, ErrInvalidAudio
	}

	result, err := s.provider.Recognize(ctx, provider.RecognizeRequest{
		AudioBase64: audioBase64,
		Format:      format,
		DataLen:     len(audioBytes),
		SampleRate:  req.SampleRate,
	})
	if err != nil {
		return domain.RecognizeResponse{}, err
	}
	return domain.RecognizeResponse{
		Text:     result.Text,
		Provider: s.providerName,
	}, nil
}

func normalizeBase64(value string) string {
	value = strings.TrimSpace(value)
	if comma := strings.Index(value, ","); comma >= 0 && strings.Contains(value[:comma], "base64") {
		value = value[comma+1:]
	}
	return strings.Map(func(r rune) rune {
		switch r {
		case '\r', '\n', '\t', ' ':
			return -1
		default:
			return r
		}
	}, value)
}

func isSupportedFormat(format string) bool {
	switch format {
	case "wav", "pcm", "ogg-opus", "mp3", "m4a":
		return true
	default:
		return false
	}
}
