package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/tag/domain"
	"xiguang/backend/internal/tag/service"
)

type Handler struct {
	service *service.Service
}

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	page, err := h.service.List(r.Context(), userID, r.URL.Query().Get("page_size"))
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "tag_failed", "暂时无法读取标签。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, page)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	params, ok := decodeUpsert(w, r)
	if !ok {
		return
	}
	dto, err := h.service.Create(r.Context(), userID, params)
	if errors.Is(err, service.ErrEmptyName) {
		shared.WriteError(w, http.StatusBadRequest, "tag_empty", "标签名不能为空。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "tag_failed", "暂时无法创建标签。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, dto)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	params, ok := decodeUpsert(w, r)
	if !ok {
		return
	}
	dto, err := h.service.Update(r.Context(), userID, id, params)
	if errors.Is(err, service.ErrEmptyName) {
		shared.WriteError(w, http.StatusBadRequest, "tag_empty", "标签名不能为空。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "tag_not_found", "没有找到这个标签。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	deleted, err := h.service.Delete(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "tag_failed", "暂时无法删除标签。")
		return
	}
	if !deleted {
		shared.WriteError(w, http.StatusNotFound, "tag_not_found", "没有找到这个标签。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

func decodeUpsert(w http.ResponseWriter, r *http.Request) (domain.UpsertParams, bool) {
	var req struct {
		Name  string `json:"name"`
		Color string `json:"color"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return domain.UpsertParams{}, false
	}
	return domain.UpsertParams{Name: req.Name, Color: req.Color}, true
}
