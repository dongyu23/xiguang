package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/space/domain"
	"xiguang/backend/internal/space/service"
)

type Handler struct{ service *service.Service }

func New(service *service.Service) *Handler { return &Handler{service: service} }

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/config", h.getConfig)
	r.Put("/config", h.updateConfig)
	r.Get("/theme", h.currentTheme)
	r.Get("/themes", h.themes)
	return r
}

func (h *Handler) getConfig(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	config, err := h.service.Config(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "space_failed", "暂时无法读取空间配置。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, config)
}

func (h *Handler) currentTheme(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	theme, err := h.service.CurrentTheme(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "space_failed", "暂时无法读取空间主题。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, theme)
}

func (h *Handler) themes(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	items, err := h.service.Themes(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "space_failed", "暂时无法读取空间主题。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) updateConfig(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var config domain.Config
	if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "空间配置格式不正确。")
		return
	}
	updated, err := h.service.UpdateConfig(r.Context(), userID, config)
	if errors.Is(err, service.ErrThemeNotFound) {
		shared.WriteError(w, http.StatusBadRequest, "space_theme_not_found", "没有找到这个空间主题。")
		return
	}
	if errors.Is(err, service.ErrEntitlementNeeded) {
		shared.WriteError(w, http.StatusForbidden, "entitlement_required", "这个空间主题需要星光会员。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "space_failed", "暂时无法保存空间配置。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, updated)
}
