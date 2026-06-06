package router

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStaticModulesUseCLAUDELayeredStructure(t *testing.T) {
	for _, module := range []string{"emotion", "space", "whitenoise"} {
		for _, layer := range []string{"domain", "service", "handler"} {
			assertModuleLayer(t, module, layer)
		}
	}
}

func TestRepositoryBackedModulesUseCLAUDELayeredStructure(t *testing.T) {
	for _, module := range []string{"ai", "auth", "fragment", "island", "media", "relation", "starmap", "stats", "sync", "tag", "timeline"} {
		for _, layer := range []string{"domain", "repository", "service", "handler"} {
			assertModuleLayer(t, module, layer)
		}
	}
}

func TestAuthModuleKeepsJWTMiddlewareLayer(t *testing.T) {
	assertModuleLayer(t, "auth", "middleware")
}

func TestCLAUDEExtendedModuleLayersExist(t *testing.T) {
	for _, spec := range []struct {
		module string
		layer  string
	}{
		{"ai", "provider"},
		{"island", "rules"},
		{"media", "processor"},
		{"media", "storage"},
		{"starmap", "graph"},
		{"stats", "cache"},
	} {
		assertModuleLayer(t, spec.module, spec.layer)
	}
}

func TestCLAUDEInfraLayersExist(t *testing.T) {
	for _, layer := range []string{"config", "db", "logger", "redis", "router", "storage"} {
		path := filepath.Join("..", layer)
		info, err := os.Stat(path)
		if err != nil {
			t.Fatalf("infra missing %s layer at %s: %v", layer, path, err)
		}
		if !info.IsDir() {
			t.Fatalf("%s exists but is not a directory", path)
		}
	}
}

func assertModuleLayer(t *testing.T, module, layer string) {
	t.Helper()
	path := filepath.Join("..", "..", module, layer)
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("%s module missing %s layer at %s: %v", module, layer, path, err)
	}
	if !info.IsDir() {
		t.Fatalf("%s exists but is not a directory", path)
	}
}
