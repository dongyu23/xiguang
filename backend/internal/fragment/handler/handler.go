package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/fragment/domain"
	"xiguang/backend/internal/fragment/service"
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
	r.Post("/", h.create)
	r.Get("/", h.list)
	r.Get("/search", h.search)
	r.Get("/trash", h.trash)
	r.Get("/{id}", h.get)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	r.Post("/{id}/restore", h.restore)
	r.Delete("/{id}/permanent", h.deletePermanently)
	r.Post("/{id}/weave", h.weave)
	return r
}

func (h *Handler) TimelineRoutes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.timeline)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req struct {
		ContentText string   `json:"content_text"`
		Emotion     string   `json:"emotion"`
		Tags        []string `json:"tag_names"`
		MediaURLs   []string `json:"media_urls"`
		ClientOpID  string   `json:"client_op_id"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	dto, err := h.service.Create(r.Context(), userID, domain.CreateParams{
		ContentText: req.ContentText,
		Emotion:     req.Emotion,
		Tags:        req.Tags,
		MediaURLs:   req.MediaURLs,
		ClientOpID:  req.ClientOpID,
	})
	if errors.Is(err, service.ErrEmptyLight) {
		shared.WriteError(w, http.StatusBadRequest, "empty_light", "至少留下一句话或一张图片。")
		return
	}
	if errors.Is(err, service.ErrInvalidMedia) {
		shared.WriteError(w, http.StatusBadRequest, "invalid_media", "图片需要先完成上传，再放进这束光。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "create_failed", "暂时无法保存这束光。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, dto)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	items, err := h.service.List(r.Context(), userID, r.URL.Query().Get("emotion"), r.URL.Query().Get("tag"), r.URL.Query().Get("limit"))
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "list_failed", "暂时无法读取光片。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) search(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	items, err := h.service.Search(r.Context(), userID, r.URL.Query().Get("q"), r.URL.Query().Get("limit"))
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "search_failed", "暂时无法查找旧光。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) trash(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	items, err := h.service.ListDeleted(r.Context(), userID, r.URL.Query().Get("limit"))
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "trash_failed", "暂时无法打开回收站。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, items)
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

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	dto, err := h.service.Get(r.Context(), userID, id)
	if errors.Is(err, pgx.ErrNoRows) {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这束光。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "read_failed", "暂时无法读取这束光。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	var req struct {
		ContentText string    `json:"content_text"`
		Emotion     string    `json:"emotion"`
		Tags        []string  `json:"tag_names"`
		MediaURLs   *[]string `json:"media_urls"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	dto, err := h.service.Update(r.Context(), userID, domain.UpdateParams{
		ID:          id,
		ContentText: req.ContentText,
		Emotion:     req.Emotion,
		Tags:        req.Tags,
		MediaURLs:   req.MediaURLs,
	})
	if errors.Is(err, service.ErrEmptyLight) {
		shared.WriteError(w, http.StatusBadRequest, "empty_light", "文字内容不能为空。")
		return
	}
	if errors.Is(err, service.ErrInvalidMedia) {
		shared.WriteError(w, http.StatusBadRequest, "invalid_media", "图片需要先完成上传，再放进这束光。")
		return
	}
	if errors.Is(err, pgx.ErrNoRows) {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这束光。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "update_failed", "暂时无法更新这束光。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	deleted, err := h.service.Delete(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "delete_failed", "暂时无法删除这束光。")
		return
	}
	if !deleted {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这束光。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

func (h *Handler) restore(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	restored, err := h.service.Restore(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "restore_failed", "暂时无法恢复这束光。")
		return
	}
	if !restored {
		shared.WriteError(w, http.StatusNotFound, "not_found", "回收站里没有找到这束光。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"restored": true})
}

func (h *Handler) deletePermanently(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	deleted, err := h.service.DeletePermanently(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "delete_failed", "暂时无法彻底删除这束光。")
		return
	}
	if !deleted {
		shared.WriteError(w, http.StatusNotFound, "not_found", "回收站里没有找到这束光。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

func (h *Handler) weave(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	sourceID, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	var req struct {
		TargetFragmentID int64  `json:"target_fragment_id"`
		RelationType     string `json:"relation_type"`
		Note             string `json:"note"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	dto, err := h.service.Weave(r.Context(), userID, sourceID, req.TargetFragmentID, req.RelationType, req.Note)
	if err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid_relation", "暂时无法把它们织在一起。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, dto)
}
