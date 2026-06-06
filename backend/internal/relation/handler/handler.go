package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/relation/domain"
	"xiguang/backend/internal/relation/service"
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
	r.Delete("/{id}", h.delete)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req struct {
		SourceFragmentID int64  `json:"source_fragment_id"`
		TargetFragmentID int64  `json:"target_fragment_id"`
		RelationType     string `json:"relation_type"`
		Note             string `json:"note"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	dto, err := h.service.Create(r.Context(), userID, domain.CreateParams{
		SourceFragmentID: req.SourceFragmentID,
		TargetFragmentID: req.TargetFragmentID,
		RelationType:     req.RelationType,
		Note:             req.Note,
	})
	if errors.Is(err, service.ErrInvalidRelation) {
		shared.WriteError(w, http.StatusBadRequest, "invalid_relation", "请选择两束不同的光，再给这条线一个关系。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "relation_failed", "暂时无法把它们织在一起。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, dto)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	fragmentID, _ := strconv.ParseInt(r.URL.Query().Get("fragment_id"), 10, 64)
	items, err := h.service.List(r.Context(), userID, fragmentID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "relation_failed", "暂时无法读取织线。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"relations": items})
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	deleted, err := h.service.Delete(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "relation_failed", "暂时无法解开这条线。")
		return
	}
	if !deleted {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这条线。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}
