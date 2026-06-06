package router

import (
	"os"
	"strings"
	"testing"
)

func TestRouterMountsCLAUDEMVPModules(t *testing.T) {
	raw, err := os.ReadFile("router.go")
	if err != nil {
		t.Fatalf("read router.go: %v", err)
	}
	source := string(raw)

	requiredSnippets := []string{
		`r.Get("/healthz"`,
		`r.Route("/api/v1"`,
		`api.Mount("/auth"`,
		`api.Mount("/emotions"`,
		`private.Mount("/users"`,
		`private.Mount("/fragments"`,
		`private.Mount("/timeline"`,
		`private.Mount("/tags"`,
		`private.Mount("/stats"`,
		`private.Mount("/relations"`,
		`private.Mount("/starmap"`,
		`private.Mount("/islands"`,
		`private.Mount("/media"`,
		`private.Mount("/space"`,
		`private.Mount("/whitenoise"`,
		`private.Mount("/sync"`,
		`private.Mount("/ai"`,
		`private.Mount("/asr"`,
	}
	for _, snippet := range requiredSnippets {
		if !strings.Contains(source, snippet) {
			t.Fatalf("router.go missing required CLAUDE MVP route mount %q", snippet)
		}
	}
}
