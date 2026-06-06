package domain

type NoiseAudio struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Category string `json:"category"`
}

var StaticList = []NoiseAudio{
	{ID: "rain", Name: "雨声", Category: "nature"},
	{ID: "pages", Name: "翻书声", Category: "room"},
	{ID: "wind", Name: "风声", Category: "nature"},
	{ID: "heartbeat", Name: "心跳声", Category: "body"},
}
