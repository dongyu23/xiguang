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

// WriteJSONWithMeta 在标准响应里 piggyback 一个 meta 字段，用于把版本提示等
// 轻量信息搭载在高频接口的响应里。meta 为 nil 时退化为普通 WriteJSON。
func WriteJSONWithMeta(w http.ResponseWriter, status int, data any, meta any) {
	if meta == nil {
		WriteJSON(w, status, data)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(APIResponse{OK: true, Data: data, Meta: meta}); err != nil {
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
