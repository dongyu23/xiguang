package ai

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/ai/domain"
	"xiguang/backend/internal/ai/handler"
	"xiguang/backend/internal/ai/repository"
	"xiguang/backend/internal/ai/service"
)

type Handler = handler.Handler
type GlowSummaryRequest = domain.GlowSummaryRequest
type GlowSummaryResponse = domain.GlowSummaryResponse

func New(db *pgxpool.Pool) *Handler {
	return handler.New(service.New(repository.NewPG(db)))
}

var _ http.Handler = (*Handler)(nil)
