package service

import (
	"context"
	"errors"
	"testing"

	"xiguang/backend/internal/ai/domain"
	"xiguang/backend/internal/ai/repository"
)

type fakeRepo struct{ logs []repository.RequestMeta }

func (r *fakeRepo) LogRequest(_ context.Context, _ int64, m repository.RequestMeta) (int64, error) {
	r.logs = append(r.logs, m)
	return int64(len(r.logs)), nil
}
func (*fakeRepo) ListRequests(context.Context, int64) ([]domain.RequestLog, error) { return nil, nil }
func (*fakeRepo) SaveArtifact(context.Context, int64, domain.SummarySaveRequest) (domain.AIArtifact, error) {
	return domain.AIArtifact{ID: 1}, nil
}
func (*fakeRepo) UpdateArtifact(context.Context, int64, int64, domain.SummarySaveRequest) (domain.AIArtifact, error) {
	return domain.AIArtifact{ID: 1}, nil
}
func (*fakeRepo) DeleteArtifact(context.Context, int64, int64) (bool, error)       { return true, nil }
func (*fakeRepo) LogFeedback(context.Context, int64, domain.FeedbackRequest) error { return nil }

type fakeProvider struct {
	json string
	err  error
}

func (p fakeProvider) Chat(context.Context, string, string) (string, int, error) {
	return p.json, 12, p.err
}
func (p fakeProvider) TextChat(context.Context, string, string) (string, int, error) {
	return p.json, 12, p.err
}

type fakeSources struct {
	fragments []FragmentSummary
	groups    []IslandCandidate
	err       error
}

func (f fakeSources) AIEnabled(context.Context, int64) (bool, error) { return true, f.err }

func (f fakeSources) ResolveScope(context.Context, int64, domain.AIScope) ([]FragmentSummary, error) {
	return f.fragments, f.err
}
func (f fakeSources) IslandCandidates(context.Context, int64) ([]IslandCandidate, error) {
	return f.groups, f.err
}

type fakeQuota struct {
	reserved, released int
	err                error
}

func (q *fakeQuota) ReserveAI(context.Context, int64) error { q.reserved++; return q.err }
func (q *fakeQuota) ReleaseAI(context.Context, int64)       { q.released++ }

var testFragments = []FragmentSummary{{ID: 1, ContentText: "第一束光"}, {ID: 2, ContentText: "第二束光"}}

func TestSummaryRejectsOutOfScopeReferenceAndReturnsQuota(t *testing.T) {
	quota := &fakeQuota{}
	repo := &fakeRepo{}
	s := New(repo, fakeProvider{json: `{"summary":"这段时间有一点回声","key_points":[{"text":"线索一","source_fragment_ids":[1]},{"text":"线索二","source_fragment_ids":[99]}],"title_candidates":["微光之间"],"why":"按重复主题整理"}`}, fakeSources{fragments: testFragments}, quota)
	got := s.PreviewSummary(t.Context(), 7, domain.SummaryPreviewRequest{Scope: domain.AIScope{Type: "fragments", FragmentIDs: []int64{1, 2}}})
	if got.Status != "parse_error" || quota.reserved != 1 || quota.released != 1 {
		t.Fatalf("got=%+v quota=%+v", got, quota)
	}
}

func TestSuccessfulSummaryKeepsQuotaAndDoesNotLogContent(t *testing.T) {
	quota := &fakeQuota{}
	repo := &fakeRepo{}
	s := New(repo, fakeProvider{json: `{"summary":"这段时间有一点回声","key_points":[{"text":"线索一","source_fragment_ids":[1]},{"text":"线索二","source_fragment_ids":[2]}],"title_candidates":["微光之间"],"why":"按重复主题整理"}`}, fakeSources{fragments: testFragments}, quota)
	got := s.PreviewSummary(t.Context(), 7, domain.SummaryPreviewRequest{Scope: domain.AIScope{Type: "fragments", FragmentIDs: []int64{1, 2}}})
	if got.Status != "success" || quota.released != 0 || len(repo.logs) != 1 || repo.logs[0].ContentCount != 2 {
		t.Fatalf("got=%+v quota=%+v logs=%+v", got, quota, repo.logs)
	}
}

func TestPolishProtectsNumbersAndNoChangeReturnsQuota(t *testing.T) {
	quota := &fakeQuota{}
	s := New(&fakeRepo{}, fakeProvider{json: `{"polished_text":"今天花了 20 元","why":"无需调整","no_change":true}`}, fakeSources{}, quota)
	got := s.PreviewPolish(t.Context(), 7, domain.PolishRequest{ContentText: "今天花了 20 元"})
	if got.Status != "no_change" || quota.released != 1 {
		t.Fatalf("got=%+v quota=%+v", got, quota)
	}

	quota2 := &fakeQuota{}
	s2 := New(&fakeRepo{}, fakeProvider{json: `{"polished_text":"今天花了一些钱","why":"更自然","no_change":false}`}, fakeSources{}, quota2)
	got = s2.PreviewPolish(t.Context(), 7, domain.PolishRequest{ContentText: "今天花了 20 元"})
	if got.Status != "parse_error" || quota2.released != 1 {
		t.Fatalf("got=%+v quota=%+v", got, quota2)
	}
}

func TestProviderFailureReturnsQuota(t *testing.T) {
	quota := &fakeQuota{}
	s := New(&fakeRepo{}, fakeProvider{err: errors.New("offline")}, fakeSources{fragments: testFragments}, quota)
	got := s.PreviewSummary(t.Context(), 1, domain.SummaryPreviewRequest{Scope: domain.AIScope{Type: "fragments", FragmentIDs: []int64{1, 2}}})
	if got.Status != "error" || quota.released != 1 {
		t.Fatalf("got=%+v quota=%+v", got, quota)
	}
}
