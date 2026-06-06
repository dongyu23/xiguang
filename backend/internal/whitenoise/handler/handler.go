package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/whitenoise/service"
)

type Handler struct {
	service *service.Service
}

func New() *Handler {
	return &Handler{service: service.New()}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	return r
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	shared.WriteJSON(w, http.StatusOK, h.service.List())
}
