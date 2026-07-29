package service

import "testing"

func TestListLocksPaidSoundsForFreeTier(t *testing.T) {
	items := New().List("glimmer")
	for _, item := range items {
		if item.RequiredTier == "starlight" && !item.Locked {
			t.Fatalf("paid sound is unlocked: %+v", item)
		}
	}
	items = New().List("galaxy")
	for _, item := range items {
		if item.Locked {
			t.Fatalf("galaxy member sees locked sound: %+v", item)
		}
	}
}
