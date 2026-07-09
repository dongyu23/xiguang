package handler

import (
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/app_release/domain"
	"xiguang/backend/internal/app_release/service"
	authmw "xiguang/backend/internal/auth/middleware"
	"xiguang/backend/internal/shared"
)

type Handler struct {
	service *service.Service
	pool    *pgxpool.Pool
	authMW  func(http.Handler) http.Handler
}

func New(svc *service.Service, pool *pgxpool.Pool, authMW func(http.Handler) http.Handler) *Handler {
	return &Handler{service: svc, pool: pool, authMW: authMW}
}

// PublicRoutes 挂在 /api/v1/app/，无需登录就能查最新版本。
func (h *Handler) PublicRoutes() http.Handler {
	r := chi.NewRouter()
	r.Get("/version", h.latest)
	return r
}

// AdminRoutes 挂在 /api/v1/admin/releases/，需要登录 + is_admin。
func (h *Handler) AdminRoutes() http.Handler {
	r := chi.NewRouter()
	if h.authMW != nil {
		r.Use(h.authMW)
	}
	r.Use(authmw.RequireAdmin(h.pool))
	r.Get("/", h.adminList)
	r.Get("/{public_id}", h.adminDetail)
	r.Post("/", h.adminPublish)
	r.Patch("/{public_id}", h.adminUpdatePolicy)
	r.Delete("/{public_id}", h.adminRetract)
	return r
}

// latest — GET /app/version?channel=stable&platform=android
func (h *Handler) latest(w http.ResponseWriter, r *http.Request) {
	view, err := h.service.LatestPublic(r.Context(),
		r.URL.Query().Get("channel"),
		r.URL.Query().Get("platform"),
	)
	if errors.Is(err, service.ErrInvalidParams) {
		shared.WriteError(w, http.StatusBadRequest, "validation.invalid_param", "请求参数不正确。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "common.internal_error", "暂时无法查询版本。")
		return
	}
	// view 为 nil 表示没有发布过任何版本 — 返回 data: null，前端容错处理。
	shared.WriteJSON(w, http.StatusOK, view)
}

func (h *Handler) adminList(w http.ResponseWriter, r *http.Request) {
	includeDeleted := strings.EqualFold(r.URL.Query().Get("include_deleted"), "true")
	items, err := h.service.List(r.Context(), includeDeleted, 50)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "common.internal_error", "暂时无法读取发布列表。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) adminDetail(w http.ResponseWriter, r *http.Request) {
	rel, err := h.service.GetByPublicID(r.Context(), chi.URLParam(r, "public_id"))
	if errors.Is(err, service.ErrNotFound) {
		shared.WriteError(w, http.StatusNotFound, "release.not_found", "找不到这个发布。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "common.internal_error", "暂时无法读取发布详情。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, rel)
}

func (h *Handler) adminPublish(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Channel           string `json:"channel"`
		Platform          string `json:"platform"`
		Version           string `json:"version"`
		BuildNumber       int    `json:"build_number"`
		MinSupportedBuild int    `json:"min_supported_build"`
		APKFileName       string `json:"apk_file_name"`
		APKSizeBytes      int64  `json:"apk_size_bytes"`
		SHA256            string `json:"sha256"`
		ReleaseNote       string `json:"release_note"`
		ForceUpdate       bool   `json:"force_update"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "validation.invalid_param", "请求格式不正确。")
		return
	}
	rel, err := h.service.Publish(r.Context(), domain.PublishParams{
		Channel:           req.Channel,
		Platform:          req.Platform,
		Version:           req.Version,
		BuildNumber:       req.BuildNumber,
		MinSupportedBuild: req.MinSupportedBuild,
		APKFileName:       req.APKFileName,
		APKSizeBytes:      req.APKSizeBytes,
		SHA256:            req.SHA256,
		ReleaseNote:       req.ReleaseNote,
		ForceUpdate:       req.ForceUpdate,
	})
	switch {
	case errors.Is(err, service.ErrInvalidParams),
		errors.Is(err, service.ErrInvalidChannel),
		errors.Is(err, service.ErrInvalidPlatform),
		errors.Is(err, service.ErrInvalidSHA256),
		errors.Is(err, service.ErrInvalidFileName):
		shared.WriteError(w, http.StatusBadRequest, "validation.invalid_param", err.Error())
		return
	case errors.Is(err, service.ErrBuildNotIncreasing):
		shared.WriteError(w, http.StatusConflict, "release.build_not_increasing", "build_number 必须大于该 channel 当前最新版本。")
		return
	case err != nil:
		shared.WriteError(w, http.StatusInternalServerError, "common.internal_error", "暂时无法发布。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, rel)
}

func (h *Handler) adminUpdatePolicy(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ReleaseNote       *string `json:"release_note"`
		ForceUpdate       *bool   `json:"force_update"`
		MinSupportedBuild *int    `json:"min_supported_build"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "validation.invalid_param", "请求格式不正确。")
		return
	}
	rel, err := h.service.UpdatePolicy(r.Context(), chi.URLParam(r, "public_id"), domain.UpdatePolicyParams{
		ReleaseNote:       req.ReleaseNote,
		ForceUpdate:       req.ForceUpdate,
		MinSupportedBuild: req.MinSupportedBuild,
	})
	switch {
	case errors.Is(err, service.ErrInvalidParams):
		shared.WriteError(w, http.StatusBadRequest, "validation.invalid_param", "至少需要修改一项字段。")
		return
	case errors.Is(err, service.ErrNotFound):
		shared.WriteError(w, http.StatusNotFound, "release.not_found", "找不到这个发布。")
		return
	case err != nil:
		shared.WriteError(w, http.StatusInternalServerError, "common.internal_error", "暂时无法更新。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, rel)
}

func (h *Handler) adminRetract(w http.ResponseWriter, r *http.Request) {
	ok, err := h.service.Retract(r.Context(), chi.URLParam(r, "public_id"))
	if errors.Is(err, service.ErrNotFound) {
		shared.WriteError(w, http.StatusNotFound, "release.not_found", "找不到这个发布。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "common.internal_error", "暂时无法下架。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"retracted": ok})
}
