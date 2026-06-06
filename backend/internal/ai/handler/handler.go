package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/ai/domain"
	"xiguang/backend/internal/ai/service"
	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
)

type Handler struct {
	service *service.Service
}

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Post("/glow-summary", h.glowSummary)
	r.Get("/requests", h.requests)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) glowSummary(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req domain.GlowSummaryRequest
	_ = shared.DecodeJSON(r, &req)
	shared.WriteJSON(w, http.StatusAccepted, h.service.GlowSummary(r.Context(), userID, req))
}

func (h *Handler) requests(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	items, err := h.service.Requests(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "ai_failed", "暂时无法读取柔光整理记录。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, items)
}
