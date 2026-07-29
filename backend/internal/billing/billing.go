package billing

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/billing/handler"
	"xiguang/backend/internal/billing/repository"
	"xiguang/backend/internal/billing/service"
	"xiguang/backend/internal/infra/config"
)

type Module struct {
	Handler *handler.Handler
	Service *service.Service
}

func New(db *pgxpool.Pool, cfg config.Config) *Module {
	module := newModule(db, cfg)
	go module.Service.Run(context.Background())
	return module
}

func NewInitializer(db *pgxpool.Pool, cfg config.Config) *Module {
	return newModule(db, cfg)
}

func newModule(db *pgxpool.Pool, cfg config.Config) *Module {
	s := service.New(repository.NewPG(db), cfg)
	prepareCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	_ = s.PrepareInitialization(prepareCtx)
	cancel()
	return &Module{Handler: handler.New(s), Service: s}
}
func (m *Module) PrivateRoutes() http.Handler                { return m.Handler.PrivateRoutes() }
func (m *Module) PublicRoutes() http.Handler                 { return m.Handler.PublicRoutes() }
func (m *Module) Readiness(r *http.Request) domain.Readiness { return m.Service.Readiness(r.Context()) }
func (m *Module) Metrics(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	_, _ = w.Write([]byte(m.Service.MetricsText(r.Context())))
}
