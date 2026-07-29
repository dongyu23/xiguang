package service

import (
	"context"
	"testing"

	"xiguang/backend/internal/stats/domain"
)

type statsRepoStub struct{ tide domain.EmotionCount }

func (s statsRepoStub) EmotionCounts(context.Context, int64) ([]domain.EmotionCount, error) {
	return nil, nil
}
func (s statsRepoStub) FreqWords(context.Context, int64, int) ([]domain.FreqWord, error) {
	return nil, nil
}
func (s statsRepoStub) TideSignal(context.Context, int64) (domain.EmotionCount, error) {
	return s.tide, nil
}

func TestTideInsightKeepsInterpretationGentle(t *testing.T) {
	result, err := New(statsRepoStub{tide: domain.EmotionCount{Name: "疲惫", Count: 4}}).Tide(context.Background(), 1)
	if err != nil {
		t.Fatal(err)
	}
	if result.Emotion != "疲惫" || result.Occurrences != 4 {
		t.Fatalf("unexpected tide insight: %+v", result)
	}
	if result.Message == "" {
		t.Fatal("tide insight message is empty")
	}
}
