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
	r.Get("/status", h.status)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

const maxPushBatchSize = 100

func (h *Handler) push(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req domain.PushRequest
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "同步请求格式不正确。")
		return
	}
	if len(req.Operations) > maxPushBatchSize {
		shared.WriteError(w, http.StatusBadRequest, "batch_too_large", "单次最多推送 100 条操作。")
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

func (h *Handler) status(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	status, err := h.service.Status(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "sync_failed", "暂时无法获取同步状态。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, status)
}
