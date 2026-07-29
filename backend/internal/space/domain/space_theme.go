package domain

type Config struct {
	Theme             string `json:"theme"`
	BreathingMotion   bool   `json:"breathing_motion"`
	WhiteNoiseEnabled bool   `json:"white_noise_enabled"`
}

type Theme struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	PrimaryColor string `json:"primary_color"`
	Description  string `json:"description"`
	RequiredTier string `json:"required_tier"`
	Locked       bool   `json:"locked"`
	Selected     bool   `json:"selected"`
}

const ThemeMorningMist = "morning_mist"

var Themes = []Theme{
	{ID: ThemeMorningMist, Name: "晨雾", PrimaryColor: "#72A58F", Description: "一层轻柔的微光。", RequiredTier: "glimmer"},
	{ID: "starry", Name: "静夜星点", PrimaryColor: "#61748F", Description: "把星点留在安静的深蓝里。", RequiredTier: "glimmer"},
	{ID: "ocean", Name: "潮声", PrimaryColor: "#7096A6", Description: "低缓的海面托住正在流动的光。", RequiredTier: "starlight"},
	{ID: "island", Name: "雾中小岛", PrimaryColor: "#8B9B78", Description: "让反复出现的主题慢慢靠岸。", RequiredTier: "starlight"},
}
