package middleware

import (
	"context"
	"net/http"
	"strings"

	"xiguang/backend/internal/shared"
)

type contextKey string

const userIDKey contextKey = "user_id"
const sessionIDKey contextKey = "session_id"

type TokenParser interface {
	ParseToken(token string) (int64, error)
}

type sessionTokenParser interface {
	ParseTokenSession(token string) (int64, int64, error)
}

func RequireAuth(parser TokenParser) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := bearerToken(r)
			if token == "" {
				shared.WriteError(w, http.StatusUnauthorized, "unauthorized", "请先登录后再继续。")
				return
			}
			var userID, sessionID int64
			var err error
			if sessionParser, ok := parser.(sessionTokenParser); ok {
				userID, sessionID, err = sessionParser.ParseTokenSession(token)
			} else {
				userID, err = parser.ParseToken(token)
			}
			if err != nil {
				shared.WriteError(w, http.StatusUnauthorized, "unauthorized", "登录状态已过期，请重新登录。")
				return
			}
			ctx := context.WithValue(r.Context(), userIDKey, userID)
			ctx = context.WithValue(ctx, sessionIDKey, sessionID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func bearerToken(r *http.Request) string {
	header := r.Header.Get("Authorization")
	if strings.HasPrefix(header, "Bearer ") {
		return strings.TrimPrefix(header, "Bearer ")
	}
	return r.URL.Query().Get("access_token")
}

func UserID(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(userIDKey).(int64)
	return id, ok
}

func SessionID(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(sessionIDKey).(int64)
	return id, ok && id > 0
}
