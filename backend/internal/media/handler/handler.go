package handler

import (
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/media/domain"
	"xiguang/backend/internal/media/service"
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
	r.Post("/upload", h.upload)
	r.Post("/presign-upload", h.presign)
	r.Post("/confirm-upload", h.confirm)
	r.Get("/{id}", h.get)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) upload(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	if err := r.ParseMultipartForm(50 << 20); err != nil { // 50MB max
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "文件太大了。")
		return
	}
	fragmentID, _ := strconv.ParseInt(r.FormValue("fragment_id"), 10, 64)
	file, header, err := r.FormFile("file")
	if err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请选择一个文件。")
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "media_failed", "无法读取文件。")
		return
	}

	result, err := h.service.Upload(r.Context(), userID, fragmentID, header.Filename, data)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "media_failed", "上传失败，请稍后再试。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, result)
}

func (h *Handler) presign(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req struct {
		FragmentID  int64  `json:"fragment_id"`
		FileName    string `json:"file_name"`
		ContentType string `json:"content_type"`
		FileSize    int64  `json:"file_size"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "文件信息不完整。")
		return
	}
	result, err := h.service.Presign(userID, domain.PresignRequest{
		FragmentID:  req.FragmentID,
		FileName:    req.FileName,
		ContentType: req.ContentType,
		FileSize:    req.FileSize,
	})
	if errors.Is(err, service.ErrInvalidPresign) {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "文件信息不完整。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "presign_failed", "暂时无法签发上传凭证。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) confirm(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req struct {
		FragmentID int64  `json:"fragment_id"`
		ObjectKey  string `json:"object_key"`
		FileName   string `json:"file_name"`
		MimeType   string `json:"mime_type"`
		FileSize   int64  `json:"file_size"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "确认上传的信息不完整。")
		return
	}
	result, err := h.service.Confirm(r.Context(), userID, domain.ConfirmRequest{
		FragmentID: req.FragmentID,
		ObjectKey:  req.ObjectKey,
		FileName:   req.FileName,
		MimeType:   req.MimeType,
		FileSize:   req.FileSize,
	})
	if errors.Is(err, service.ErrInvalidConfirm) {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "确认上传的信息不完整。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "media_failed", "暂时无法确认媒体文件。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, result)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	result, err := h.service.Get(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这个媒体文件。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	deleted, err := h.service.Delete(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "media_failed", "暂时无法删除媒体文件。")
		return
	}
	if !deleted {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这个媒体文件。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}
