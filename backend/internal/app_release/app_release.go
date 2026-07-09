package app_release

import (
	"net/http"
	"os"
	"path/filepath"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/app_release/domain"
	"xiguang/backend/internal/app_release/handler"
	"xiguang/backend/internal/app_release/repository"
	"xiguang/backend/internal/app_release/service"
	"xiguang/backend/internal/infra/config"
)

// Service 暴露给其他模块（如 auth）做 piggyback meta 注入。
type Service = service.Service

// Handler 暴露公共/管理路由。
type Handler = handler.Handler

// Release 是发布实体（不导出 internal/domain 的细节）。
type Release = domain.Release

// VersionMeta 是 piggyback 携带的轻量版本信息。
type VersionMeta = domain.VersionMeta

// Module 组装 app_release 的所有依赖，供 router 使用。
type Module struct {
	Service *Service
	Handler *Handler
}

// New 接收 db 池、运行配置、auth 的 JWT 中间件，返回完整模块。
// auth 中间件以函数形式注入避免循环依赖。
func New(pool *pgxpool.Pool, cfg config.Config, authMW func(http.Handler) http.Handler) *Module {
	repo := repository.NewPG(pool)
	dir := cfg.ReleaseStaticDir
	checker := makeFileChecker(dir)
	svc := service.New(repo, cfg.ReleaseDownloadBase, checker)
	h := handler.New(svc, pool, authMW)
	return &Module{Service: svc, Handler: h}
}

func makeFileChecker(dir string) func(name string) bool {
	if dir == "" {
		// 没配置时跳过文件存在性校验，便于本地开发只测元数据接口。
		return nil
	}
	return func(name string) bool {
		if name == "" {
			return false
		}
		info, err := os.Stat(filepath.Join(dir, name))
		return err == nil && !info.IsDir()
	}
}
