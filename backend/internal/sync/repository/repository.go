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
