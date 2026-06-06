package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/space/service"
)

type Handler struct {
	service *service.Service
}

func New() *Handler {
	return &Handler{service: service.New()}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/config", h.getConfig)
	r.Put("/config", h.updateConfig)
	return r
}

func (h *Handler) getConfig(w http.ResponseWriter, r *http.Request) {
	shared.WriteJSON(w, http.StatusOK, h.service.Config())
}

func (h *Handler) updateConfig(w http.ResponseWriter, r *http.Request) {
	shared.WriteJSON(w, http.StatusOK, h.service.UpdateConfig())
}
