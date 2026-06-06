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
