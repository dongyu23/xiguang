package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/sync/domain"
	"xiguang/backend/internal/sync/service"
)

type Handler struct {
	service *service.Service
}

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Post("/push", h.push)
	r.Get("/pull", h.pull)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) push(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req domain.PushRequest
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "同步请求格式不正确。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, h.service.Push(r.Context(), userID, req))
}

func (h *Handler) pull(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	since, _ := strconv.ParseInt(r.URL.Query().Get("since_rev"), 10, 64)
	response, err := h.service.Pull(r.Context(), userID, since)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "sync_failed", "暂时无法拉取同步数据。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, response)
}
