package shared

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestWriteJSONWrapsSuccessfulResponse(t *testing.T) {
	rec := httptest.NewRecorder()

	WriteJSON(rec, http.StatusAccepted, map[string]string{"message": "ok"})

	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusAccepted)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json; charset=utf-8" {
		t.Fatalf("content-type = %q", got)
	}
	var body APIResponse
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !body.OK || body.Error != nil {
		t.Fatalf("unexpected response wrapper: %+v", body)
	}
}

func TestWriteErrorWrapsAppError(t *testing.T) {
	rec := httptest.NewRecorder()

	WriteError(rec, http.StatusUnauthorized, "unauthorized", "请先登录后再继续。")

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
	var body APIResponse
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.OK || body.Error == nil {
		t.Fatalf("unexpected response wrapper: %+v", body)
	}
	if body.Error.Code != "unauthorized" {
		t.Fatalf("error code = %q", body.Error.Code)
	}
}
