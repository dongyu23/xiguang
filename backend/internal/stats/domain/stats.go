package domain

import "time"

type EmotionCount struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

type EmotionDensity struct {
	Period      string         `json:"period"`
	Total       int            `json:"total"`
	Emotions    []EmotionCount `json:"emotions"`
	GeneratedAt time.Time      `json:"generated_at"`
}

type FreqWord struct {
	Text  string `json:"text"`
	Count int    `json:"count"`
}

type FreqWords struct {
	Words []FreqWord `json:"words"`
}

type TideInsight struct {
	Period      string    `json:"period"`
	Title       string    `json:"title"`
	Message     string    `json:"message"`
	Emotion     string    `json:"emotion,omitempty"`
	Occurrences int       `json:"occurrences"`
	GeneratedAt time.Time `json:"generated_at"`
}
