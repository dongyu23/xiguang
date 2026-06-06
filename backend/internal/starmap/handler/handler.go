package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/starmap/service"
)

type Handler struct {
	service *service.Service
}

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.graph)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) graph(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	graph, err := h.service.Graph(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "starmap_failed", "暂时无法读取星图。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, graph)
}
