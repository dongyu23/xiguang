package asr

import (
	"net/http"

	"xiguang/backend/internal/asr/handler"
	"xiguang/backend/internal/asr/provider"
	"xiguang/backend/internal/asr/service"
	"xiguang/backend/internal/infra/config"
)

type Handler = handler.Handler

func New(cfg config.Config) *Handler {
	return handler.New(
		service.New(cfg.ASRProvider, provider.NewTencent(cfg)),
		provider.NewRealtimeProxy(cfg),
	)
}

var _ http.Handler = (*Handler)(nil)
