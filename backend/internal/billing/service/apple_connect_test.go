package service

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"xiguang/backend/internal/infra/config"
)

type fakeAppleConnect struct {
	mu            sync.Mutex
	groups        []map[string]any
	subscriptions map[string]map[string]any
	localizations map[string]map[string]any
	prices        map[string]string
	trials        map[string]map[string]any
}

func newFakeAppleConnect() *fakeAppleConnect {
	return &fakeAppleConnect{
		subscriptions: map[string]map[string]any{},
		localizations: map[string]map[string]any{},
		prices:        map[string]string{},
		trials:        map[string]map[string]any{},
	}
}

func (f *fakeAppleConnect) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	if !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}
	path := r.URL.Path
	switch {
	case r.Method == http.MethodGet && path == "/v1/apps/app-1/subscriptionGroups":
		writeAppleList(w, f.groups)
	case r.Method == http.MethodPost && path == "/v1/subscriptionGroups":
		resource := readAppleData(r)
		resource["id"] = "group-1"
		f.groups = append(f.groups, resource)
		writeAppleSingle(w, resource)
	case r.Method == http.MethodGet && path == "/v1/subscriptionGroups/group-1/subscriptions":
		items := make([]map[string]any, 0, len(f.subscriptions))
		for _, item := range f.subscriptions {
			items = append(items, item)
		}
		writeAppleList(w, items)
	case r.Method == http.MethodPost && path == "/v1/subscriptions":
		resource := readAppleData(r)
		attributes := resource["attributes"].(map[string]any)
		productID := attributes["productId"].(string)
		resource["id"] = fmt.Sprintf("subscription-%d", len(f.subscriptions)+1)
		f.subscriptions[productID] = resource
		writeAppleSingle(w, resource)
	case r.Method == http.MethodPatch && strings.HasPrefix(path, "/v1/subscriptions/"):
		resource := readAppleData(r)
		for productID, existing := range f.subscriptions {
			if existing["id"] != resource["id"] {
				continue
			}
			existingAttributes := existing["attributes"].(map[string]any)
			for key, value := range resource["attributes"].(map[string]any) {
				existingAttributes[key] = value
			}
			existing["attributes"] = existingAttributes
			f.subscriptions[productID] = existing
			writeAppleSingle(w, existing)
			return
		}
		http.NotFound(w, r)
	case r.Method == http.MethodGet && strings.HasSuffix(path, "/subscriptionLocalizations"):
		subscriptionID := subscriptionIDFromPath(path)
		if item := f.localizations[subscriptionID]; item != nil {
			writeAppleList(w, []map[string]any{item})
		} else {
			writeAppleList(w, nil)
		}
	case r.Method == http.MethodPost && path == "/v1/subscriptionLocalizations":
		resource := readAppleData(r)
		resource["id"] = fmt.Sprintf("localization-%d", len(f.localizations)+1)
		subscriptionID := relationshipID(resource, "subscription")
		f.localizations[subscriptionID] = resource
		writeAppleSingle(w, resource)
	case r.Method == http.MethodPatch && strings.HasPrefix(path, "/v1/subscriptionLocalizations/"):
		resource := readAppleData(r)
		for subscriptionID, existing := range f.localizations {
			if existing["id"] == resource["id"] {
				existing["attributes"] = resource["attributes"]
				f.localizations[subscriptionID] = existing
				writeAppleSingle(w, existing)
				return
			}
		}
		http.NotFound(w, r)
	case r.Method == http.MethodGet && strings.HasSuffix(path, "/pricePoints"):
		subscriptionID := subscriptionIDFromPath(path)
		price := f.priceForSubscription(subscriptionID)
		writeAppleList(w, []map[string]any{{
			"type": "subscriptionPricePoints", "id": "point-" + subscriptionID,
			"attributes": map[string]any{"customerPrice": price},
		}})
	case r.Method == http.MethodGet && strings.HasSuffix(path, "/prices"):
		subscriptionID := subscriptionIDFromPath(path)
		pointID := f.prices[subscriptionID]
		if pointID == "" {
			writeAppleList(w, nil)
		} else {
			writeAppleList(w, []map[string]any{{
				"type": "subscriptionPrices", "id": "price-" + subscriptionID,
				"relationships": map[string]any{
					"subscriptionPricePoint": map[string]any{"data": map[string]any{"type": "subscriptionPricePoints", "id": pointID}},
				},
			}})
		}
	case r.Method == http.MethodPost && path == "/v1/subscriptionPrices":
		resource := readAppleData(r)
		subscriptionID := relationshipID(resource, "subscription")
		f.prices[subscriptionID] = relationshipID(resource, "subscriptionPricePoint")
		resource["id"] = "price-" + subscriptionID
		writeAppleSingle(w, resource)
	case r.Method == http.MethodGet && strings.HasSuffix(path, "/introductoryOffers"):
		subscriptionID := subscriptionIDFromPath(path)
		if item := f.trials[subscriptionID]; item != nil {
			writeAppleList(w, []map[string]any{item})
		} else {
			writeAppleList(w, nil)
		}
	case r.Method == http.MethodPost && path == "/v1/subscriptionIntroductoryOffers":
		resource := readAppleData(r)
		subscriptionID := relationshipID(resource, "subscription")
		resource["id"] = "trial-" + subscriptionID
		f.trials[subscriptionID] = resource
		writeAppleSingle(w, resource)
	default:
		http.Error(w, r.Method+" "+path, http.StatusNotFound)
	}
}

func (f *fakeAppleConnect) priceForSubscription(subscriptionID string) string {
	for _, product := range f.subscriptions {
		if product["id"] != subscriptionID {
			continue
		}
		productID := product["attributes"].(map[string]any)["productId"].(string)
		for _, desired := range appleSubscriptionCatalog {
			if desired.ProductID == productID {
				return desired.Price + ".00"
			}
		}
	}
	return "0.00"
}

func subscriptionIDFromPath(path string) string {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) >= 3 {
		return parts[2]
	}
	return ""
}

func relationshipID(resource map[string]any, name string) string {
	relationships := resource["relationships"].(map[string]any)
	relationship := relationships[name].(map[string]any)
	data := relationship["data"].(map[string]any)
	return data["id"].(string)
}

func readAppleData(r *http.Request) map[string]any {
	var body struct {
		Data map[string]any `json:"data"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		panic(err)
	}
	return body.Data
}

func writeAppleList(w http.ResponseWriter, data []map[string]any) {
	_ = json.NewEncoder(w).Encode(map[string]any{"data": data, "links": map[string]any{"next": ""}})
}

func writeAppleSingle(w http.ResponseWriter, data map[string]any) {
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{"data": data})
}

func appleTestPrivateKey(t *testing.T) string {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	encoded, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	pemValue := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: encoded})
	return base64.StdEncoding.EncodeToString(pemValue)
}

func TestAppleProductInitializationCreatesAndReusesCatalog(t *testing.T) {
	fake := newFakeAppleConnect()
	server := httptest.NewServer(fake)
	defer server.Close()
	service := New(nil, config.Config{
		AppleAppID:      "app-1",
		AppleIssuerID:   "issuer-1",
		AppleKeyID:      "key-1",
		ApplePrivateKey: appleTestPrivateKey(t),
	})
	service.appleConnectBaseURL = server.URL
	service.appleConnectHTTPClient = server.Client()

	for attempt := 0; attempt < 2; attempt++ {
		ids, err := service.verifyAppleProducts(t.Context())
		if err != nil {
			t.Fatalf("attempt %d: %v", attempt+1, err)
		}
		if len(ids) != 4 {
			t.Fatalf("attempt %d returned %d products", attempt+1, len(ids))
		}
	}

	fake.mu.Lock()
	defer fake.mu.Unlock()
	if len(fake.groups) != 1 || len(fake.subscriptions) != 4 || len(fake.localizations) != 4 || len(fake.prices) != 4 || len(fake.trials) != 2 {
		t.Fatalf("unexpected synchronized catalog: groups=%d subscriptions=%d localizations=%d prices=%d trials=%d",
			len(fake.groups), len(fake.subscriptions), len(fake.localizations), len(fake.prices), len(fake.trials))
	}
}
