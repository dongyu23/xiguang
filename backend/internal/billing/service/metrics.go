package service

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

type billingMetrics struct {
	mu       sync.Mutex
	counters map[string]uint64
	latency  map[string]struct {
		count uint64
		sum   float64
	}
}

func newBillingMetrics() *billingMetrics {
	return &billingMetrics{counters: map[string]uint64{}, latency: map[string]struct {
		count uint64
		sum   float64
	}{}}
}

func (m *billingMetrics) inc(name, labels string) {
	m.mu.Lock()
	m.counters[name+labels]++
	m.mu.Unlock()
}

func (m *billingMetrics) observeWebhook(provider string, delay time.Duration) {
	if delay < 0 {
		delay = 0
	}
	m.mu.Lock()
	item := m.latency[provider]
	item.count++
	item.sum += delay.Seconds()
	m.latency[provider] = item
	m.mu.Unlock()
}

func (s *Service) MetricsText(ctx context.Context) string {
	s.metrics.mu.Lock()
	counters := make(map[string]uint64, len(s.metrics.counters))
	for key, value := range s.metrics.counters {
		counters[key] = value
	}
	latency := make(map[string]struct {
		count uint64
		sum   float64
	}, len(s.metrics.latency))
	for key, value := range s.metrics.latency {
		latency[key] = value
	}
	s.metrics.mu.Unlock()

	keys := make([]string, 0, len(counters))
	for key := range counters {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	var output strings.Builder
	output.WriteString("# TYPE xiguang_payment_events_total counter\n")
	for _, key := range keys {
		fmt.Fprintf(&output, "%s %d\n", key, counters[key])
	}
	providers := make([]string, 0, len(latency))
	for provider := range latency {
		providers = append(providers, provider)
	}
	sort.Strings(providers)
	for _, provider := range providers {
		item := latency[provider]
		fmt.Fprintf(&output, "xiguang_payment_webhook_delay_seconds_count{provider=%q} %d\n", provider, item.count)
		fmt.Fprintf(&output, "xiguang_payment_webhook_delay_seconds_sum{provider=%q} %.6f\n", provider, item.sum)
	}
	mismatches, err := s.repo.EntitlementMismatchCount(ctx)
	if err == nil {
		fmt.Fprintf(&output, "xiguang_payment_entitlement_mismatches %d\n", mismatches)
	}
	return output.String()
}

func labels(values ...string) string {
	if len(values)%2 != 0 {
		return ""
	}
	parts := make([]string, 0, len(values)/2)
	for index := 0; index < len(values); index += 2 {
		parts = append(parts, values[index]+"="+fmt.Sprintf("%q", values[index+1]))
	}
	return "{" + strings.Join(parts, ",") + "}"
}
