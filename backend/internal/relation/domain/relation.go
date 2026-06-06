package domain

import "time"

type Relation struct {
	ID               int64     `json:"id"`
	PublicID         string    `json:"public_id"`
	UserID           int64     `json:"user_id"`
	SourceFragmentID int64     `json:"source_fragment_id"`
	TargetFragmentID int64     `json:"target_fragment_id"`
	RelationType     string    `json:"relation_type"`
	Note             string    `json:"note"`
	CreatedAt        time.Time `json:"created_at"`
}

type CreateParams struct {
	SourceFragmentID int64
	TargetFragmentID int64
	RelationType     string
	Note             string
}
