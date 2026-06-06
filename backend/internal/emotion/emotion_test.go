package emotion

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRoutesListMVPEmotions(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()

	Routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body struct {
		OK   bool      `json:"ok"`
		Data []Emotion `json:"data"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !body.OK {
		t.Fatal("response ok = false, want true")
	}
	if len(body.Data) != 8 {
		t.Fatalf("emotion count = %d, want 8", len(body.Data))
	}
	foundUnknown := false
	for _, item := range body.Data {
		if item.Name == "说不清" {
			foundUnknown = true
		}
		if item.ColorHex == "" {
			t.Fatalf("emotion %q has empty color", item.Name)
		}
	}
	if !foundUnknown {
		t.Fatal("missing MVP default emotion 说不清")
	}
}
