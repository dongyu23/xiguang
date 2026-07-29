package space

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/space/handler"
	"xiguang/backend/internal/space/repository"
	"xiguang/backend/internal/space/service"
)

func New(db *pgxpool.Pool, entitlements service.EntitlementService) http.Handler {
	return handler.New(service.New(repository.NewPG(db), entitlements)).Routes()
}
