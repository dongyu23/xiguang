package domain

import "time"

type Fragment struct {
	ID          int64     `json:"id"`
	PublicID    string    `json:"public_id"`
	UserID      int64     `json:"user_id"`
	ContentText string    `json:"content_text"`
	Emotion     string    `json:"emotion"`
	Status      string    `json:"status"`
	Tags        []string  `json:"tags"`
	MediaURLs   []string  `json:"media_urls"`
	IsDeleted   bool      `json:"is_deleted"`
	ServerRev   int64     `json:"server_rev"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type CreateParams struct {
	ContentText string
	Emotion     string
	Tags        []string
	MediaURLs   []string
	ClientOpID  string
}

type UpdateParams struct {
	ID          int64
	ContentText string
	Emotion     string
	Tags        []string
	MediaURLs   *[]string
}

type ListQuery struct {
	Emotion string
	Tag     string
	Limit   int
}

type TimelineGroup struct {
	Label     string     `json:"label"`
	Count     int        `json:"count"`
	Fragments []Fragment `json:"fragments"`
}

type TimelineResponse struct {
	Groups  []TimelineGroup `json:"groups"`
	Items   []Fragment      `json:"items"`
	HasMore bool            `json:"has_more"`
}
