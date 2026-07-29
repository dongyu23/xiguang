package service

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/url"
	"strings"
	"time"
)

func (s *Service) Initialize(ctx context.Context) error {
	if !s.cfg.PaymentEnabled {
		s.initialized.Store(true)
		return nil
	}
	if err := s.verifyPublicCallbackRoutes(ctx); err != nil {
		return err
	}
	for _, channel := range s.cfg.PaymentChannels {
		switch channel {
		case "apple":
			ids, err := s.verifyAppleProducts(ctx)
			if err != nil {
				return fmt.Errorf("verify apple products: %w", err)
			}
			if err = s.repo.MarkProviderProductsVerified(ctx, "apple", ids); err != nil {
				return err
			}
		case "wechat", "alipay":
			provider := s.providers[channel]
			if provider == nil {
				return fmt.Errorf("payment provider %s is not installed", channel)
			}
			products, err := s.repo.Catalog(ctx, channel)
			if err != nil {
				return err
			}
			ids, err := provider.VerifyProducts(ctx, products)
			if err != nil {
				return fmt.Errorf("verify %s products: %w", channel, err)
			}
			if err := s.repo.MarkProviderProductsVerified(ctx, channel, ids); err != nil {
				return err
			}
		}
	}
	s.initialized.Store(true)
	ready := s.Readiness(ctx)
	if !ready.Ready {
		s.initialized.Store(false)
		return fmt.Errorf("payment products are not ready: %v", ready.Channels)
	}
	return nil
}

func (s *Service) verifyPublicCallbackRoutes(ctx context.Context) error {
	client := &http.Client{
		Timeout: 10 * time.Second,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	healthReq, err := http.NewRequestWithContext(ctx, http.MethodGet, s.cfg.PaymentPublicBaseURL+"/healthz", nil)
	if err != nil {
		return err
	}
	healthResp, err := client.Do(healthReq)
	if err != nil {
		return fmt.Errorf("verify payment public HTTPS endpoint: %w", err)
	}
	_ = healthResp.Body.Close()
	if healthResp.StatusCode != http.StatusOK {
		return fmt.Errorf("payment public health endpoint returned HTTP %d", healthResp.StatusCode)
	}
	for _, channel := range s.cfg.PaymentChannels {
		request, requestErr := http.NewRequestWithContext(ctx, http.MethodGet,
			s.cfg.PaymentPublicBaseURL+"/api/v1/billing/webhooks/"+url.PathEscape(channel), nil)
		if requestErr != nil {
			return requestErr
		}
		response, requestErr := client.Do(request)
		if requestErr != nil {
			return fmt.Errorf("verify %s callback route: %w", channel, requestErr)
		}
		_ = response.Body.Close()
		if response.StatusCode != http.StatusMethodNotAllowed {
			return fmt.Errorf("%s callback route returned HTTP %d for probe", channel, response.StatusCode)
		}
	}
	return nil
}

func (s *Service) verifyAppleProducts(ctx context.Context) ([]string, error) {
	token, err := appStoreConnectToken(s.cfg.AppleIssuerID, s.cfg.AppleKeyID, s.cfg.ApplePrivateKey)
	if err != nil {
		return nil, err
	}
	client := s.appleConnectHTTPClient
	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}
	baseURL := strings.TrimRight(s.appleConnectBaseURL, "/")
	if baseURL == "" {
		baseURL = "https://api.appstoreconnect.apple.com"
	}
	api := appleConnectAPI{baseURL: baseURL, token: token, client: client}
	if err := api.syncSubscriptions(ctx, s.cfg.AppleAppID); err != nil {
		return nil, err
	}
	ids := make([]string, 0, len(appleSubscriptionCatalog))
	for _, product := range appleSubscriptionCatalog {
		ids = append(ids, product.ProductID)
	}
	return ids, nil
}

type appleSubscriptionDefinition struct {
	ProductID   string
	Name        string
	Description string
	Period      string
	GroupLevel  int
	Price       string
	TrialDays   int
}

var appleSubscriptionCatalog = []appleSubscriptionDefinition{
	{ProductID: "com.xiguang.membership.starlight.month", Name: "星光月付", Description: "20GB 空间、全部主题与白噪音、潮汐提示。", Period: "ONE_MONTH", GroupLevel: 2, Price: "12"},
	{ProductID: "com.xiguang.membership.starlight.year", Name: "星光年付", Description: "20GB 空间、全部主题与白噪音、潮汐提示。", Period: "ONE_YEAR", GroupLevel: 2, Price: "98", TrialDays: 7},
	{ProductID: "com.xiguang.membership.galaxy.month", Name: "星河月付", Description: "100GB 空间、全部会员内容及每计费周期 300 次成功 AI 请求。", Period: "ONE_MONTH", GroupLevel: 1, Price: "28"},
	{ProductID: "com.xiguang.membership.galaxy.year", Name: "星河年付", Description: "100GB 空间、全部会员内容及每计费周期 300 次成功 AI 请求。", Period: "ONE_YEAR", GroupLevel: 1, Price: "218", TrialDays: 7},
}

type appleConnectAPI struct {
	baseURL string
	token   string
	client  *http.Client
}

type appleResource struct {
	Type          string          `json:"type"`
	ID            string          `json:"id,omitempty"`
	Attributes    json.RawMessage `json:"attributes,omitempty"`
	Relationships map[string]struct {
		Data appleResourceRef `json:"data"`
	} `json:"relationships,omitempty"`
}

type appleResourceRef struct {
	Type string `json:"type"`
	ID   string `json:"id"`
}

type appleListResponse struct {
	Data     []appleResource `json:"data"`
	Included []appleResource `json:"included,omitempty"`
	Links    struct {
		Next string `json:"next"`
	} `json:"links"`
}

type appleSingleResponse struct {
	Data appleResource `json:"data"`
}

func (a appleConnectAPI) syncSubscriptions(ctx context.Context, appID string) error {
	groups, err := a.list(ctx, "/v1/apps/"+url.PathEscape(appID)+"/subscriptionGroups?limit=200")
	if err != nil {
		return err
	}
	groupID := ""
	namedGroupID := ""
	productResources := map[string]appleResource{}
	for _, group := range groups {
		var attributes struct {
			ReferenceName string `json:"referenceName"`
		}
		_ = json.Unmarshal(group.Attributes, &attributes)
		products, listErr := a.list(ctx, "/v1/subscriptionGroups/"+url.PathEscape(group.ID)+"/subscriptions?limit=200")
		if listErr != nil {
			return listErr
		}
		containsManagedProduct := false
		for _, product := range products {
			var productAttributes struct {
				ProductID string `json:"productId"`
			}
			_ = json.Unmarshal(product.Attributes, &productAttributes)
			if isManagedAppleProduct(productAttributes.ProductID) {
				containsManagedProduct = true
				productResources[productAttributes.ProductID] = product
			}
		}
		if containsManagedProduct {
			if groupID != "" && groupID != group.ID {
				return errors.New("managed App Store subscriptions are split across subscription groups")
			}
			groupID = group.ID
		} else if attributes.ReferenceName == "隙光会员" {
			namedGroupID = group.ID
		}
	}
	if groupID == "" {
		groupID = namedGroupID
	}
	if groupID == "" {
		created, createErr := a.create(ctx, "/v1/subscriptionGroups", map[string]any{
			"type":       "subscriptionGroups",
			"attributes": map[string]any{"referenceName": "隙光会员"},
			"relationships": map[string]any{
				"app": map[string]any{"data": map[string]string{"type": "apps", "id": appID}},
			},
		})
		if createErr != nil {
			return createErr
		}
		groupID = created.ID
	}
	for _, desired := range appleSubscriptionCatalog {
		resource, ok := productResources[desired.ProductID]
		if !ok {
			created, createErr := a.create(ctx, "/v1/subscriptions", map[string]any{
				"type": "subscriptions",
				"attributes": map[string]any{
					"name": desired.Name, "productId": desired.ProductID, "subscriptionPeriod": desired.Period,
					"familySharable": false, "groupLevel": desired.GroupLevel,
				},
				"relationships": map[string]any{
					"group": map[string]any{"data": map[string]string{"type": "subscriptionGroups", "id": groupID}},
				},
			})
			if createErr != nil {
				return createErr
			}
			resource = created
		}
		if err := a.ensureSubscriptionMetadata(ctx, resource, desired); err != nil {
			return fmt.Errorf("sync subscription %s: %w", desired.ProductID, err)
		}
		if err := a.ensureLocalization(ctx, resource.ID, desired); err != nil {
			return fmt.Errorf("sync localization for %s: %w", desired.ProductID, err)
		}
		if err := a.ensurePrice(ctx, resource.ID, desired.Price); err != nil {
			return fmt.Errorf("sync China price for %s: %w", desired.ProductID, err)
		}
		if desired.TrialDays == 7 {
			if err := a.ensureSevenDayTrial(ctx, resource.ID); err != nil {
				return fmt.Errorf("sync introductory offer for %s: %w", desired.ProductID, err)
			}
		}
	}
	return nil
}

func (a appleConnectAPI) ensureSubscriptionMetadata(ctx context.Context, resource appleResource, desired appleSubscriptionDefinition) error {
	var attributes struct {
		Name               string `json:"name"`
		ProductID          string `json:"productId"`
		SubscriptionPeriod string `json:"subscriptionPeriod"`
		FamilySharable     bool   `json:"familySharable"`
		GroupLevel         int    `json:"groupLevel"`
	}
	if err := json.Unmarshal(resource.Attributes, &attributes); err != nil {
		return errors.New("invalid subscription attributes")
	}
	if attributes.ProductID != desired.ProductID {
		return fmt.Errorf("unexpected product ID %q", attributes.ProductID)
	}
	if attributes.SubscriptionPeriod != desired.Period {
		return fmt.Errorf("period is %s, expected %s", attributes.SubscriptionPeriod, desired.Period)
	}
	if attributes.Name == desired.Name && !attributes.FamilySharable && attributes.GroupLevel == desired.GroupLevel {
		return nil
	}
	return a.update(ctx, "/v1/subscriptions/"+url.PathEscape(resource.ID), map[string]any{
		"type": "subscriptions", "id": resource.ID,
		"attributes": map[string]any{
			"name": desired.Name, "familySharable": false, "groupLevel": desired.GroupLevel,
		},
	})
}

func isManagedAppleProduct(productID string) bool {
	for _, product := range appleSubscriptionCatalog {
		if product.ProductID == productID {
			return true
		}
	}
	return false
}

func (a appleConnectAPI) ensureLocalization(ctx context.Context, subscriptionID string, desired appleSubscriptionDefinition) error {
	items, err := a.list(ctx, "/v1/subscriptions/"+url.PathEscape(subscriptionID)+"/subscriptionLocalizations?limit=200")
	if err != nil {
		return err
	}
	for _, item := range items {
		var attributes struct {
			Name        string `json:"name"`
			Locale      string `json:"locale"`
			Description string `json:"description"`
		}
		_ = json.Unmarshal(item.Attributes, &attributes)
		if attributes.Locale != "zh-Hans" {
			continue
		}
		if attributes.Name == desired.Name && attributes.Description == desired.Description {
			return nil
		}
		return a.update(ctx, "/v1/subscriptionLocalizations/"+url.PathEscape(item.ID), map[string]any{
			"type": "subscriptionLocalizations", "id": item.ID,
			"attributes": map[string]string{"name": desired.Name, "description": desired.Description},
		})
	}
	_, err = a.create(ctx, "/v1/subscriptionLocalizations", map[string]any{
		"type":       "subscriptionLocalizations",
		"attributes": map[string]string{"name": desired.Name, "locale": "zh-Hans", "description": desired.Description},
		"relationships": map[string]any{
			"subscription": map[string]any{"data": map[string]string{"type": "subscriptions", "id": subscriptionID}},
		},
	})
	return err
}

func (a appleConnectAPI) ensurePrice(ctx context.Context, subscriptionID, customerPrice string) error {
	points, err := a.list(ctx, "/v1/subscriptions/"+url.PathEscape(subscriptionID)+"/pricePoints?filter%5Bterritory%5D=CHN&limit=200")
	if err != nil {
		return err
	}
	pricePointID := ""
	for _, point := range points {
		var attributes struct {
			CustomerPrice string `json:"customerPrice"`
		}
		_ = json.Unmarshal(point.Attributes, &attributes)
		if normalizeApplePrice(attributes.CustomerPrice) == normalizeApplePrice(customerPrice) {
			pricePointID = point.ID
			break
		}
	}
	if pricePointID == "" {
		return fmt.Errorf("App Store Connect has no CHN price point for CNY %s", customerPrice)
	}
	prices, err := a.list(ctx, "/v1/subscriptions/"+url.PathEscape(subscriptionID)+"/prices?filter%5Bterritory%5D=CHN&include=subscriptionPricePoint&limit=200")
	if err != nil {
		return err
	}
	for _, price := range prices {
		if relation, ok := price.Relationships["subscriptionPricePoint"]; ok && relation.Data.ID == pricePointID {
			return nil
		}
	}
	_, err = a.create(ctx, "/v1/subscriptionPrices", map[string]any{
		"type":       "subscriptionPrices",
		"attributes": map[string]any{"preserved": false},
		"relationships": map[string]any{
			"subscription":           map[string]any{"data": map[string]string{"type": "subscriptions", "id": subscriptionID}},
			"subscriptionPricePoint": map[string]any{"data": map[string]string{"type": "subscriptionPricePoints", "id": pricePointID}},
		},
	})
	return err
}

func normalizeApplePrice(value string) string {
	value = strings.TrimSpace(value)
	value = strings.TrimRight(value, "0")
	return strings.TrimRight(value, ".")
}

func (a appleConnectAPI) ensureSevenDayTrial(ctx context.Context, subscriptionID string) error {
	offers, err := a.list(ctx, "/v1/subscriptions/"+url.PathEscape(subscriptionID)+"/introductoryOffers?filter%5Bterritory%5D=CHN&limit=200")
	if err != nil {
		return err
	}
	for _, offer := range offers {
		var attributes struct {
			Duration        string `json:"duration"`
			OfferMode       string `json:"offerMode"`
			NumberOfPeriods int    `json:"numberOfPeriods"`
		}
		_ = json.Unmarshal(offer.Attributes, &attributes)
		if attributes.Duration == "ONE_WEEK" && attributes.OfferMode == "FREE_TRIAL" && attributes.NumberOfPeriods == 1 {
			return nil
		}
	}
	_, err = a.create(ctx, "/v1/subscriptionIntroductoryOffers", map[string]any{
		"type":       "subscriptionIntroductoryOffers",
		"attributes": map[string]any{"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
		"relationships": map[string]any{
			"subscription": map[string]any{"data": map[string]string{"type": "subscriptions", "id": subscriptionID}},
			"territory":    map[string]any{"data": map[string]string{"type": "territories", "id": "CHN"}},
		},
	})
	return err
}

func (a appleConnectAPI) list(ctx context.Context, path string) ([]appleResource, error) {
	endpoint := a.absoluteURL(path)
	var result []appleResource
	for endpoint != "" {
		var decoded appleListResponse
		if err := a.doJSON(ctx, http.MethodGet, endpoint, nil, &decoded); err != nil {
			return nil, err
		}
		result = append(result, decoded.Data...)
		endpoint = a.absoluteURL(decoded.Links.Next)
	}
	return result, nil
}

func (a appleConnectAPI) create(ctx context.Context, path string, data map[string]any) (appleResource, error) {
	var decoded appleSingleResponse
	err := a.doJSON(ctx, http.MethodPost, a.absoluteURL(path), map[string]any{"data": data}, &decoded)
	return decoded.Data, err
}

func (a appleConnectAPI) update(ctx context.Context, path string, data map[string]any) error {
	return a.doJSON(ctx, http.MethodPatch, a.absoluteURL(path), map[string]any{"data": data}, &appleSingleResponse{})
}

func (a appleConnectAPI) absoluteURL(path string) string {
	if strings.TrimSpace(path) == "" {
		return ""
	}
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		return path
	}
	return strings.TrimRight(a.baseURL, "/") + "/" + strings.TrimLeft(path, "/")
}

func (a appleConnectAPI) doJSON(ctx context.Context, method, endpoint string, payload any, dst any) error {
	var requestBody io.Reader
	if payload != nil {
		encoded, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		requestBody = strings.NewReader(string(encoded))
	}
	req, err := http.NewRequestWithContext(ctx, method, endpoint, requestBody)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+a.token)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := a.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	responseBody, _ := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("App Store Connect HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(responseBody)))
	}
	if len(responseBody) > 0 && json.Unmarshal(responseBody, dst) != nil {
		return errors.New("invalid App Store Connect response")
	}
	return nil
}

func fetchAppleJSON(ctx context.Context, client *http.Client, endpoint, token string, dst any) error {
	return (appleConnectAPI{token: token, client: client}).doJSON(ctx, http.MethodGet, endpoint, nil, dst)
}

func appStoreConnectToken(issuerID, keyID, encodedKey string) (string, error) {
	return appStoreToken(issuerID, keyID, encodedKey, "")
}

func appStoreServerToken(issuerID, keyID, encodedKey, bundleID string) (string, error) {
	return appStoreToken(issuerID, keyID, encodedKey, bundleID)
}

func appStoreToken(issuerID, keyID, encodedKey, bundleID string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(encodedKey)
	if err != nil {
		raw = []byte(encodedKey)
	}
	block, _ := pem.Decode(raw)
	if block == nil {
		return "", errors.New("APPLE_PRIVATE_KEY_BASE64 is not a PEM key")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return "", err
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return "", errors.New("Apple key must be ECDSA")
	}
	now := time.Now().Unix()
	header, _ := json.Marshal(map[string]any{"alg": "ES256", "kid": keyID, "typ": "JWT"})
	claims := map[string]any{"iss": issuerID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
	if bundleID != "" {
		claims["bid"] = bundleID
	}
	claimBytes, _ := json.Marshal(claims)
	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(claimBytes)
	digest := sha256.Sum256([]byte(unsigned))
	r, sig, err := ecdsa.Sign(rand.Reader, key, digest[:])
	if err != nil {
		return "", err
	}
	signature := append(padBigInt(r, 32), padBigInt(sig, 32)...)
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature), nil
}
func padBigInt(value *big.Int, size int) []byte {
	raw := value.Bytes()
	out := make([]byte, size)
	copy(out[size-len(raw):], raw)
	return out
}
