package domain

type PresignRequest struct {
	FragmentID  int64
	FileName    string
	ContentType string
	FileSize    int64
}

type PresignResponse struct {
	UploadURL           string `json:"upload_url"`
	ObjectKey           string `json:"object_key"`
	ExpiresInSeconds    int    `json:"expires_in_seconds"`
	DirectUploadEnabled bool   `json:"direct_upload_enabled"`
}

type ConfirmRequest struct {
	FragmentID int64
	ObjectKey  string
	FileName   string
	MimeType   string
	FileSize   int64
}

type MediaFile struct {
	ID        int64  `json:"id"`
	PublicID  string `json:"public_id,omitempty"`
	ObjectKey string `json:"object_key"`
	FileName  string `json:"file_name,omitempty"`
	MimeType  string `json:"mime_type,omitempty"`
	FileSize  int64  `json:"file_size,omitempty"`
	FileURL   string `json:"file_url"`
}
