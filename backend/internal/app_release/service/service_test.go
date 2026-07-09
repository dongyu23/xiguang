package service

import (
	"context"
	"errors"
	"testing"

	"xiguang/backend/internal/app_release/domain"
	"xiguang/backend/internal/app_release/repository"
)

// fakeRepo 实现 repository.Repository，用于不依赖数据库地验证 service 业务规则。
type fakeRepo struct {
	latest      domain.Release
	latestErr   error
	inserted    domain.PublishParams
	insertErr   error
	updateInput domain.UpdatePolicyParams
}

func (f *fakeRepo) Insert(ctx context.Context, p domain.PublishParams) (domain.Release, error) {
	f.inserted = p
	if f.insertErr != nil {
		return domain.Release{}, f.insertErr
	}
	return domain.Release{ID: 1, BuildNumber: p.BuildNumber}, nil
}
func (f *fakeRepo) FindLatest(ctx context.Context, q domain.LatestQuery) (domain.Release, error) {
	return f.latest, f.latestErr
}
func (f *fakeRepo) FindByPublicID(ctx context.Context, publicID string) (domain.Release, error) {
	return domain.Release{}, repository.ErrNotFound
}
func (f *fakeRepo) List(ctx context.Context, includeDeleted bool, limit int) ([]domain.Release, error) {
	return nil, nil
}
func (f *fakeRepo) UpdatePolicy(ctx context.Context, publicID string, p domain.UpdatePolicyParams) (domain.Release, error) {
	f.updateInput = p
	return domain.Release{}, nil
}
func (f *fakeRepo) SoftDelete(ctx context.Context, publicID string) (bool, error) {
	return true, nil
}

const validSHA = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

func baseParams() domain.PublishParams {
	return domain.PublishParams{
		Channel:      "stable",
		Platform:    "android",
		Version:      "0.2.0",
		BuildNumber:  5,
		APKFileName:  "xiguang-0.2.0+5.apk",
		APKSizeBytes: 1024,
		SHA256:       validSHA,
		ReleaseNote:  "first",
	}
}

func TestPublish_RejectsBuildNotIncreasing(t *testing.T) {
	repo := &fakeRepo{latest: domain.Release{BuildNumber: 10}}
	svc := New(repo, "", func(string) bool { return true })
	_, err := svc.Publish(context.Background(), baseParams())
	if !errors.Is(err, ErrBuildNotIncreasing) {
		t.Fatalf("expected ErrBuildNotIncreasing, got %v", err)
	}
}

func TestPublish_RejectsBadSHA256(t *testing.T) {
	repo := &fakeRepo{latestErr: repository.ErrNotFound}
	svc := New(repo, "", func(string) bool { return true })
	p := baseParams()
	p.SHA256 = "not-hex"
	_, err := svc.Publish(context.Background(), p)
	if !errors.Is(err, ErrInvalidSHA256) {
		t.Fatalf("expected ErrInvalidSHA256, got %v", err)
	}
}

func TestPublish_RejectsPathTraversal(t *testing.T) {
	repo := &fakeRepo{latestErr: repository.ErrNotFound}
	svc := New(repo, "", func(string) bool { return true })
	cases := []string{"../evil.apk", "a/b.apk", "x.txt", "noext"}
	for _, name := range cases {
		p := baseParams()
		p.APKFileName = name
		_, err := svc.Publish(context.Background(), p)
		if !errors.Is(err, ErrInvalidFileName) {
			t.Fatalf("name=%q expected ErrInvalidFileName, got %v", name, err)
		}
	}
}

func TestPublish_RejectsMissingFile(t *testing.T) {
	repo := &fakeRepo{latestErr: repository.ErrNotFound}
	svc := New(repo, "", func(string) bool { return false }) // 文件不存在
	_, err := svc.Publish(context.Background(), baseParams())
	if !errors.Is(err, ErrInvalidFileName) {
		t.Fatalf("expected ErrInvalidFileName when file missing, got %v", err)
	}
}

func TestPublish_AcceptsIncreasingBuild(t *testing.T) {
	repo := &fakeRepo{latest: domain.Release{BuildNumber: 4}, latestErr: nil}
	svc := New(repo, "https://host/media/app/", func(string) bool { return true })
	rel, err := svc.Publish(context.Background(), baseParams())
	if err != nil {
		t.Fatalf("expected success, got %v", err)
	}
	if rel.BuildNumber != 5 {
		t.Fatalf("expected build 5, got %d", rel.BuildNumber)
	}
	if repo.inserted.APKFileName != "xiguang-0.2.0+5.apk" {
		t.Fatalf("inserted wrong file name: %s", repo.inserted.APKFileName)
	}
}

func TestLatestPublic_ReturnsNilWhenNotFound(t *testing.T) {
	repo := &fakeRepo{latestErr: repository.ErrNotFound}
	svc := New(repo, "", nil)
	view, err := svc.LatestPublic(context.Background(), "stable", "android")
	if err != nil {
		t.Fatalf("expected nil error, got %v", err)
	}
	if view != nil {
		t.Fatalf("expected nil view, got %+v", view)
	}
}

func TestLatestPublic_RejectsUnknownChannel(t *testing.T) {
	repo := &fakeRepo{}
	svc := New(repo, "", nil)
	_, err := svc.LatestPublic(context.Background(), "weird-channel", "android")
	if !errors.Is(err, ErrInvalidParams) {
		t.Fatalf("expected ErrInvalidParams, got %v", err)
	}
}

func TestLatestPublic_BuildsDownloadURL(t *testing.T) {
	repo := &fakeRepo{latest: domain.Release{
		Channel: "stable", Platform: "android", BuildNumber: 5,
		Version: "0.2.0", APKFileName: "xiguang-0.2.0+5.apk",
	}}
	svc := New(repo, "https://host/media/app", nil)
	view, err := svc.LatestPublic(context.Background(), "", "")
	if err != nil {
		t.Fatalf("expected success, got %v", err)
	}
	if view == nil {
		t.Fatal("expected non-nil view")
	}
	if view.DownloadURL != "https://host/media/app/xiguang-0.2.0+5.apk" {
		t.Fatalf("unexpected download url: %s", view.DownloadURL)
	}
	if view.LatestBuild != 5 {
		t.Fatalf("expected latest build 5, got %d", view.LatestBuild)
	}
}

func TestUpdatePolicy_RejectsAllNil(t *testing.T) {
	repo := &fakeRepo{}
	svc := New(repo, "", nil)
	_, err := svc.UpdatePolicy(context.Background(), "any", domain.UpdatePolicyParams{})
	if !errors.Is(err, ErrInvalidParams) {
		t.Fatalf("expected ErrInvalidParams, got %v", err)
	}
}
