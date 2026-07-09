package handler

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"xiguang/backend/internal/auth/domain"
	authmw "xiguang/backend/internal/auth/middleware"
	"xiguang/backend/internal/auth/service"
	"xiguang/backend/internal/shared"
)

type Handler struct {
	service      *service.Service
	metaProvider MetaProvider
}

// MetaProvider 允许其他模块（如 app_release）往 /users/me 等响应里
// piggyback 一段 meta，避免引入循环依赖。
type MetaProvider func(r *http.Request) any

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

// SetMetaProvider 注入 meta 提供器。传 nil 表示不附加 meta。
func (h *Handler) SetMetaProvider(p MetaProvider) {
	h.metaProvider = p
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Post("/register", h.register)
	r.Post("/login", h.login)
	r.Post("/refresh", h.refresh)
	r.Group(func(r chi.Router) {
		r.Use(h.Middleware)
		r.Put("/password", h.changePassword)
	})
	return r
}

func (h *Handler) UserRoutes() http.Handler {
	r := chi.NewRouter()
	r.Use(h.Middleware)
	r.Get("/me", h.me)
	r.Put("/me", h.updateMe)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) Middleware(next http.Handler) http.Handler {
	return authmw.RequireAuth(h.service)(next)
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
		Nickname string `json:"nickname"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	user, tokens, err := h.service.Register(r.Context(), domain.RegisterParams{Username: req.Username, Password: req.Password, Nickname: req.Nickname})
	if errors.Is(err, service.ErrInvalidAccount) {
		shared.WriteError(w, http.StatusBadRequest, "invalid_account", "用户名不能为空，密码至少 6 位。")
		return
	}
	if isPGUniqueViolation(err) {
		shared.WriteError(w, http.StatusConflict, "username_taken", "这个用户名已经被使用。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "register_failed", "暂时无法注册，请稍后再试。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, map[string]any{"user": user, "tokens": tokens})
}

func (h *Handler) login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	user, tokens, err := h.service.Login(r.Context(), domain.LoginParams{Username: req.Username, Password: req.Password})
	if errors.Is(err, service.ErrLoginFailed) {
		shared.WriteError(w, http.StatusUnauthorized, "login_failed", "用户名或密码不正确。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "login_failed", "暂时无法登录。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"user": user, "tokens": tokens})
}

func (h *Handler) me(w http.ResponseWriter, r *http.Request) {
	id, _ := authmw.UserID(r.Context())
	user, err := h.service.Me(r.Context(), id)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这个账号。")
		return
	}
	shared.WriteJSONWithMeta(w, http.StatusOK, user, h.meta(r))
}

func (h *Handler) updateMe(w http.ResponseWriter, r *http.Request) {
	id, _ := authmw.UserID(r.Context())
	var req struct {
		Nickname    string `json:"nickname"`
		AvatarKey   string `json:"avatar_key"`
		AIEnabled   *bool  `json:"ai_enabled"`
		PrivacyMode string `json:"privacy_mode"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	user, err := h.service.UpdateMe(r.Context(), id, domain.UpdateUserParams{
		Nickname:    req.Nickname,
		AvatarKey:   req.AvatarKey,
		AIEnabled:   req.AIEnabled,
		PrivacyMode: req.PrivacyMode,
	})
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "not_found", "没有找到这个账号。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, user)
}

func (h *Handler) refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil || req.RefreshToken == "" {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "刷新令牌不能为空。")
		return
	}
	tokens, err := h.service.Refresh(r.Context(), req.RefreshToken)
	if errors.Is(err, service.ErrRefreshFailed) || errors.Is(err, pgx.ErrNoRows) {
		shared.WriteError(w, http.StatusUnauthorized, "refresh_failed", "登录状态已过期。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "token_failed", "暂时无法刷新登录状态。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, tokens)
}

func (h *Handler) changePassword(w http.ResponseWriter, r *http.Request) {
	id, _ := authmw.UserID(r.Context())
	var req struct {
		OldPassword string `json:"old_password"`
		NewPassword string `json:"new_password"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}
	if req.OldPassword == "" || req.NewPassword == "" {
		shared.WriteError(w, http.StatusBadRequest, "missing_field", "当前密码和新密码不能为空。")
		return
	}
	err := h.service.ChangePassword(r.Context(), id, req.OldPassword, req.NewPassword)
	if errors.Is(err, service.ErrWrongPassword) {
		shared.WriteError(w, http.StatusBadRequest, "wrong_password", "当前密码不正确。")
		return
	}
	if errors.Is(err, service.ErrPasswordTooShort) {
		shared.WriteError(w, http.StatusBadRequest, "password_too_short", "新密码至少需要 6 个字符。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "change_password_failed", "暂时无法修改密码，请稍后再试。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "密码已修改。"})
}

func isPGUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func (h *Handler) meta(r *http.Request) any {
	if h.metaProvider == nil {
		return nil
	}
	return h.metaProvider(r)
}
