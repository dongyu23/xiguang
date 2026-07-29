package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"xiguang/backend/internal/billing"
	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/infra/db"
	"xiguang/backend/internal/infra/router"
)

func main() {
	cfg := config.Load()
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		if err := runHealthcheck(cfg.Port); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	if len(os.Args) > 1 && os.Args[1] == "payment-init" {
		if err := runPaymentInit(cfg); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println("payment catalog verified")
		return
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("database connect failed", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router.New(pool, cfg),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		slog.Info("xiguang backend listening", "port", cfg.Port, "env", cfg.Env)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server failed", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		slog.Error("server shutdown failed", "error", err)
	}
}

func runPaymentInit(cfg config.Config) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()
	module := billing.NewInitializer(pool, cfg)
	if err := module.Service.Initialize(ctx); err != nil {
		return err
	}
	report := module.Service.Readiness(ctx)
	encoded, _ := json.Marshal(report)
	fmt.Printf("payment-init diagnostics: %s\n", encoded)
	return nil
}

func runHealthcheck(port string) error {
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/healthz")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("healthcheck returned HTTP %d", resp.StatusCode)
	}
	return nil
}
