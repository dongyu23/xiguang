package domain

import "time"

type AIScope struct {
	Type        string  `json:"type"`
	FragmentIDs []int64 `json:"fragment_ids,omitempty"`
	IslandID    int64   `json:"island_id,omitempty"`
	RangeDays   int     `json:"range_days,omitempty"`
}

type AISourceReference struct {
	FragmentID int64     `json:"fragment_id"`
	Excerpt    string    `json:"excerpt"`
	Emotion    string    `json:"emotion,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

type AISummaryPoint struct {
	Text              string  `json:"text"`
	SourceFragmentIDs []int64 `json:"source_fragment_ids"`
}

type SummaryPreviewRequest struct {
	Scope AIScope `json:"scope"`
}

type AISummaryDraft struct {
	Status          string              `json:"status"`
	Message         string              `json:"message,omitempty"`
	RequestID       int64               `json:"request_id,omitempty"`
	Scope           AIScope             `json:"scope"`
	SourceCount     int                 `json:"source_count"`
	Sources         []AISourceReference `json:"sources"`
	Summary         string              `json:"summary"`
	KeyPoints       []AISummaryPoint    `json:"key_points"`
	TitleCandidates []string            `json:"title_candidates"`
	Why             string              `json:"why"`
}

type SummarySaveRequest struct {
	RequestID  int64            `json:"request_id"`
	Scope      AIScope          `json:"scope"`
	Title      string           `json:"title"`
	Summary    string           `json:"summary"`
	KeyPoints  []AISummaryPoint `json:"key_points"`
	UserEdited bool             `json:"user_edited"`
}

type AIArtifact struct {
	ID         int64            `json:"id"`
	PublicID   string           `json:"public_id"`
	Scope      AIScope          `json:"scope"`
	Title      string           `json:"title"`
	Summary    string           `json:"summary"`
	KeyPoints  []AISummaryPoint `json:"key_points"`
	UserEdited bool             `json:"user_edited"`
	CreatedAt  time.Time        `json:"created_at"`
	UpdatedAt  time.Time        `json:"updated_at"`
}

type PolishRequest struct {
	ContentText string   `json:"content_text"`
	Emotion     string   `json:"emotion"`
	Tags        []string `json:"tags,omitempty"`
}

type AIPolishDraft struct {
	Status       string `json:"status"`
	Message      string `json:"message"`
	RequestID    int64  `json:"request_id,omitempty"`
	OriginalText string `json:"original_text"`
	PolishedText string `json:"polished_text"`
	Why          string `json:"why,omitempty"`
}

type AIIslandGroupProposal struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	IslandIDs   []int64 `json:"island_ids"`
	Confidence  string  `json:"confidence"`
	Preselected bool    `json:"preselected"`
	Why         string  `json:"why"`
}

type IslandGroupPreviewResponse struct {
	Status    string                  `json:"status"`
	Message   string                  `json:"message,omitempty"`
	RequestID int64                   `json:"request_id,omitempty"`
	Proposals []AIIslandGroupProposal `json:"proposals"`
}

type FeedbackRequest struct {
	RequestID int64  `json:"request_id"`
	Action    string `json:"action"`
	Reason    string `json:"reason,omitempty"`
}

type RequestLog struct {
	ID           int64     `json:"id"`
	RequestType  string    `json:"request_type"`
	Status       string    `json:"status"`
	Model        string    `json:"model,omitempty"`
	LatencyMS    int       `json:"latency_ms,omitempty"`
	TokenUsed    int       `json:"token_used,omitempty"`
	ContentCount int       `json:"content_count"`
	ErrorCode    string    `json:"error_code,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

// Compatibility contracts kept for one client version.
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
type AISuggestedIsland struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	FragmentIDs []int64 `json:"fragment_ids"`
	Confidence  string  `json:"confidence"`
}
type BuildIslandsResponse struct {
	Status  string              `json:"status"`
	Message string              `json:"message"`
	Islands []AISuggestedIsland `json:"islands"`
}
type PolishResponse = AIPolishDraft
