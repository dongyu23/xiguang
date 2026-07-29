package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/ai/domain"
	"xiguang/backend/internal/ai/service"
	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/shared"
)

type Handler struct{ service *service.Service }

func New(s *service.Service) *Handler { return &Handler{service: s} }

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Post("/summaries/preview", h.summaryPreview)
	r.Post("/summaries", h.summarySave)
	r.Put("/summaries/{id}", h.summaryUpdate)
	r.Delete("/summaries/{id}", h.summaryDelete)
	r.Post("/island-groups/preview", h.islandGroupsPreview)
	r.Post("/polish/preview", h.polishPreview)
	r.Post("/feedback", h.feedback)
	r.Get("/requests", h.requests)
	// One-version compatibility surface.
	r.Post("/glow-summary", h.glowSummary)
	r.Post("/build-islands", h.buildIslands)
	r.Post("/polish", h.polishPreview)
	return r
}
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) { h.Routes().ServeHTTP(w, r) }

func (h *Handler) summaryPreview(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	var req domain.SummaryPreviewRequest
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	result := h.service.PreviewSummary(r.Context(), uid, req)
	shared.WriteJSON(w, statusFor(result.Status), result)
}
func (h *Handler) summarySave(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	var req domain.SummarySaveRequest
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	item, err := h.service.SaveSummary(r.Context(), uid, req)
	if err != nil {
		shared.WriteError(w, 400, "invalid_ai_draft", "这段整理未通过来源校验。")
		return
	}
	shared.WriteJSON(w, 201, item)
}
func (h *Handler) summaryUpdate(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	var req domain.SummarySaveRequest
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	item, err := h.service.UpdateSummary(r.Context(), uid, id, req)
	if err != nil {
		shared.WriteError(w, 404, "summary_not_found", "没有找到这段星图注释。")
		return
	}
	shared.WriteJSON(w, 200, item)
}
func (h *Handler) summaryDelete(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	ok, err := h.service.DeleteSummary(r.Context(), uid, id)
	if err != nil || !ok {
		shared.WriteError(w, 404, "summary_not_found", "没有找到这段星图注释。")
		return
	}
	shared.WriteJSON(w, 200, map[string]bool{"deleted": true})
}
func (h *Handler) islandGroupsPreview(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	result := h.service.PreviewIslandGroups(r.Context(), uid)
	shared.WriteJSON(w, statusFor(result.Status), result)
}
func (h *Handler) polishPreview(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	var req domain.PolishRequest
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	result := h.service.PreviewPolish(r.Context(), uid, req)
	shared.WriteJSON(w, statusFor(result.Status), result)
}
func (h *Handler) feedback(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	var req domain.FeedbackRequest
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	if err := h.service.Feedback(r.Context(), uid, req); err != nil {
		shared.WriteError(w, 500, "ai_feedback_failed", "暂时无法记录反馈。")
		return
	}
	shared.WriteJSON(w, 202, map[string]bool{"accepted": true})
}
func (h *Handler) requests(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	items, err := h.service.Requests(r.Context(), uid)
	if err != nil {
		shared.WriteError(w, 500, "ai_failed", "暂时无法读取整理记录。")
		return
	}
	shared.WriteJSON(w, 200, items)
}

func (h *Handler) glowSummary(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	var req domain.GlowSummaryRequest
	_ = shared.DecodeJSON(r, &req)
	result := h.service.GlowSummary(r.Context(), uid, req)
	shared.WriteJSON(w, statusFor(result.Status), result)
}
func (h *Handler) buildIslands(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	var req struct {
		RangeDays int `json:"range_days"`
	}
	_ = shared.DecodeJSON(r, &req)
	shared.WriteJSON(w, 200, h.service.BuildIslands(r.Context(), uid, req.RangeDays))
}

func statusFor(status string) int {
	switch status {
	case "membership_required":
		return http.StatusForbidden
	case "quota_exhausted", "rate_limited":
		return http.StatusTooManyRequests
	case "invalid_scope", "not_enough", "parse_error":
		return http.StatusUnprocessableEntity
	case "error":
		return http.StatusServiceUnavailable
	}
	return http.StatusOK
}
