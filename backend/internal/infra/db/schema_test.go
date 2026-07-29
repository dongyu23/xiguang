package db

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"testing"
)

var requiredTables = []string{
	"users",
	"fragments",
	"tags",
	"fragment_tags",
	"media_files",
	"relations",
	"islands",
	"island_fragments",
	"refresh_tokens",
	"oplog",
	"ai_requests",
	"ai_artifacts",
	"island_groups",
	"island_group_members",
}

var requiredEnums = []string{
	"fragment_status",
	"media_type",
	"island_status",
}

func TestRuntimeSchemaContainsCLAUDECoreTables(t *testing.T) {
	assertSchemaContainsTables(t, "runtime schema", schema+billingSchema+aiAssistanceSchema, requiredTables)
	assertSchemaContainsEnums(t, "runtime schema", schema, requiredEnums)
}

func TestMigrationFileContainsCLAUDECoreTables(t *testing.T) {
	paths, err := filepath.Glob(filepath.Join("..", "..", "..", "migrations", "*.sql"))
	if err != nil || len(paths) == 0 {
		t.Fatalf("list migrations: %v", err)
	}
	var migration string
	for _, path := range paths {
		raw, readErr := os.ReadFile(path)
		if readErr != nil {
			t.Fatalf("read migration: %v", readErr)
		}
		migration += "\n" + string(raw)
	}
	path := "all migrations"

	assertSchemaContainsTables(t, path, migration, requiredTables)
	assertSchemaContainsEnums(t, path, migration, requiredEnums)

	runtimeTables := createTableNames(schema + billingSchema + aiAssistanceSchema)
	migrationTables := createTableNames(migration)
	if diff := missing(runtimeTables, migrationTables); len(diff) > 0 {
		t.Fatalf("migration has tables not present in runtime schema: %v", diff)
	}
	if diff := missing(migrationTables, runtimeTables); len(diff) > 0 {
		t.Fatalf("runtime schema has tables not present in migration: %v", diff)
	}
}

func assertSchemaContainsTables(t *testing.T, label, sql string, tables []string) {
	t.Helper()
	found := createTableNames(sql)
	if diff := missing(tables, found); len(diff) > 0 {
		t.Fatalf("%s missing required tables: %v", label, diff)
	}
}

func assertSchemaContainsEnums(t *testing.T, label, sql string, enums []string) {
	t.Helper()
	found := createTypeNames(sql)
	if diff := missing(enums, found); len(diff) > 0 {
		t.Fatalf("%s missing required enum types: %v", label, diff)
	}
}

func createTableNames(sql string) []string {
	return captureNames(regexp.MustCompile(`(?i)CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+([a-z_]+)`), sql)
}

func createTypeNames(sql string) []string {
	return captureNames(regexp.MustCompile(`(?i)CREATE\s+TYPE\s+([a-z_]+)\s+AS\s+ENUM`), sql)
}

func captureNames(re *regexp.Regexp, sql string) []string {
	matches := re.FindAllStringSubmatch(sql, -1)
	names := make([]string, 0, len(matches))
	for _, match := range matches {
		names = append(names, match[1])
	}
	sort.Strings(names)
	return names
}

func missing(want, got []string) []string {
	gotSet := make(map[string]bool, len(got))
	for _, item := range got {
		gotSet[item] = true
	}
	diff := []string{}
	for _, item := range want {
		if !gotSet[item] {
			diff = append(diff, item)
		}
	}
	sort.Strings(diff)
	return diff
}
