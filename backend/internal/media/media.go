package media

import (
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/infra/storage"
	"xiguang/backend/internal/media/handler"
	"xiguang/backend/internal/media/repository"
	"xiguang/backend/internal/media/service"
)

type Handler = handler.Handler

func New(db *pgxpool.Pool, cfg config.Config, quotas ...service.QuotaService) *Handler {
	var quota service.QuotaService
	if len(quotas) > 0 {
		quota = quotas[0]
	}
	provider, err := storage.NewMinIOProvider(cfg)
	if err != nil {
		slog.Error("media: minio provider init failed, presigned URLs will be unavailable", "error", err)
		return handler.New(service.New(repository.NewPG(db), cfg, nil, quota))
	}
	return handler.New(service.New(repository.NewPG(db), cfg, provider, quota))
}

var _ http.Handler = (*Handler)(nil)
