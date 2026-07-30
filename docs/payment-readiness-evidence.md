# 隙光付费功能上线证据矩阵

本文对应《中国双端付费功能开发计划》。结论中的“已完成”指代码、自动化与本地模拟环境已经具备；真实商户、App Store 审核和真机渠道验收仍属于平台强制人工步骤。

## 商品、订阅与权益

| 要求 | 状态 | 证据 |
|---|---|---|
| 微光、星光、星河固定价格与权益 | 已完成 | `005_billing.sql`、`billing_schema.go`、`service/catalog.go`；`TestValidateConfiguredCatalogRequiresExactFixedCatalog` |
| 年付 7 天试用与跨账号防重复 | 已完成 | `trial_redemptions`；`TestAnnualAgreementTrialThenFirstCharge`、`TestAnnualTrialCannotBeRedeemedBySamePayerAcrossAccounts`、`TestAppleIntroductoryOfferCreatesTrialingEntitlement` |
| 单账号仅一个有效订阅、跨渠道保护 | 已完成 | 数据库部分唯一索引、事务行锁；`TestApplePurchaseRejectsExistingDirectSubscription`、Flutter `cross-channel purchase` 测试 |
| 取消、退款、宽限、撤销状态 | 已完成 | 统一状态机与退款保留；`TestDirectDebitSimulatedTrialRenewalRetriesRecoveryCancelAndExpiry`、`TestRefundKeepsRevokedStatusVisibleAfterDowngrade`、会员页 Widget 测试 |
| 旧体验会员清除 | 已完成 | `membership_repository.dart`；`clears legacy trial keys before loading server membership` |

## 渠道与订单

| 要求 | 状态 | 证据 |
|---|---|---|
| Apple 签名交易、通知 V2、恢复、升级降级、退款、每日对账 | 已完成 | `apple_jws.go`、`apple_reconcile.go`、`apple_connect.go`；Apple smoke 集成测试覆盖购买、续费、取消、退款、恢复、跨账号拒绝 |
| 微信委托代扣 | 已完成 | 官方 API v3 SDK、平台证书验签、AES-GCM、APP 预签约、扣款、查询、解约；微信 Provider 与通知集成测试 |
| 支付宝周期扣款 | 已完成 | RSA2、证书模式、官方 Android `PayTask`、签约、扣款、查询、解约；支付宝 Provider 与通知集成测试 |
| 回调幂等、乱序、金额校验、加密原文 | 已完成 | `payment_events` 唯一约束、失败重认领、事务处理；回放/乱序集成测试、`TestEncryptPayloadDoesNotStorePlaintext` |
| 0/24/48 小时重试和 72 小时宽限 | 已完成 | `ClaimDueRenewals`、`FailRenewal`、数据库租约与 advisory lock；直接渠道模拟 E2E |
| 日志不泄露完整渠道订单号 | 已完成 | `ChannelError` 仅返回稳定错误码；`TestChannelErrorNeverReturnsProviderPayload` |

## 权益与配额

| 要求 | 状态 | 证据 |
|---|---|---|
| 媒体预签名、确认、普通上传按真实对象大小计费 | 已完成 | `storage.Provider.StatObject`、媒体 service 测试 |
| 归档恢复不能绕过空间配额 | 已完成 | `archiveimport.prepareMedia`；归档 PostgreSQL 集成测试按真实大小拒绝并删除非法对象 |
| 并发空间预留不超额 | 已完成 | `storage_reservations`；`TestConcurrentStorageReservationCannotExceedQuota`、首次权益行漏算测试 |
| AI 仅成功请求扣次数 | 已完成 | `ReserveAI`/`ReleaseAI`；服务测试覆盖内容不足、Provider 失败、解析失败返还次数，PostgreSQL 测试覆盖并发配额 |
| 主题、白噪音、潮汐由服务端权益控制 | 已完成 | 对应 handler/service 注入 `EntitlementService` 及测试；ASR 未接入 AI 配额 |
| 离线权益仅展示主题与白噪音 | 已完成 | Ed25519 72 小时快照；本地主题与白噪音目录，离线主题测试；主题切换、上传、AI 仍需在线 |

## 客户端与发布门禁

| 要求 | 状态 | 证据 |
|---|---|---|
| iOS StoreKit 2 购买、pending、完成、恢复、管理订阅 | 已完成（静态与模拟） | `in_app_purchase_storekit`、购买监听与服务端核验；Controller 测试。Windows 无法代替 TestFlight 真机验收 |
| Android 微信/支付宝官方 SDK，SDK 返回不直接开权益 | 已完成 | 受控 `MethodChannel`、微信 OpenSDK、支付宝官方 SDK；购买后轮询服务端订单 |
| 商店包移除自更新安装权限与 Google Billing | 已完成 | `store`/`sideload` flavor；APK 扫描中两个权限/Google Billing 均为 0，官方渠道 SDK 存在 |
| HTTPS、正式签名、MinIO 私有、注销清理 | 已完成到配置门禁 | 支付启用要求 TLS；release 缺签名变量直接失败；MinIO 清空匿名策略；注销媒体清理测试 |

## 配置、初始化与监控

| 要求 | 状态 | 证据 |
|---|---|---|
| 环境变量及 `_FILE` | 已完成 | `.env.example`、`config.go`、Compose；`TestEnvSupportsFileValues` |
| `payment-init` 幂等目录初始化和脱敏诊断 | 已完成 | 一次性容器；Apple 商品自动创建，直连渠道配置核验；本地退出码 0 |
| 生产配置失效关闭 | 已完成 | 支付启用时任何环境均校验密钥和 HTTPS；生产拒绝 sandbox；启动先撤销旧验证标记，成功前购买关闭且 `/readyz` 为 503 |
| `/readyz` 检查迁移、固定目录和渠道映射 | 已完成 | `catalog` 与逐渠道状态；PostgreSQL 测试覆盖缺映射、字段篡改和未验证 |
| 支付监控 | 已完成 | `/metrics` 覆盖订单、通知、延迟、验签、续费、对账和权益不一致；Apple 使用 `signedDate` |

## 最终自动化命令

```text
flutter analyze
flutter test
docker build --target test -t xiguang-backend-test ./backend
go test -p 1 ./internal/archiveimport ./internal/billing/service ./internal/billing/repository
flutter build apk --debug --flavor store
docker compose config --quiet
docker compose up -d --build --force-recreate
GET /healthz, /readyz, /metrics
MinIO anonymous request => HTTP 403
git diff --check
```

## 仅剩人工与真实变量

1. Apple、微信、支付宝主体实名、协议签署及自动续费资质审核。
2. 填写 `.env` 或对应 `_FILE` 密钥、渠道计划 ID、产品码、TLS 与 Android release 签名参数。
3. Apple 通知地址登记、商品提交审核及 TestFlight 真机验收。
4. 微信、支付宝真实测试商户和小比例生产账号验收。

以上步骤完成前保持未获批渠道不出现在 `PAYMENT_CHANNELS`；代码无需再次修改或手工执行 SQL。
