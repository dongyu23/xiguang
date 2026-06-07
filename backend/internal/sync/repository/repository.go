package repository

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/sync/domain"
)

type Repository interface {
	InsertOperation(ctx context.Context, userID int64, deviceID string, op domain.PushOperation) (int64, error)
	FindSinceRev(ctx context.Context, userID, sinceRev int64, limit int) ([]domain.PullOperation, error)
	ExecuteFragmentInsert(ctx context.Context, userID int64, payload map[string]any) (int64, error)
	ExecuteFragmentUpdate(ctx context.Context, userID int64, entityID int64, payload map[string]any) error
	ExecuteFragmentDelete(ctx context.Context, userID int64, entityID int64) error
	FindFragmentByPublicID(ctx context.Context, userID int64, publicID string) (int64, error)
	FindMostRecentServerRev(ctx context.Context, userID int64) (int64, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) InsertOperation(ctx context.Context, userID int64, deviceID string, op domain.PushOperation) (int64, error) {
	payload, _ := json.Marshal(op.Payload)
	var rev int64
	err := r.db.QueryRow(ctx, `INSERT INTO oplog(user_id, client_op_id, entity_type, op_type, entity_public_id, payload, client_seq, device_id)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8)
		ON CONFLICT(user_id, client_op_id) DO UPDATE SET client_op_id=EXCLUDED.client_op_id
		RETURNING server_rev`, userID, op.ClientOpID, op.EntityType, op.OpType, op.EntityPublicID, string(payload), op.ClientSeq, deviceID).Scan(&rev)
	return rev, err
}

func (r *PG) FindSinceRev(ctx context.Context, userID, sinceRev int64, limit int) ([]domain.PullOperation, error) {
	rows, err := r.db.Query(ctx, `SELECT server_rev, client_op_id, entity_type, op_type, entity_public_id, payload, client_seq, device_id, created_at
		FROM oplog WHERE user_id=$1 AND server_rev>$2 ORDER BY server_rev ASC LIMIT $3`, userID, sinceRev, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.PullOperation{}
	for rows.Next() {
		var item domain.PullOperation
		var entityPublicID, deviceID sql.NullString
		var payload string
		var createdAt time.Time
		if err := rows.Scan(&item.ServerRev, &item.ClientOpID, &item.EntityType, &item.OpType, &entityPublicID, &payload, &item.ClientSeq, &deviceID, &createdAt); err != nil {
			return nil, err
		}
		_ = json.Unmarshal([]byte(payload), &item.Payload)
		item.EntityPublicID = entityPublicID.String
		item.DeviceID = deviceID.String
		item.CreatedAt = createdAt
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) FindFragmentByPublicID(ctx context.Context, userID int64, publicID string) (int64, error) {
	var id int64
	err := r.db.QueryRow(ctx,
		`SELECT id FROM fragments WHERE user_id=$1 AND public_id=$2 AND is_deleted=FALSE`, userID, publicID,
	).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}

func (r *PG) ExecuteFragmentInsert(ctx context.Context, userID int64, payload map[string]any) (int64, error) {
	text := stringField(payload, "content_text")
	emotion := stringField(payload, "emotion")
	publicID := stringField(payload, "public_id")

	var id int64
	err := r.db.QueryRow(ctx,
		`INSERT INTO fragments(user_id, public_id, content_text, emotion)
		 VALUES($1, $2, $3, $4)
		 ON CONFLICT(public_id) DO UPDATE SET content_text=EXCLUDED.content_text, emotion=EXCLUDED.emotion, updated_at=now()
		 RETURNING id`, userID, publicID, text, emotion,
	).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}

func (r *PG) ExecuteFragmentUpdate(ctx context.Context, userID int64, entityID int64, payload map[string]any) error {
	text := stringField(payload, "content_text")
	emotion := stringField(payload, "emotion")
	_, err := r.db.Exec(ctx,
		`UPDATE fragments SET content_text=$1, emotion=$2, updated_at=now()
		 WHERE id=$3 AND user_id=$4 AND is_deleted=FALSE`, text, emotion, entityID, userID,
	)
	return err
}

func (r *PG) ExecuteFragmentDelete(ctx context.Context, userID int64, entityID int64) error {
	_, err := r.db.Exec(ctx,
		`UPDATE fragments SET is_deleted=TRUE, deleted_at=now()
		 WHERE id=$1 AND user_id=$2 AND is_deleted=FALSE`, entityID, userID,
	)
	return err
}

func (r *PG) FindMostRecentServerRev(ctx context.Context, userID int64) (int64, error) {
	var rev int64
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(MAX(server_rev), 0) FROM oplog WHERE user_id=$1`, userID,
	).Scan(&rev)
	return rev, err
}

func stringField(m map[string]any, key string) string {
	v, ok := m[key]
	if !ok {
		return ""
	}
	s, ok := v.(string)
	if !ok {
		return ""
	}
	return s
}
