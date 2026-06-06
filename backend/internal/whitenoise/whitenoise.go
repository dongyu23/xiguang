package whitenoise

import (
	"net/http"

	"xiguang/backend/internal/whitenoise/handler"
)

func Routes() http.Handler {
	return handler.New().Routes()
}
