package router

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/ai"
	"xiguang/backend/internal/app_release"
	"xiguang/backend/internal/archiveimport"
	"xiguang/backend/internal/asr"
	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/billing"
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
	billingMod := billing.New(pool, cfg)
	fragmentSvc := fragment.New(pool)
	releaseMod := app_release.New(pool, cfg, authSvc.Middleware)
	// 在 /users/me 等响应里 piggyback 最新版本 meta，客户端可以零额外请求拿到提示。
	authSvc.SetMetaProvider(func(r *http.Request) any {
		meta := releaseMod.Service.LatestMeta(r.Context(),
			r.URL.Query().Get("channel"),
			r.URL.Query().Get("platform"),
		)
		if meta == nil {
			return nil
		}
		return meta
	})

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(cors(cfg.AllowedOrigin))

	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true,"service":"xiguang-backend"}`))
	})
	r.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
		status := billingMod.Readiness(r)
		code := http.StatusOK
		if !status.Ready {
			code = http.StatusServiceUnavailable
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.WriteHeader(code)
		_ = json.NewEncoder(w).Encode(status)
	})
	r.Get("/metrics", billingMod.Metrics)

	r.Route("/api/v1", func(api chi.Router) {
		api.Mount("/auth", authSvc.Routes())
		api.Mount("/emotions", emotion.Routes())
		api.Mount("/app", releaseMod.Handler.PublicRoutes())
		api.Mount("/billing/webhooks", billingMod.PublicRoutes())

		api.Group(func(private chi.Router) {
			private.Use(authSvc.Middleware)
			private.Mount("/users", authSvc.UserRoutes())
			private.Mount("/fragments", fragmentSvc.Routes())
			private.Mount("/timeline", timeline.New(pool).Routes())
			private.Mount("/tags", tag.New(pool).Routes())
			private.Mount("/stats", stats.New(pool, billingMod.Service).Routes())
			private.Mount("/relations", relation.New(pool).Routes())
			private.Mount("/starmap", starmap.New(pool).Routes())
			private.Mount("/islands", island.New(pool).Routes())
			private.Mount("/island-groups", island.NewGroups(pool))
			private.Mount("/media", media.New(pool, cfg, billingMod.Service).Routes())
			private.Mount("/archive/imports", archiveimport.New(pool, cfg, billingMod.Service).Routes())
			private.Mount("/space", space.New(pool, billingMod.Service))
			private.Mount("/whitenoise", whitenoise.Routes(billingMod.Service))
			private.Mount("/sync", sync.New(pool).Routes())
			private.Mount("/ai", ai.New(pool, cfg, billingMod.Service).Routes())
			private.Mount("/asr", asr.New(cfg).Routes())
			private.Mount("/billing", billingMod.PrivateRoutes())
		})

		// 管理员路由：路径段以 /admin 开头，内部由 RequireAdmin 中间件校验。
		api.Mount("/admin/releases", releaseMod.Handler.AdminRoutes())
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
