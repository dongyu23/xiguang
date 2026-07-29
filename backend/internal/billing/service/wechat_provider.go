package service

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/wechatpay-apiv3/wechatpay-go/core"
	"github.com/wechatpay-apiv3/wechatpay-go/core/auth/verifiers"
	"github.com/wechatpay-apiv3/wechatpay-go/core/downloader"
	wechatnotify "github.com/wechatpay-apiv3/wechatpay-go/core/notify"
	"github.com/wechatpay-apiv3/wechatpay-go/core/option"
	"github.com/wechatpay-apiv3/wechatpay-go/utils"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/infra/config"
)

type WeChatProvider struct {
	cfg config.Config

	mu            sync.Mutex
	client        wechatAPIClient
	notifyHandler *wechatnotify.Handler
}

type wechatAPIClient interface {
	Post(context.Context, string, interface{}) (*core.APIResult, error)
	Get(context.Context, string) (*core.APIResult, error)
}

func NewWeChatProvider(cfg config.Config) *WeChatProvider { return &WeChatProvider{cfg: cfg} }

func (p *WeChatProvider) Name() string { return "wechat" }

func (p *WeChatProvider) VerifyProducts(ctx context.Context, products []domain.Product) ([]string, error) {
	if _, _, err := p.ensure(ctx); err != nil {
		return nil, err
	}
	if strings.TrimSpace(p.cfg.WeChatPayPlanID) == "" {
		return nil, errors.New("WECHAT_PAY_PLAN_ID is empty")
	}
	ids := make([]string, 0, len(products))
	for _, product := range products {
		if product.ExternalProductID == "" {
			return nil, fmt.Errorf("missing WeChat mapping for %s", product.Code)
		}
		ids = append(ids, product.ExternalProductID)
	}
	return ids, nil
}

func (p *WeChatProvider) StartAgreement(ctx context.Context, order domain.Order, product domain.Product) (map[string]any, error) {
	client, _, err := p.ensure(ctx)
	if err != nil {
		return nil, err
	}
	body := map[string]any{
		"appid":             p.cfg.WeChatPayAppID,
		"mchid":             p.cfg.WeChatPayMerchantID,
		"plan_id":           p.cfg.WeChatPayPlanID,
		"out_contract_code": order.PublicID,
		"user_display_name": "隙光会员 " + product.Code,
		"notify_url":        p.cfg.PaymentPublicBaseURL + "/api/v1/billing/webhooks/wechat",
	}
	result, err := client.Post(ctx, p.endpoint(p.cfg.WeChatPayContractPath), body)
	if err != nil {
		return nil, err
	}
	var response struct {
		PreEntrustWebID string `json:"pre_entrustweb_id"`
	}
	if err = core.UnMarshalResponse(result.Response, &response); err != nil {
		return nil, err
	}
	if response.PreEntrustWebID == "" {
		return nil, errors.New("WeChat pre-entrust response contains no pre_entrustweb_id")
	}
	return map[string]any{
		"app_id":            p.cfg.WeChatPayAppID,
		"business_type":     12,
		"pre_entrustweb_id": response.PreEntrustWebID,
		"method":            "open_business_webview",
	}, nil
}

func (p *WeChatProvider) Charge(ctx context.Context, candidate domain.RenewalCandidate) (string, time.Time, error) {
	client, _, err := p.ensure(ctx)
	if err != nil {
		return "", time.Time{}, err
	}
	outTradeNo := renewalOutTradeNo(candidate)
	body := map[string]any{
		"appid":        p.cfg.WeChatPayAppID,
		"mchid":        p.cfg.WeChatPayMerchantID,
		"description":  "隙光会员 " + candidate.Product.Code,
		"out_trade_no": outTradeNo,
		"notify_url":   p.cfg.PaymentPublicBaseURL + "/api/v1/billing/webhooks/wechat",
		"contract_id":  candidate.ExternalSubscriptionID,
		"amount": map[string]any{
			"total":    candidate.Product.PriceCents,
			"currency": candidate.Product.Currency,
		},
	}
	result, err := client.Post(ctx, p.endpoint(p.cfg.WeChatPayChargePath), body)
	if err != nil {
		return "", time.Time{}, err
	}
	var response struct {
		TransactionID string `json:"transaction_id"`
		TradeState    string `json:"trade_state"`
		SuccessTime   string `json:"success_time"`
	}
	if err = core.UnMarshalResponse(result.Response, &response); err != nil {
		return "", time.Time{}, err
	}
	if response.TransactionID == "" || (response.TradeState != "SUCCESS" && response.TradeState != "") {
		return "", time.Time{}, fmt.Errorf("WeChat charge is not successful: %s", response.TradeState)
	}
	paidAt, err := time.Parse(time.RFC3339, response.SuccessTime)
	if err != nil {
		paidAt = time.Now().UTC()
	}
	return response.TransactionID, paidAt.UTC(), nil
}

func (p *WeChatProvider) QueryCharge(ctx context.Context, candidate domain.RenewalCandidate) (string, time.Time, bool, error) {
	client, _, err := p.ensure(ctx)
	if err != nil {
		return "", time.Time{}, false, err
	}
	path := strings.ReplaceAll(p.cfg.WeChatPayQueryPath, "{out_trade_no}", url.PathEscape(renewalOutTradeNo(candidate)))
	separator := "?"
	if strings.Contains(path, "?") {
		separator = "&"
	}
	result, err := client.Get(ctx, p.endpoint(path)+separator+"mchid="+url.QueryEscape(p.cfg.WeChatPayMerchantID))
	if err != nil {
		if strings.Contains(err.Error(), "ORDER_NOT_EXIST") || strings.Contains(err.Error(), "RESOURCE_NOT_EXISTS") {
			return "", time.Time{}, false, nil
		}
		return "", time.Time{}, false, err
	}
	var response struct {
		TransactionID string `json:"transaction_id"`
		TradeState    string `json:"trade_state"`
		SuccessTime   string `json:"success_time"`
	}
	if err = core.UnMarshalResponse(result.Response, &response); err != nil {
		return "", time.Time{}, false, err
	}
	if response.TradeState != "SUCCESS" || response.TransactionID == "" {
		return "", time.Time{}, false, nil
	}
	paidAt, err := time.Parse(time.RFC3339, response.SuccessTime)
	if err != nil {
		paidAt = time.Now().UTC()
	}
	return response.TransactionID, paidAt.UTC(), true, nil
}

func (p *WeChatProvider) Cancel(ctx context.Context, agreementID string) error {
	client, _, err := p.ensure(ctx)
	if err != nil {
		return err
	}
	path := strings.ReplaceAll(p.cfg.WeChatPayCancelPath, "{contract_id}", url.PathEscape(agreementID))
	result, err := client.Post(ctx, p.endpoint(path), map[string]string{"mchid": p.cfg.WeChatPayMerchantID})
	if err != nil {
		return err
	}
	if result.Response != nil && result.Response.Body != nil {
		_ = result.Response.Body.Close()
	}
	return nil
}

func (p *WeChatProvider) ParseNotification(ctx context.Context, request *http.Request, content any) (*wechatnotify.Request, error) {
	_, handler, err := p.ensure(ctx)
	if err != nil {
		return nil, err
	}
	return handler.ParseNotifyRequest(ctx, request, content)
}

func (p *WeChatProvider) ensure(ctx context.Context) (wechatAPIClient, *wechatnotify.Handler, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.client != nil && p.notifyHandler != nil {
		return p.client, p.notifyHandler, nil
	}
	privateMaterial := strings.TrimSpace(p.cfg.WeChatPayPrivateKey)
	if decoded, err := base64.StdEncoding.DecodeString(privateMaterial); err == nil {
		privateMaterial = string(decoded)
	}
	privateKey, err := utils.LoadPrivateKey(privateMaterial)
	if err != nil {
		return nil, nil, err
	}
	client, err := core.NewClient(ctx, option.WithWechatPayAutoAuthCipher(
		p.cfg.WeChatPayMerchantID,
		p.cfg.WeChatPayCertSerial,
		privateKey,
		p.cfg.WeChatPayAPIV3Key,
	))
	if err != nil {
		return nil, nil, err
	}
	visitor := downloader.MgrInstance().GetCertificateVisitor(p.cfg.WeChatPayMerchantID)
	verifier := verifiers.NewSHA256WithRSAVerifier(visitor)
	handler, err := wechatnotify.NewRSANotifyHandler(p.cfg.WeChatPayAPIV3Key, verifier)
	if err != nil {
		return nil, nil, err
	}
	p.client, p.notifyHandler = client, handler
	return client, handler, nil
}

func (p *WeChatProvider) endpoint(path string) string {
	if strings.HasPrefix(path, "https://") {
		return path
	}
	return p.cfg.WeChatPayAPIBase + "/" + strings.TrimLeft(path, "/")
}
