package space

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRoutesReadAndUpdateSpaceConfig(t *testing.T) {
	for _, tc := range []struct {
		name   string
		method string
		body   string
	}{
		{name: "read", method: http.MethodGet},
		{name: "update", method: http.MethodPut, body: `{"theme":"starry"}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(tc.method, "/config", strings.NewReader(tc.body))
			rec := httptest.NewRecorder()

			Routes().ServeHTTP(rec, req)

			if rec.Code != http.StatusOK {
				t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
			}
			var body struct {
				OK   bool `json:"ok"`
				Data struct {
					Theme             string `json:"theme"`
					BreathingMotion   bool   `json:"breathing_motion"`
					WhiteNoiseEnabled bool   `json:"white_noise_enabled"`
				} `json:"data"`
			}
			if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
				t.Fatalf("decode response: %v", err)
			}
			if !body.OK {
				t.Fatal("response ok = false, want true")
			}
			if body.Data.Theme != "starry" || !body.Data.BreathingMotion || body.Data.WhiteNoiseEnabled {
				t.Fatalf("unexpected space config: %+v", body.Data)
			}
		})
	}
}
