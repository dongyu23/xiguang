package provider

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"xiguang/backend/internal/infra/config"
)

func TestDeepSeekChatRequestsJSONResponse(t *testing.T) {
	var requestBody map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		_, _ = w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":"{\"ok\":true}"}}],"usage":{"total_tokens":9}}`))
	}))
	t.Cleanup(server.Close)

	client := NewDeepSeek(config.Config{
		DeepSeekAPIKey:  "test-key",
		DeepSeekBaseURL: server.URL,
		DeepSeekModel:   "deepseek-chat",
	})

	if _, _, err := client.Chat(context.Background(), "system", "user"); err != nil {
		t.Fatalf("chat failed: %v", err)
	}

	format, ok := requestBody["response_format"].(map[string]any)
	if !ok {
		t.Fatal("expected response_format in JSON chat request")
	}
	if got := format["type"]; got != "json_object" {
		t.Fatalf("expected json_object response format, got %v", got)
	}
}

func TestDeepSeekTextChatDoesNotRequestJSONResponse(t *testing.T) {
	var requestBody map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		_, _ = w.Write([]byte(`{"choices":[{"message":{"role":"assistant","content":"润色后的文字"}}],"usage":{"total_tokens":9}}`))
	}))
	t.Cleanup(server.Close)

	client := NewDeepSeek(config.Config{
		DeepSeekAPIKey:  "test-key",
		DeepSeekBaseURL: server.URL,
		DeepSeekModel:   "deepseek-chat",
	})

	if _, _, err := client.TextChat(context.Background(), "system", "user"); err != nil {
		t.Fatalf("text chat failed: %v", err)
	}

	if _, ok := requestBody["response_format"]; ok {
		t.Fatal("did not expect response_format in text chat request")
	}
}
