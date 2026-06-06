package whitenoise

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRoutesListWhiteNoiseOptions(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()

	Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body struct {
		OK   bool `json:"ok"`
		Data []struct {
			ID       string `json:"id"`
			Name     string `json:"name"`
			Category string `json:"category"`
		} `json:"data"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !body.OK {
		t.Fatal("response ok = false, want true")
	}
	if len(body.Data) < 4 {
		t.Fatalf("noise option count = %d, want at least 4", len(body.Data))
	}
	foundRain := false
	for _, item := range body.Data {
		if item.ID == "" || item.Name == "" || item.Category == "" {
			t.Fatalf("incomplete noise option: %+v", item)
		}
		if item.ID == "rain" && item.Name == "雨声" {
			foundRain = true
		}
	}
	if !foundRain {
		t.Fatal("missing rain white noise option")
	}
}
