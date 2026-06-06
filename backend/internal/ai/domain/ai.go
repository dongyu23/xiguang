package domain

import "time"

type GlowSummaryRequest struct {
	Mode        string  `json:"mode"`
	FragmentIDs []int64 `json:"fragment_ids"`
	Context     string  `json:"context"`
}

type GlowSummaryResponse struct {
	Status        string   `json:"status"`
	Message       string   `json:"message"`
	Keywords      []string `json:"keywords"`
	SuggestionIDs []int64  `json:"suggestion_ids"`
}

type RequestLog struct {
	ID        int64     `json:"id"`
	Mode      string    `json:"mode"`
	Status    string    `json:"status"`
	Response  string    `json:"response"`
	CreatedAt time.Time `json:"created_at"`
}
