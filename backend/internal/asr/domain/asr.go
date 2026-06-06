package domain

type RecognizeRequest struct {
	AudioBase64 string `json:"audio_base64"`
	Format      string `json:"format"`
	SampleRate  int    `json:"sample_rate,omitempty"`
}

type RecognizeResponse struct {
	Text     string `json:"text"`
	Provider string `json:"provider"`
}
