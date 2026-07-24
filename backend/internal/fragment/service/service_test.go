package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"xiguang/backend/internal/fragment/domain"
)

type fakeRepo struct {
	confirmed map[string]bool
}

type recordingRepo struct {
	fakeRepo
	query domain.ListQuery
}

func (f *recordingRepo) List(ctx context.Context, userID int64, query domain.ListQuery) ([]domain.Fragment, error) {
	f.query = query
	return []domain.Fragment{{ID: 9, ContentText: "找到的旧光"}}, nil
}

func (f fakeRepo) Create(ctx context.Context, userID int64, text, emotion, status string, tags, media []string) (domain.Fragment, error) {
	return domain.Fragment{ID: 1, UserID: userID, ContentText: text, Emotion: emotion, Status: status, Tags: tags, MediaURLs: media, CreatedAt: time.Now()}, nil
}

func (f fakeRepo) Update(ctx context.Context, userID int64, id int64, text, emotion, status string, tags []string, media *[]string) (domain.Fragment, error) {
	return domain.Fragment{}, nil
}

func (f fakeRepo) Delete(ctx context.Context, userID, id int64) (bool, error) { return false, nil }

func (f fakeRepo) Restore(ctx context.Context, userID, id int64) (bool, error) { return false, nil }

func (f fakeRepo) DeletePermanently(ctx context.Context, userID, id int64) (bool, error) {
	return false, nil
}

func (f fakeRepo) List(ctx context.Context, userID int64, query domain.ListQuery) ([]domain.Fragment, error) {
	return nil, nil
}

func (f fakeRepo) ListDeleted(ctx context.Context, userID int64, limit int) ([]domain.Fragment, error) {
	return nil, nil
}

func (f fakeRepo) FindByID(ctx context.Context, userID, id int64) (domain.Fragment, error) {
	return domain.Fragment{}, nil
}

func (f fakeRepo) LogCreate(ctx context.Context, userID int64, clientOpID string, dto domain.Fragment) error {
	return nil
}

func (f fakeRepo) FindConfirmedMedia(ctx context.Context, userID int64, objectKeys []string) (map[string]bool, error) {
	return f.confirmed, nil
}

func TestCreateRejectsUnconfirmedOrLocalMedia(t *testing.T) {
	svc := New(fakeRepo{confirmed: map[string]bool{
		"users/7/media/ok.jpg": true,
	}}, nil)

	cases := []string{
		"/tmp/local.jpg",
		"data:text/plain;base64,abc",
		"file:///tmp/local.jpg",
		"users/8/media/other.jpg",
		"users/7/media/missing.jpg",
	}
	for _, media := range cases {
		_, err := svc.Create(context.Background(), 7, domain.CreateParams{
			ContentText: "hello",
			Emotion:     "平静",
			MediaURLs:   []string{media},
		})
		if !errors.Is(err, ErrInvalidMedia) {
			t.Fatalf("media %q: expected ErrInvalidMedia, got %v", media, err)
		}
	}
}

func TestCreateAcceptsInlineImageMedia(t *testing.T) {
	svc := New(fakeRepo{}, nil)

	dto, err := svc.Create(context.Background(), 7, domain.CreateParams{
		ContentText: "hello",
		Emotion:     "平静",
		MediaURLs:   []string{"data:image/png;base64,abc"},
	})
	if err != nil {
		t.Fatalf("expected inline image media to be accepted: %v", err)
	}
	if len(dto.MediaURLs) != 1 || dto.MediaURLs[0] != "data:image/png;base64,abc" {
		t.Fatalf("unexpected media urls: %+v", dto.MediaURLs)
	}
}

func TestCreateAcceptsInlineAudioMedia(t *testing.T) {
	svc := New(fakeRepo{}, nil)

	dto, err := svc.Create(context.Background(), 7, domain.CreateParams{
		ContentText: "hello",
		Emotion:     "平静",
		MediaURLs:   []string{"data:audio/mp4;base64,abc"},
	})
	if err != nil {
		t.Fatalf("expected inline audio media to be accepted: %v", err)
	}
	if len(dto.MediaURLs) != 1 || dto.MediaURLs[0] != "data:audio/mp4;base64,abc" {
		t.Fatalf("unexpected media urls: %+v", dto.MediaURLs)
	}
}

func TestCreateAcceptsConfirmedUserMedia(t *testing.T) {
	svc := New(fakeRepo{confirmed: map[string]bool{
		"users/7/media/ok.jpg": true,
	}}, nil)

	dto, err := svc.Create(context.Background(), 7, domain.CreateParams{
		ContentText: "hello",
		Emotion:     "平静",
		MediaURLs:   []string{"users/7/media/ok.jpg"},
	})
	if err != nil {
		t.Fatalf("expected confirmed media to be accepted: %v", err)
	}
	if len(dto.MediaURLs) != 1 || dto.MediaURLs[0] != "users/7/media/ok.jpg" {
		t.Fatalf("unexpected media urls: %+v", dto.MediaURLs)
	}
}

func TestSearchUsesTrimmedFullTextQuery(t *testing.T) {
	repo := &recordingRepo{}
	svc := New(repo, nil)
	items, err := svc.Search(context.Background(), 7, "  考试周  ", "200")
	if err != nil {
		t.Fatalf("search failed: %v", err)
	}
	if len(items) != 1 || repo.query.Search != "考试周" || repo.query.Limit != 200 {
		t.Fatalf("unexpected search query/result: query=%+v items=%+v", repo.query, items)
	}
}
