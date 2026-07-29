package stats

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	billingdomain "xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/stats/handler"
	"xiguang/backend/internal/stats/repository"
	"xiguang/backend/internal/stats/service"
)

type Handler = handler.Handler

type EntitlementService interface {
	Entitlement(context.Context, int64) (billingdomain.Entitlement, error)
}

func New(db *pgxpool.Pool, entitlements EntitlementService) *Handler {
	repo := repository.NewPG(db)
	return handler.New(service.New(repo), entitlements)
}

var _ http.Handler = (*Handler)(nil)
