package shared

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
)

type APIResponse struct {
	OK    bool        `json:"ok"`
	Data  any         `json:"data,omitempty"`
	Error *APIError   `json:"error,omitempty"`
	Meta  interface{} `json:"meta,omitempty"`
}

type APIError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

var (
	ErrUnauthorized = errors.New("unauthorized")
	ErrNotFound     = errors.New("not_found")
	ErrConflict     = errors.New("conflict")
)

func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(APIResponse{OK: true, Data: data}); err != nil {
		slog.Error("write json", "error", err)
	}
}

func WriteError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(APIResponse{OK: false, Error: &APIError{Code: code, Message: message}})
}

func DecodeJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(dst)
}
