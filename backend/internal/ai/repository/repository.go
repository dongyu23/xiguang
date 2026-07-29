package repository

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/ai/domain"
)

type RequestMeta struct {
	RequestType  string
	Status       string
	Model        string
	LatencyMS    int
	TokenUsed    int
	ContentCount int
	ErrorCode    string
}

type Repository interface {
	LogRequest(context.Context, int64, RequestMeta) (int64, error)
	ListRequests(context.Context, int64) ([]domain.RequestLog, error)
	SaveArtifact(context.Context, int64, domain.SummarySaveRequest) (domain.AIArtifact, error)
	UpdateArtifact(context.Context, int64, int64, domain.SummarySaveRequest) (domain.AIArtifact, error)
	DeleteArtifact(context.Context, int64, int64) (bool, error)
	LogFeedback(context.Context, int64, domain.FeedbackRequest) error
}

type PG struct{ db *pgxpool.Pool }

func NewPG(db *pgxpool.Pool) *PG { return &PG{db: db} }

func (r *PG) LogRequest(ctx context.Context, userID int64, meta RequestMeta) (int64, error) {
	var id int64
	err := r.db.QueryRow(ctx, `INSERT INTO ai_requests(
		user_id, mode, request_type, status, model, latency_ms, token_used, content_count, error_code, completed_at)
		VALUES($1,$2,$2,$3,NULLIF($4,''),$5,$6,$7,NULLIF($8,''),now()) RETURNING id`,
		userID, meta.RequestType, meta.Status, meta.Model, meta.LatencyMS,
		meta.TokenUsed, meta.ContentCount, meta.ErrorCode).Scan(&id)
	return id, err
}

func (r *PG) ListRequests(ctx context.Context, userID int64) ([]domain.RequestLog, error) {
	rows, err := r.db.Query(ctx, `SELECT id, COALESCE(request_type,mode), status,
		COALESCE(model,''), COALESCE(latency_ms,0), COALESCE(token_used,0),
		COALESCE(content_count,0), COALESCE(error_code,''), created_at
		FROM ai_requests WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []domain.RequestLog{}
	for rows.Next() {
		var item domain.RequestLog
		if err := rows.Scan(&item.ID, &item.RequestType, &item.Status, &item.Model,
			&item.LatencyMS, &item.TokenUsed, &item.ContentCount, &item.ErrorCode, &item.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) SaveArtifact(ctx context.Context, userID int64, req domain.SummarySaveRequest) (domain.AIArtifact, error) {
	points, _ := json.Marshal(req.KeyPoints)
	row := r.db.QueryRow(ctx, `INSERT INTO ai_artifacts(
		user_id, scope_type, fragment_ids, island_id, range_start, range_end,
		title, summary_text, key_points, source_request_id, user_edited)
		VALUES($1,$2,$3,NULLIF($4,0),
			CASE WHEN $5>0 THEN now()-($5*interval '1 day') END,
			CASE WHEN $5>0 THEN now() END,$6,$7,$8,NULLIF($9,0),$10)
		RETURNING id, public_id::text, created_at, updated_at`, userID, req.Scope.Type,
		req.Scope.FragmentIDs, req.Scope.IslandID, req.Scope.RangeDays, req.Title,
		req.Summary, points, req.RequestID, req.UserEdited)
	return scanArtifact(row, req)
}

func (r *PG) UpdateArtifact(ctx context.Context, userID, id int64, req domain.SummarySaveRequest) (domain.AIArtifact, error) {
	points, _ := json.Marshal(req.KeyPoints)
	row := r.db.QueryRow(ctx, `UPDATE ai_artifacts SET title=$3, summary_text=$4,
		key_points=$5, user_edited=TRUE, updated_at=now()
		WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, public_id::text, created_at, updated_at`, userID, id, req.Title, req.Summary, points)
	return scanArtifact(row, req)
}

func scanArtifact(row interface{ Scan(...any) error }, req domain.SummarySaveRequest) (domain.AIArtifact, error) {
	item := domain.AIArtifact{Scope: req.Scope, Title: req.Title, Summary: req.Summary,
		KeyPoints: req.KeyPoints, UserEdited: req.UserEdited}
	err := row.Scan(&item.ID, &item.PublicID, &item.CreatedAt, &item.UpdatedAt)
	return item, err
}

func (r *PG) DeleteArtifact(ctx context.Context, userID, id int64) (bool, error) {
	result, err := r.db.Exec(ctx, `UPDATE ai_artifacts SET deleted_at=now(), updated_at=now()
		WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, id)
	return err == nil && result.RowsAffected() > 0, err
}

func (r *PG) LogFeedback(ctx context.Context, userID int64, req domain.FeedbackRequest) error {
	allowed := map[string]bool{"accepted": true, "modified": true, "rejected": true, "undone": true}
	if !allowed[req.Action] {
		req.Action = "rejected"
	}
	reasons := map[string]bool{"": true, "放错了": true, "名字不合适": true, "解释太多": true}
	if !reasons[req.Reason] {
		req.Reason = ""
	}
	_, err := r.LogRequest(ctx, userID, RequestMeta{RequestType: "feedback", Status: req.Action, ErrorCode: req.Reason})
	return err
}
