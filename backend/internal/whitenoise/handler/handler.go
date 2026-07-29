package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	billingdomain "xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/shared"
	"xiguang/backend/internal/whitenoise/service"
)

type Handler struct {
	service      *service.Service
	entitlements EntitlementService
}

type EntitlementService interface {
	Entitlement(context.Context, int64) (billingdomain.Entitlement, error)
}

func New(entitlements ...EntitlementService) *Handler {
	var e EntitlementService
	if len(entitlements) > 0 {
		e = entitlements[0]
	}
	return &Handler{service: service.New(), entitlements: e}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	return r
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	tier := "glimmer"
	if h.entitlements != nil {
		userID, _ := auth.UserID(r.Context())
		if e, err := h.entitlements.Entitlement(r.Context(), userID); err == nil {
			tier = e.Tier
		}
	}
	shared.WriteJSON(w, http.StatusOK, h.service.List(tier))
}
