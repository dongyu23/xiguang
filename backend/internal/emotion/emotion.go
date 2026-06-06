package emotion

import (
	"net/http"

	"xiguang/backend/internal/emotion/domain"
	"xiguang/backend/internal/emotion/handler"
)

type Emotion = domain.Emotion

func Routes() http.Handler {
	return handler.New().Routes()
}
