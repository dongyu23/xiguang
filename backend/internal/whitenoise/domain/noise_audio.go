package domain

type NoiseAudio struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Category     string `json:"category"`
	RequiredTier string `json:"required_tier"`
	Locked       bool   `json:"locked"`
}

var StaticList = []NoiseAudio{
	{ID: "rain", Name: "雨声", Category: "nature", RequiredTier: "glimmer"},
	{ID: "pages", Name: "翻书声", Category: "room", RequiredTier: "glimmer"},
	{ID: "wind", Name: "风声", Category: "nature", RequiredTier: "starlight"},
	{ID: "heartbeat", Name: "心跳声", Category: "body", RequiredTier: "starlight"},
}
