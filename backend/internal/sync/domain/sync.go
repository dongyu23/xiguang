package domain

import "time"

type PushRequest struct {
	DeviceID   string          `json:"device_id"`
	Operations []PushOperation `json:"operations"`
}

type PushOperation struct {
	ClientOpID     string         `json:"client_op_id"`
	EntityType     string         `json:"entity_type"`
	OpType         string         `json:"op_type"`
	EntityPublicID string         `json:"entity_public_id"`
	Payload        map[string]any `json:"payload"`
	ClientSeq      int64          `json:"client_seq"`
	BaseServerRev  int64          `json:"base_server_version"`
}

type PushResult struct {
	ClientOpID string `json:"client_op_id"`
	Status     string `json:"status"`
	ServerRev  int64  `json:"server_rev,omitempty"`
}

type PushResponse struct {
	Results      []PushResult `json:"results"`
	NewServerRev int64        `json:"new_server_rev"`
}

type PullOperation struct {
	ServerRev      int64          `json:"server_rev"`
	ClientOpID     string         `json:"client_op_id"`
	EntityType     string         `json:"entity_type"`
	OpType         string         `json:"op_type"`
	EntityPublicID string         `json:"entity_public_id"`
	Payload        map[string]any `json:"payload"`
	ClientSeq      int64          `json:"client_seq"`
	DeviceID       string         `json:"device_id"`
	CreatedAt      time.Time      `json:"created_at"`
}

type PullResponse struct {
	Operations       []PullOperation `json:"operations"`
	NextSinceRev     int64           `json:"next_since_rev"`
	HasMore          bool            `json:"has_more"`
	FullSyncRequired bool            `json:"full_sync_required"`
}

type SyncStatus struct {
	ServerRev int64 `json:"server_rev"`
	Connected bool  `json:"connected"`
}
