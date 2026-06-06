package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/island/domain"
	"xiguang/backend/internal/island/service"
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
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{id}", h.get)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	r.Get("/{name}/fragments", h.fragments)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	items, err := h.service.List(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法读取小宇宙。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"islands": items})
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	params, ok := decodeUpsert(w, r)
	if !ok {
		return
	}
	dto, err := h.service.Create(r.Context(), userID, params)
	if errors.Is(err, service.ErrEmptyName) {
		shared.WriteError(w, http.StatusBadRequest, "island_empty", "小岛名称不能为空。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法创建小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, dto)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	dto, err := h.service.Get(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "island_not_found", "没有找到这座小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
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
		shared.WriteError(w, http.StatusBadRequest, "island_empty", "小岛名称不能为空。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "island_not_found", "没有找到这座小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	deleted, err := h.service.Delete(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法删除小岛。")
		return
	}
	if !deleted {
		shared.WriteError(w, http.StatusNotFound, "island_not_found", "没有找到这座小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

func (h *Handler) fragments(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	name := chi.URLParam(r, "name")
	items, err := h.service.Fragments(r.Context(), userID, name, r.URL.Query().Get("limit"))
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法读取岛内光片。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"name": name, "fragments": items})
}

func decodeUpsert(w http.ResponseWriter, r *http.Request) (domain.UpsertParams, bool) {
	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return domain.UpsertParams{}, false
	}
	return domain.UpsertParams{Name: req.Name, Description: req.Description}, true
}
