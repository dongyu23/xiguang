package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	billingdomain "xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/stats/service"
)

type Handler struct {
	service      *service.Service
	entitlements EntitlementService
}

type EntitlementService interface {
	Entitlement(context.Context, int64) (billingdomain.Entitlement, error)
}

func New(service *service.Service, entitlements EntitlementService) *Handler {
	return &Handler{service: service, entitlements: entitlements}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/emotion-density", h.emotionDensity)
	r.Get("/freq-words", h.freqWords)
	r.Get("/tide", h.tide)
	return r
}

func (h *Handler) tide(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	entitlement, err := h.entitlements.Entitlement(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "stats_failed", "暂时无法确认潮汐提示权益。")
		return
	}
	if !billingdomain.TierAllows(entitlement.Tier, "starlight") {
		shared.WriteError(w, http.StatusForbidden, "entitlement_required", "潮汐提示需要星光会员。")
		return
	}
	result, err := h.service.Tide(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "stats_failed", "暂时无法读取潮汐提示。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, result)
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
