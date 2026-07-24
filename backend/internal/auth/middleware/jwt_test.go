package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeSessionParser struct{}

func (fakeSessionParser) ParseToken(string) (int64, error) {
	return 42, nil
}

func (fakeSessionParser) ParseTokenSession(string) (int64, int64, error) {
	return 42, 73, nil
}

func TestRequireAuthExposesCurrentSession(t *testing.T) {
	handler := RequireAuth(fakeSessionParser{})(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, hasUser := UserID(r.Context())
		sessionID, hasSession := SessionID(r.Context())
		if !hasUser || userID != 42 {
			t.Fatalf("user id = %d, present = %v", userID, hasUser)
		}
		if !hasSession || sessionID != 73 {
			t.Fatalf("session id = %d, present = %v", sessionID, hasSession)
		}
		w.WriteHeader(http.StatusNoContent)
	}))

	req := httptest.NewRequest(http.MethodGet, "/users/devices", nil)
	req.Header.Set("Authorization", "Bearer signed-token")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, req)

	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNoContent)
	}
}
