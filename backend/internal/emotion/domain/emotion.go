package domain

type Emotion struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	ColorHex    string `json:"color_hex"`
	Description string `json:"description"`
}

var StaticList = []Emotion{
	{ID: "calm", Name: "平静", ColorHex: "#9CB7AD", Description: "像雾慢慢落下来。"},
	{ID: "happy", Name: "开心", ColorHex: "#E6BE8A", Description: "轻一点亮起来。"},
	{ID: "tired", Name: "疲惫", ColorHex: "#A8A1B8", Description: "先放下也可以。"},
	{ID: "anxious", Name: "焦虑", ColorHex: "#C58F8D", Description: "有一点乱，也被允许。"},
	{ID: "lost", Name: "失落", ColorHex: "#8EA4BF", Description: "像低低的天色。"},
	{ID: "touched", Name: "被击中", ColorHex: "#D8A48F", Description: "某个瞬间突然靠近。"},
	{ID: "messy", Name: "混乱", ColorHex: "#B7A58E", Description: "还没有名字的一团光。"},
	{ID: "unknown", Name: "说不清", ColorHex: "#B9B9A8", Description: "不解释也可以。"},
}
