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

type BuildIslandsResponse struct {
	Status  string            `json:"status"`
	Message string            `json:"message"`
	Islands []AISuggestedIsland `json:"islands"`
}

type AISuggestedIsland struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	FragmentIDs []int64 `json:"fragment_ids"`
	Confidence  string  `json:"confidence"`
}

type PolishRequest struct {
	ContentText string `json:"content_text"`
	Emotion     string `json:"emotion"`
}

type PolishResponse struct {
	Status       string `json:"status"`
	Message      string `json:"message"`
	PolishedText string `json:"polished_text"`
}

type RequestLog struct {
	ID        int64     `json:"id"`
	Mode      string    `json:"mode"`
	Status    string    `json:"status"`
	Response  string    `json:"response"`
	CreatedAt time.Time `json:"created_at"`
}
