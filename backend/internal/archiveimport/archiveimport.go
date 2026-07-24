package archiveimport

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/infra/storage"
	"xiguang/backend/internal/shared"
)

const uploadTTL = 30 * time.Minute

var shaPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)

type Handler struct {
	db       *pgxpool.Pool
	provider storage.Provider
}

func New(db *pgxpool.Pool, cfg config.Config) *Handler {
	provider, _ := storage.NewMinIOProvider(cfg)
	h := &Handler{db: db, provider: provider}
	go h.cleanupLoop()
	return h
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Post("/", h.create)
	r.Post("/{id}/upload-urls", h.uploadURLs)
	r.Post("/{id}/commit", h.commit)
	r.Get("/{id}", h.get)
	r.Delete("/{id}", h.cancel)
	return r
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var req struct {
		SourceAccountPublicID string         `json:"source_account_public_id"`
		Manifest              map[string]any `json:"manifest"`
	}
	if shared.DecodeJSON(r, &req) != nil || req.Manifest["format"] != "xiguang-archive" || number(req.Manifest["version"]) != 1 {
		shared.WriteError(w, http.StatusBadRequest, "archive_invalid", "归档 manifest 格式不正确。")
		return
	}
	var id string
	err := h.db.QueryRow(r.Context(), `INSERT INTO archive_imports(user_id, source_account_public_id, manifest)
		VALUES($1,$2,$3) RETURNING id::text`, userID, req.SourceAccountPublicID, req.Manifest).Scan(&id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "archive_failed", "暂时无法创建恢复会话。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, map[string]any{"id": id, "status": "pending", "expires_in_seconds": 86400})
}

type uploadItem struct {
	SHA256   string `json:"sha256"`
	MIME     string `json:"mime_type"`
	FileSize int64  `json:"file_size"`
	Ext      string `json:"extension"`
}

func (h *Handler) uploadURLs(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var req struct {
		Items []uploadItem `json:"items"`
	}
	if shared.DecodeJSON(r, &req) != nil || len(req.Items) == 0 || len(req.Items) > 100 {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "每批需要包含 1 到 100 个媒体。")
		return
	}
	if !h.pending(r.Context(), userID, id) {
		shared.WriteError(w, http.StatusNotFound, "archive_not_found", "恢复会话不存在或已过期。")
		return
	}
	if h.provider == nil {
		shared.WriteError(w, http.StatusServiceUnavailable, "storage_unavailable", "媒体暂存服务不可用。")
		return
	}
	result := make([]map[string]any, 0, len(req.Items))
	for _, item := range req.Items {
		ext := strings.ToLower(item.Ext)
		if !shaPattern.MatchString(item.SHA256) || item.FileSize < 0 || len(ext) > 9 || strings.ContainsAny(ext, `/\\`) {
			shared.WriteError(w, http.StatusBadRequest, "archive_media_invalid", "媒体描述不正确。")
			return
		}
		if ext == "" || ext[0] != '.' {
			ext = ".bin"
		}
		objectKey := fmt.Sprintf("users/%d/archive-imports/%s/%s%s", userID, id, item.SHA256, ext)
		url, err := h.provider.PresignedPutObject(r.Context(), objectKey, item.MIME, uploadTTL)
		if err != nil {
			shared.WriteError(w, http.StatusInternalServerError, "archive_failed", "暂时无法签发媒体上传地址。")
			return
		}
		_, err = h.db.Exec(r.Context(), `INSERT INTO archive_import_media(import_id,sha256,object_key,mime_type,file_size)
			VALUES($1,$2,$3,$4,$5) ON CONFLICT(import_id,sha256) DO UPDATE
			SET object_key=excluded.object_key,mime_type=excluded.mime_type,file_size=excluded.file_size`, id, item.SHA256, objectKey, item.MIME, item.FileSize)
		if err != nil {
			shared.WriteError(w, http.StatusInternalServerError, "archive_failed", "暂时无法记录媒体暂存信息。")
			return
		}
		result = append(result, map[string]any{"sha256": item.SHA256, "object_key": objectKey, "upload_url": url, "expires_in_seconds": int(uploadTTL.Seconds())})
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"items": result})
}

type fragmentInput struct {
	PublicID  string   `json:"public_id"`
	Content   string   `json:"content_text"`
	Emotion   string   `json:"emotion"`
	Status    string   `json:"status"`
	Tags      []string `json:"tags"`
	CreatedAt string   `json:"created_at"`
	UpdatedAt string   `json:"updated_at"`
	MediaSHA  []string `json:"media_sha256"`
}

type relationInput struct {
	PublicID string `json:"public_id"`
	SourceID string `json:"source_archive_id"`
	TargetID string `json:"target_archive_id"`
	Type     string `json:"relation_type"`
	Note     string `json:"note"`
}

type islandInput struct {
	PublicID    string   `json:"public_id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Manual      bool     `json:"manual"`
	Members     []string `json:"members"`
}

type commitRequest struct {
	Fragments []fragmentInput `json:"fragments"`
	Relations []relationInput `json:"relations"`
	Islands   []islandInput   `json:"islands"`
}

func (h *Handler) commit(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var req commitRequest
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "恢复内容格式不正确。")
		return
	}
	tx, err := h.db.BeginTx(r.Context(), pgx.TxOptions{})
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "archive_failed", "暂时无法开始恢复。")
		return
	}
	defer tx.Rollback(r.Context())
	var source, target string
	err = tx.QueryRow(r.Context(), `SELECT ai.source_account_public_id,u.public_id::text
		FROM archive_imports ai JOIN users u ON u.id=ai.user_id
		WHERE ai.id=$1 AND ai.user_id=$2 AND ai.status='pending' AND ai.expires_at>now() FOR UPDATE`, id, userID).Scan(&source, &target)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "archive_not_found", "恢复会话不存在或已过期。")
		return
	}
	_, _ = tx.Exec(r.Context(), `UPDATE archive_imports SET status='committing',updated_at=now() WHERE id=$1`, id)
	crossAccount := source != "" && source != target
	report := map[string]any{"added": 0, "skipped": 0, "conflicts": []map[string]any{}, "id_mapping": map[string]string{}}
	fragmentDBIDs := map[string]int64{}
	for _, item := range req.Fragments {
		oldID := item.PublicID
		if oldID == "" {
			err = errors.New("fragment id missing")
			break
		}
		newID := oldID
		if crossAccount || uuid.Validate(newID) != nil {
			newID = uuid.NewString()
		}
		var existingID int64
		var content, emotion, status string
		findErr := tx.QueryRow(r.Context(), `SELECT id,content_text,COALESCE(emotion,''),status::text
			FROM fragments WHERE user_id=$1 AND public_id=$2 AND is_deleted=FALSE`, userID, newID).Scan(&existingID, &content, &emotion, &status)
		if findErr == nil {
			fragmentDBIDs[oldID] = existingID
			if content == item.Content && emotion == item.Emotion && status == safeStatus(item.Status) {
				report["skipped"] = report["skipped"].(int) + 1
			} else {
				report["conflicts"] = append(report["conflicts"].([]map[string]any), map[string]any{"type": "fragment", "public_id": oldID, "resolution": "kept_existing"})
			}
			continue
		}
		if findErr != pgx.ErrNoRows {
			err = findErr
			break
		}
		created := parseTime(item.CreatedAt)
		updated := parseTime(item.UpdatedAt)
		err = tx.QueryRow(r.Context(), `INSERT INTO fragments(public_id,user_id,content_text,emotion,status,created_at,updated_at)
			VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id`, newID, userID, item.Content, item.Emotion, safeStatus(item.Status), created, updated).Scan(&existingID)
		if err != nil {
			// A global UUID collision belongs to another account; remap it.
			newID = uuid.NewString()
			err = tx.QueryRow(r.Context(), `INSERT INTO fragments(public_id,user_id,content_text,emotion,status,created_at,updated_at)
				VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id`, newID, userID, item.Content, item.Emotion, safeStatus(item.Status), created, updated).Scan(&existingID)
		}
		if err != nil {
			break
		}
		fragmentDBIDs[oldID] = existingID
		report["id_mapping"].(map[string]string)[oldID] = newID
		report["added"] = report["added"].(int) + 1
		if err = mergeTags(r.Context(), tx, userID, existingID, item.Tags); err != nil {
			break
		}
		if err = mergeMedia(r.Context(), tx, id, userID, existingID, item.MediaSHA); err != nil {
			break
		}
	}
	if err == nil {
		err = mergeRelations(r.Context(), tx, userID, req.Relations, fragmentDBIDs, crossAccount, report)
	}
	if err == nil {
		err = mergeIslands(r.Context(), tx, userID, req.Islands, fragmentDBIDs, crossAccount, report)
	}
	if err != nil {
		shared.WriteError(w, http.StatusConflict, "archive_conflict", "恢复内容无法安全合并，未写入任何数据。")
		return
	}
	_, err = tx.Exec(r.Context(), `UPDATE archive_imports SET status='committed',report=$2,updated_at=now() WHERE id=$1`, id, report)
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "archive_failed", "恢复提交失败，未写入任何数据。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"id": id, "status": "committed", "report": report})
}

func mergeTags(ctx context.Context, tx pgx.Tx, userID, fragmentID int64, tags []string) error {
	for _, raw := range tags {
		name := strings.TrimSpace(raw)
		if name == "" || len([]rune(name)) > 128 {
			continue
		}
		var tagID int64
		err := tx.QueryRow(ctx, `INSERT INTO tags(user_id,name,use_count) VALUES($1,$2,1)
			ON CONFLICT(user_id,name) WHERE deleted_at IS NULL DO UPDATE SET use_count=tags.use_count+1
			RETURNING id`, userID, name).Scan(&tagID)
		if err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO fragment_tags(fragment_id,tag_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, fragmentID, tagID); err != nil {
			return err
		}
	}
	return nil
}

func mergeMedia(ctx context.Context, tx pgx.Tx, importID string, userID, fragmentID int64, hashes []string) error {
	for _, hash := range hashes {
		if !shaPattern.MatchString(hash) {
			return errors.New("invalid media hash")
		}
		var key, mime string
		var size int64
		if err := tx.QueryRow(ctx, `SELECT object_key,mime_type,file_size FROM archive_import_media WHERE import_id=$1 AND sha256=$2`, importID, hash).Scan(&key, &mime, &size); err != nil {
			return err
		}
		mediaType := "image"
		if strings.HasPrefix(mime, "audio/") {
			mediaType = "audio"
		}
		_, err := tx.Exec(ctx, `INSERT INTO media_files(user_id,fragment_id,media_type,object_key,file_name,file_size,mime_type)
			SELECT $1,$2,$3,$4,$5,$6,$7 WHERE NOT EXISTS(
				SELECT 1 FROM media_files WHERE user_id=$1 AND fragment_id=$2 AND object_key=$4 AND deleted_at IS NULL)`,
			userID, fragmentID, mediaType, key, filepath.Base(key), size, mime)
		if err != nil {
			return err
		}
	}
	return nil
}

func mergeRelations(ctx context.Context, tx pgx.Tx, userID int64, items []relationInput, ids map[string]int64, cross bool, report map[string]any) error {
	for _, item := range items {
		source, sourceOK := ids[item.SourceID]
		target, targetOK := ids[item.TargetID]
		if !sourceOK || !targetOK || source == target {
			report["conflicts"] = append(report["conflicts"].([]map[string]any), map[string]any{"type": "relation", "public_id": item.PublicID, "reason": "missing_endpoint"})
			continue
		}
		publicID := item.PublicID
		if cross || uuid.Validate(publicID) != nil {
			publicID = uuid.NewString()
		}
		_, err := tx.Exec(ctx, `INSERT INTO relations(public_id,user_id,source_fragment_id,target_fragment_id,relation_type,note)
			VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(user_id,source_fragment_id,target_fragment_id,relation_type) DO NOTHING`, publicID, userID, source, target, item.Type, item.Note)
		if err != nil {
			return err
		}
	}
	return nil
}

func mergeIslands(ctx context.Context, tx pgx.Tx, userID int64, items []islandInput, ids map[string]int64, cross bool, report map[string]any) error {
	for _, item := range items {
		if !item.Manual || strings.TrimSpace(item.Name) == "" {
			continue
		}
		publicID := item.PublicID
		if cross || uuid.Validate(publicID) != nil {
			publicID = uuid.NewString()
		}
		var islandID int64
		err := tx.QueryRow(ctx, `SELECT id FROM islands WHERE user_id=$1 AND public_id=$2 AND deleted_at IS NULL`, userID, publicID).Scan(&islandID)
		if err == pgx.ErrNoRows {
			err = tx.QueryRow(ctx, `INSERT INTO islands(public_id,user_id,name,description,status) VALUES($1,$2,$3,$4,'star_point') RETURNING id`, publicID, userID, item.Name, item.Description).Scan(&islandID)
		}
		if err != nil {
			return err
		}
		for _, member := range item.Members {
			fragmentID, ok := ids[member]
			if !ok {
				report["conflicts"] = append(report["conflicts"].([]map[string]any), map[string]any{"type": "island_member", "island_id": item.PublicID, "fragment_id": member})
				continue
			}
			if _, err = tx.Exec(ctx, `INSERT INTO island_fragments(island_id,fragment_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, islandID, fragmentID); err != nil {
				return err
			}
		}
		_, _ = tx.Exec(ctx, `UPDATE islands SET fragment_count=(SELECT count(*) FROM island_fragments WHERE island_id=$1),updated_at=now() WHERE id=$1`, islandID)
	}
	return nil
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	var status string
	var report map[string]any
	var created, expires time.Time
	err := h.db.QueryRow(r.Context(), `SELECT status,report,created_at,expires_at FROM archive_imports WHERE id=$1 AND user_id=$2`, chi.URLParam(r, "id"), userID).Scan(&status, &report, &created, &expires)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "archive_not_found", "恢复会话不存在。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"id": chi.URLParam(r, "id"), "status": status, "report": report, "created_at": created, "expires_at": expires})
}

func (h *Handler) cancel(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	rows, _ := h.db.Query(r.Context(), `SELECT aim.object_key FROM archive_import_media aim JOIN archive_imports ai ON ai.id=aim.import_id WHERE ai.id=$1 AND ai.user_id=$2 AND ai.status<>'committed'`, id, userID)
	keys := []string{}
	if rows != nil {
		for rows.Next() {
			var key string
			_ = rows.Scan(&key)
			keys = append(keys, key)
		}
		rows.Close()
	}
	result, err := h.db.Exec(r.Context(), `DELETE FROM archive_imports WHERE id=$1 AND user_id=$2 AND status<>'committed'`, id, userID)
	if err != nil || result.RowsAffected() == 0 {
		shared.WriteError(w, http.StatusNotFound, "archive_not_found", "恢复会话不存在或已经提交。")
		return
	}
	if h.provider != nil {
		for _, key := range keys {
			_ = h.provider.DeleteObject(r.Context(), key)
		}
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

func (h *Handler) pending(ctx context.Context, userID int64, id string) bool {
	var ok bool
	_ = h.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM archive_imports WHERE id=$1 AND user_id=$2 AND status='pending' AND expires_at>now())`, id, userID).Scan(&ok)
	return ok
}

func (h *Handler) cleanupLoop() {
	ticker := time.NewTicker(time.Hour)
	defer ticker.Stop()
	h.cleanupExpired(context.Background())
	for range ticker.C {
		h.cleanupExpired(context.Background())
	}
}

func (h *Handler) cleanupExpired(ctx context.Context) {
	rows, err := h.db.Query(ctx, `SELECT aim.object_key
		FROM archive_import_media aim
		JOIN archive_imports ai ON ai.id=aim.import_id
		WHERE ai.expires_at<=now() AND ai.status<>'committed'`)
	if err == nil {
		keys := []string{}
		for rows.Next() {
			var key string
			if rows.Scan(&key) == nil {
				keys = append(keys, key)
			}
		}
		rows.Close()
		if h.provider != nil {
			for _, key := range keys {
				_ = h.provider.DeleteObject(ctx, key)
			}
		}
	}
	_, _ = h.db.Exec(ctx, `DELETE FROM archive_imports WHERE expires_at<=now() AND status<>'committed'`)
}

func safeStatus(value string) string {
	switch value {
	case "twilight", "stardust", "echo", "seed", "tide", "island_core":
		return value
	default:
		return "twilight"
	}
}

func parseTime(value string) time.Time {
	parsed, err := time.Parse(time.RFC3339Nano, value)
	if err != nil {
		return time.Now().UTC()
	}
	return parsed
}

func number(value any) int {
	switch v := value.(type) {
	case float64:
		return int(v)
	case int:
		return v
	default:
		return 0
	}
}
