package whitenoise

import (
	"net/http"

	"xiguang/backend/internal/whitenoise/handler"
)

func Routes(entitlements ...handler.EntitlementService) http.Handler {
	return handler.New(entitlements...).Routes()
}
