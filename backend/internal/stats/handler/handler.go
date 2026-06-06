package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/stats/service"
)

type Handler struct {
	service *service.Service
}

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/emotion-density", h.emotionDensity)
	r.Get("/freq-words", h.freqWords)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) emotionDensity(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	result, err := h.service.EmotionDensity(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "stats_failed", "暂时无法读取情绪密度。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, result)
}

func (h *Handler) freqWords(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	result, err := h.service.FreqWords(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "stats_failed", "暂时无法读取高频主题。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, result)
}
