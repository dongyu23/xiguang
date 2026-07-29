package handler

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/billing/repository"
	"xiguang/backend/internal/billing/service"
	"xiguang/backend/internal/shared"
)

type Handler struct{ service *service.Service }

func New(service *service.Service) *Handler { return &Handler{service: service} }

func (h *Handler) PrivateRoutes() http.Handler {
	r := chi.NewRouter()
	r.Get("/catalog", h.catalog)
	r.Get("/me", h.me)
	r.Get("/orders/{id}", h.order)
	r.Post("/subscriptions", h.create)
	r.Post("/subscriptions/{id}/cancel", h.cancel)
	r.Post("/apple/verify", h.appleVerify)
	r.Post("/apple/restore", h.appleRestore)
	return r
}
func (h *Handler) PublicRoutes() http.Handler {
	r := chi.NewRouter()
	r.Post("/apple", h.appleWebhook)
	r.Post("/wechat", h.wechatWebhook)
	r.Post("/alipay", h.alipayWebhook)
	return r
}

func (h *Handler) catalog(w http.ResponseWriter, r *http.Request) {
	items, err := h.service.Catalog(r.Context(), r.URL.Query().Get("provider"))
	if err != nil {
		serverError(w)
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
}
func (h *Handler) me(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	item, err := h.service.Entitlement(r.Context(), userID)
	if err != nil {
		serverError(w)
		return
	}
	shared.WriteJSON(w, http.StatusOK, item)
}
func (h *Handler) order(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	item, err := h.service.Order(r.Context(), userID, chi.URLParam(r, "id"))
	if errors.Is(err, repository.ErrNotFound) {
		shared.WriteError(w, http.StatusNotFound, "order_not_found", "没有找到这笔订单。")
		return
	}
	if err != nil {
		serverError(w)
		return
	}
	shared.WriteJSON(w, http.StatusOK, item)
}
func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req domain.CreateSubscriptionRequest
	if shared.DecodeJSON(r, &req) != nil {
		badRequest(w)
		return
	}
	item, err := h.service.CreateSubscription(r.Context(), userID, req)
	if writeServiceError(w, err) {
		return
	}
	shared.WriteJSON(w, http.StatusCreated, item)
}
func (h *Handler) cancel(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	ok, err := h.service.Cancel(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		serverError(w)
		return
	}
	if !ok {
		shared.WriteError(w, http.StatusNotFound, "subscription_not_found", "没有找到有效订阅。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"cancel_at_period_end": true})
}
func (h *Handler) appleVerify(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req struct {
		SignedTransaction string `json:"signed_transaction"`
	}
	if shared.DecodeJSON(r, &req) != nil || req.SignedTransaction == "" {
		badRequest(w)
		return
	}
	item, err := h.service.VerifyApple(r.Context(), userID, req.SignedTransaction)
	if writeServiceError(w, err) {
		return
	}
	shared.WriteJSON(w, http.StatusOK, item)
}
func (h *Handler) appleRestore(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req struct {
		SignedTransactions []string `json:"signed_transactions"`
	}
	if shared.DecodeJSON(r, &req) != nil {
		badRequest(w)
		return
	}
	item, err := h.service.RestoreApple(r.Context(), userID, req.SignedTransactions)
	if writeServiceError(w, err) {
		return
	}
	shared.WriteJSON(w, http.StatusOK, item)
}
func (h *Handler) appleWebhook(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
	if err != nil {
		badRequest(w)
		return
	}
	var req struct {
		SignedPayload string `json:"signedPayload"`
	}
	if json.Unmarshal(body, &req) != nil || req.SignedPayload == "" {
		badRequest(w)
		return
	}
	_, err = h.service.ProcessAppleNotification(r.Context(), req.SignedPayload)
	if err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid_notification", "通知验证失败。")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
func (h *Handler) unavailableWebhook(w http.ResponseWriter, r *http.Request) {
	shared.WriteError(w, http.StatusServiceUnavailable, "channel_not_ready", "该自动续费渠道尚未完成商户计划核验。")
}
func (h *Handler) wechatWebhook(w http.ResponseWriter, r *http.Request) {
	if _, err := h.service.ProcessWeChatNotification(r.Context(), r); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid_notification", "微信支付通知验证失败。")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
func (h *Handler) alipayWebhook(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	if err := r.ParseForm(); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("failure"))
		return
	}
	if _, err := h.service.ProcessAlipayNotification(r.Context(), r.PostForm); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("failure"))
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("success"))
}
func badRequest(w http.ResponseWriter) {
	shared.WriteError(w, http.StatusBadRequest, "bad_request", "支付请求格式不正确。")
}
func serverError(w http.ResponseWriter) {
	shared.WriteError(w, http.StatusInternalServerError, "billing_failed", "支付服务暂时不可用。")
}
func writeServiceError(w http.ResponseWriter, err error) bool {
	if err == nil {
		return false
	}
	switch {
	case errors.Is(err, service.ErrDisabled):
		shared.WriteError(w, http.StatusServiceUnavailable, "payments_disabled", "支付功能尚未开放。")
	case errors.Is(err, service.ErrChannelUnavailable):
		shared.WriteError(w, http.StatusServiceUnavailable, "channel_not_ready", "支付渠道尚未完成核验。")
	case errors.Is(err, service.ErrInvalidAppleTransaction):
		shared.WriteError(w, http.StatusBadRequest, "invalid_transaction", "Apple 交易验证失败。")
	case errors.Is(err, repository.ErrActiveSubscription):
		shared.WriteError(w, http.StatusConflict, "active_subscription_exists", "当前账号已有有效订阅，请先管理现有订阅。")
	case errors.Is(err, repository.ErrNotFound), errors.Is(err, service.ErrBadRequest):
		badRequest(w)
	default:
		if strings.Contains(err.Error(), "duplicate") {
			shared.WriteError(w, http.StatusConflict, "billing_conflict", "支付状态正在更新，请稍后刷新。")
		} else {
			serverError(w)
		}
	}
	return true
}
