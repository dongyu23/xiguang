# 隙光支付部署与运营说明

## 当前可用范围

- Apple IAP 已接通服务端交易验签、订阅与权益更新、Server Notifications V2、恢复购买、退款撤销、重复及乱序通知保护。
- 支付宝周期扣款已接入 RSA2 签约串、Android 官方 `PayTask`、异步通知验签、首扣/续费、退款撤权和 0/24/48 小时重试。启用前必须取得周期扣款资质并填写获批的 `ALIPAY_PERSONAL_PRODUCT_CODE`。
- 微信委托代扣已接入官方 API v3 请求签名、平台证书验签、AES-GCM 通知解密、APP 预签约、周期扣款、查询对账和解约。只有商户主体取得对应资质并填写渠道分配的 `WECHAT_PAY_PLAN_ID` 后才允许开放；普通 APP 支付不能替代自动续费。
- `PAYMENT_CHANNELS` 中不要填写尚未获批的渠道。未启用渠道不会出现在客户端的可购买入口，也不影响已有会员权益读取。

## 部署者需要填写的变量

从 `.env.example` 复制生产配置并填写：

```dotenv
APP_ENV=production
PAYMENT_ENABLED=true
PAYMENT_ENV=production
PAYMENT_CHANNELS=apple
PAYMENT_PUBLIC_BASE_URL=https://你的域名
PAYMENT_DATA_ENCRYPTION_KEY=至少32字符的随机值

APPLE_BUNDLE_ID=com.xiguang.xiguang
APPLE_APP_ID=App Store Connect中的数字资源ID
APPLE_ISSUER_ID=
APPLE_KEY_ID=
APPLE_PRIVATE_KEY_BASE64=

TLS_CERT_BASE64=
TLS_KEY_BASE64=
```

通用支付配置、渠道资源 ID、证书和密钥均支持同名 `_FILE` 变量。渠道 API 地址、接口路径、`ALIPAY_SIGN_SCENE` 与 `ALIPAY_GATEWAY` 是非敏感覆盖项，使用普通环境变量即可。使用 `_FILE` 时不要再填写对应的普通变量，例如：

```dotenv
PAYMENT_DATA_ENCRYPTION_KEY_FILE=/run/secrets/payment_data_key
APPLE_PRIVATE_KEY_BASE64_FILE=/run/secrets/apple_private_key_base64
```

Compose 已将项目根目录的 `secrets/` 只读挂载到 `/run/secrets`，并在 `.gitignore` 中排除该目录。部署者只需把密钥文件放入该目录并填写对应 `*_FILE=/run/secrets/...`，无需修改 Compose。

Flutter 依赖更新后，需要在具备 Flutter SDK 的构建机执行一次 `flutter pub get`，以同步 `app/pubspec.lock`。本仓库不提交或下载 Flutter SDK。

生产环境还必须填写 `.env.example` 中的数据库、JWT、MinIO、CORS 与 Android 正式签名变量。证书或私钥不得提交到 Git。

## Apple 平台配置

`payment-init` 会通过 App Store Connect API 幂等创建或核验同一个订阅组内的以下四个自动续期订阅：

| 商品 ID | 价格与周期 | 试用 |
|---|---|---|
| `com.xiguang.membership.starlight.month` | ¥12/月 | 无 |
| `com.xiguang.membership.starlight.year` | ¥98/年 | 7 天 introductory offer |
| `com.xiguang.membership.galaxy.month` | ¥28/月 | 无 |
| `com.xiguang.membership.galaxy.year` | ¥218/年 | 7 天 introductory offer |

App Store Server Notifications V2 地址：

```text
https://你的域名/api/v1/billing/webhooks/apple
```

沙箱和生产环境应分别配置通知地址。通知地址登记和商品提交审核属于 Apple 强制人工流程；订阅组、商品、中国区价格、简体中文本地化和年付 7 天免费试用由初始化任务维护。`PAYMENT_ENV` 必须与收到的交易环境一致。

## 启动和验收

```powershell
docker compose config --quiet
docker compose up -d --build
curl.exe -fsS https://你的域名/readyz
```

`payment-init` 会幂等执行全部数据库迁移、写入固定商品目录，通过 App Store Connect API 创建或核验 Apple 订阅组、四个商品、简体中文文案、中国区价格和年付 7 天免费试用，并校验微信官方 API、支付宝 RSA 私钥、公钥证书和周期扣款产品码。应用进程启动时先将启用渠道置为未验证，并在公网回调可用后完成同样的幂等核验；核验成功前购买接口关闭、`/readyz` 返回 503，已有会员权益仍可读取。密钥错误、生产环境没有 HTTPS、商品字段不一致或渠道核验失败时，初始化或就绪检查会失败，应用不会带病开放支付。初始化完成后会输出不含密钥的 JSON 诊断。服务启动时及之后每 24 小时会调用 App Store Server API 对账当前有效 Apple 订阅；微信/支付宝续费 worker 使用数据库租约和行锁避免重复扣款。

除通用密钥外，渠道资质审核通过后还需填写平台下发的资源标识：

- `WECHAT_PAY_PLAN_ID`：微信委托代扣计划 ID。
- `WECHAT_PAY_*_PATH`：默认使用 API v3 扣费服务路径；若资格审核后台下发专属路径，可只改环境变量，无需改代码。
- `ALIPAY_PERSONAL_PRODUCT_CODE`：支付宝周期扣款个人产品码。
- `ALIPAY_APP_PUBLIC_CERT_BASE64`：开放平台下载的应用公钥证书；系统会校验它与应用私钥匹配并自动计算证书序列号。
- `ALIPAY_SIGN_SCENE`：签约场景，默认 `INDUSTRY|DEFAULT`，以商户后台获批值为准。
- `ALIPAY_GATEWAY`：可留空，系统会随 `PAYMENT_ENV` 自动选择生产或沙箱网关；生产模式检测到沙箱地址会拒绝启动。

上述资源 ID、证书和密钥均支持同名 `_FILE` 形式；渠道 API 地址、接口路径、`ALIPAY_SIGN_SCENE` 与 `ALIPAY_GATEWAY` 使用普通环境变量。

`/readyz` 的支付部分应满足：

```json
{
  "enabled": true,
  "ready": true,
  "mode": "production",
  "catalog": "configured",
  "channels": {"apple": "configured"}
}
```

`catalog` 会在支付关闭的迁移部署阶段同样检查账单表和四个固定商品目录。响应只返回状态，不返回密钥、证书或完整订单号。

运营监控可抓取：

```text
GET /metrics
```

指标覆盖订单状态、回调处理与重复通知、回调延迟、验签失败、续费失败、对账修复以及权益与有效订阅不一致数量。

## 发布前人工步骤

以下事项属于渠道和商店的强制人工流程，无法由 Compose 或代码代办：

1. 完成 Apple、微信、支付宝主体实名、协议签署与代扣资质审核。
2. 在 App Store Connect 登记 App Store Server Notifications V2 地址，并提交初始化任务创建的订阅商品审核。
3. 使用 TestFlight 真机验证首次购买、续费、取消、退款、恢复购买和跨设备登录。
4. Android 使用 `storeRelease` 构建正式商店包；仅 `sideload` 变体保留应用内安装更新权限。
5. 小比例生产账号观察订单成功率、通知延迟、验签失败和权益一致性后再全量开放。

微信或支付宝获批后，只需把渠道下发的委托代扣计划 ID、周期扣款产品码和证书写入对应环境变量。代码、数据库和 Compose 不需要再次修改；未获资质的渠道不要加入 `PAYMENT_CHANNELS`。
