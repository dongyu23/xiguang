package router

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/ai"
	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/emotion"
	"xiguang/backend/internal/fragment"
	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/island"
	"xiguang/backend/internal/media"
	"xiguang/backend/internal/relation"
	"xiguang/backend/internal/space"
	"xiguang/backend/internal/starmap"
	"xiguang/backend/internal/stats"
	"xiguang/backend/internal/sync"
	"xiguang/backend/internal/tag"
	"xiguang/backend/internal/timeline"
	"xiguang/backend/internal/whitenoise"
)

func New(pool *pgxpool.Pool, cfg config.Config) http.Handler {
	authSvc := auth.New(pool, cfg)
	fragmentSvc := fragment.New(pool)

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))
	r.Use(cors(cfg.AllowedOrigin))

	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true,"service":"xiguang-backend"}`))
	})

	r.Route("/api/v1", func(api chi.Router) {
		api.Mount("/auth", authSvc.Routes())
		api.Mount("/emotions", emotion.Routes())

		api.Group(func(private chi.Router) {
			private.Use(authSvc.Middleware)
			private.Mount("/users", authSvc.UserRoutes())
			private.Mount("/fragments", fragmentSvc.Routes())
			private.Mount("/timeline", timeline.New(pool).Routes())
			private.Mount("/tags", tag.New(pool).Routes())
			private.Mount("/stats", stats.New(pool).Routes())
			private.Mount("/relations", relation.New(pool).Routes())
			private.Mount("/starmap", starmap.New(pool).Routes())
			private.Mount("/islands", island.New(pool).Routes())
			private.Mount("/media", media.New(pool, cfg).Routes())
			private.Mount("/space", space.Routes())
			private.Mount("/whitenoise", whitenoise.Routes())
			private.Mount("/sync", sync.New(pool).Routes())
			private.Mount("/ai", ai.New(pool).Routes())
		})
	})
	return r
}

func cors(origin string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
