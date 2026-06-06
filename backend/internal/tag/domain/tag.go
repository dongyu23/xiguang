package domain

import "time"

type Tag struct {
	ID        int64     `json:"id"`
	PublicID  string    `json:"public_id"`
	Name      string    `json:"name"`
	Color     string    `json:"color"`
	UseCount  int       `json:"use_count"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type UpsertParams struct {
	Name  string
	Color string
}

type Page struct {
	Items      []Tag `json:"items"`
	Page       int   `json:"page"`
	PageSize   int   `json:"page_size"`
	Total      int   `json:"total"`
	TotalPages int   `json:"total_pages"`
}
