package space

import (
	"net/http"

	"xiguang/backend/internal/space/handler"
)

func Routes() http.Handler {
	return handler.New().Routes()
}
