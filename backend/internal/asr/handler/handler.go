package handler

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"nhooyr.io/websocket"

	"xiguang/backend/internal/asr/domain"
	"xiguang/backend/internal/asr/provider"
	"xiguang/backend/internal/asr/service"
	"xiguang/backend/internal/shared"
)

type Handler struct {
	service  *service.Service
	realtime *provider.RealtimeProxy
}

func New(service *service.Service, realtime *provider.RealtimeProxy) *Handler {
	return &Handler{service: service, realtime: realtime}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Post("/recognize", h.recognize)
	r.Get("/realtime", h.realtimeRecognize)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) recognize(w http.ResponseWriter, r *http.Request) {
	var req domain.RecognizeRequest
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "语音文件信息不完整。")
		return
	}
	result, err := h.service.Recognize(r.Context(), req)
	if errors.Is(err, service.ErrInvalidAudio) {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "语音格式不支持，或文件超过 3MB。")
		return
	}
	if errors.Is(err, service.ErrUnsupported) || errors.Is(err, provider.ErrNotConfigured) {
		shared.WriteError(w, http.StatusServiceUnavailable, "asr_not_configured", "语音识别服务还没有配置完成。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusBadGateway, "asr_failed", "语音识别暂时不可用，请稍后再试。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) realtimeRecognize(w http.ResponseWriter, r *http.Request) {
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		InsecureSkipVerify: true,
	})
	if err != nil {
		return
	}
	if h.realtime == nil {
		_ = conn.Close(websocket.StatusInternalError, "asr_not_configured")
		return
	}
	if err := h.realtime.Serve(r.Context(), conn); err != nil &&
		!errors.Is(err, provider.ErrNotConfigured) {
		slog.Warn("realtime asr failed", "error", err)
	}
}
