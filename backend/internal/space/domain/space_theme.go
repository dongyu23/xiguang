package domain

type Config struct {
	Theme             string `json:"theme"`
	BreathingMotion   bool   `json:"breathing_motion"`
	WhiteNoiseEnabled bool   `json:"white_noise_enabled"`
}

const ThemeStarry = "starry"
