package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/timeline/service"
)

type Handler struct {
	service *service.Service
}

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.timeline)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) timeline(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	response, err := h.service.Timeline(r.Context(), userID, r.URL.Query().Get("emotion"), r.URL.Query().Get("tag"), r.URL.Query().Get("limit"))
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "timeline_failed", "时间河暂时无法流动。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, response)
}
