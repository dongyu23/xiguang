package domain

import "time"

type Island struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	Status        string    `json:"status"`
	FragmentCount int       `json:"fragment_count"`
	Description   string    `json:"description"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type UpsertParams struct {
	ID          int64
	Name        string
	Description string
}

type FragmentPreview struct {
	ID          int64     `json:"id"`
	PublicID    string    `json:"public_id"`
	ContentText string    `json:"content_text"`
	Emotion     string    `json:"emotion"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}
