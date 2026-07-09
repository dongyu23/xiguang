package middleware

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/shared"
)

// RequireAdmin 在 JWT 中间件之后使用，从数据库读取 users.is_admin 校验权限。
//
// 设计取舍：没有把 is_admin 放进 JWT claims——避免管理员被降权后旧 token 还能继续访问。
// 内部使用频率低，每次额外查一次 PG 可以接受。
func RequireAdmin(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, ok := UserID(r.Context())
			if !ok {
				shared.WriteError(w, http.StatusUnauthorized, "auth.unauthorized", "请先登录后再继续。")
				return
			}
			var isAdmin bool
			err := pool.QueryRow(r.Context(),
				`SELECT COALESCE(is_admin, FALSE) FROM users WHERE id=$1 AND deleted_at IS NULL`,
				userID,
			).Scan(&isAdmin)
			if err != nil || !isAdmin {
				shared.WriteError(w, http.StatusForbidden, "auth.forbidden", "需要管理员权限。")
				return
			}
			ctx := context.WithValue(r.Context(), adminUserKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

const adminUserKey contextKey = "admin_user_id"

// AdminUserID 取出经过 RequireAdmin 校验后的用户 ID，便于审计日志。
func AdminUserID(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(adminUserKey).(int64)
	return id, ok
}
