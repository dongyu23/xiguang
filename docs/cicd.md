# 隙光 CI/CD

## 自动链路

1. 后端 PR 或 `main` 推送运行格式检查、`go vet`、race test、覆盖率门槛和 PostgreSQL 集成测试。
2. 测试通过后构建本地候选镜像并执行 Trivy 严重漏洞扫描。
3. `main` 或版本标签构建 GHCR 镜像，写入 SBOM、provenance，并发布 `latest`、版本和短 SHA 标签。
4. `main` 镜像发布成功后，`Production Deployment` 将标签解析为不可变 digest，经 SSH 部署。
5. 服务器执行幂等 `payment-init`，检查 `/healthz`、`/readyz`；失败时恢复上一镜像。

Flutter PR 和 `main` 推送固定使用 Flutter 3.44.8，执行锁文件解析、格式检查、静态分析、全部测试和 Android Debug 编译。
Debug APK 会保存为 Actions artifact，保留 14 天，可直接用于内部安装验证。

## 多平台自动安装包发布

`Android Release` 工作流提供两种入口：

- 推送与 `app/pubspec.yaml` 版本一致的语义化标签，例如 `v0.2.0`，自动创建 GitHub Release。
- 在 Actions 中手动运行，仅构建并保存 30 天 artifact，不创建正式 Release。

正式构建会同时生成：

- GitHub/官网侧载的通用签名 APK。
- ARMv7、ARM64、x86_64 分架构签名 APK。
- Google Play 使用的签名 AAB，以及用于权限核验的 Store APK。
- `SHA256SUMS.txt`。

`Apple and Windows Release` 同时生成：

- Windows x64 完整运行目录 ZIP。
- macOS Intel x64 应用 ZIP。
- macOS Apple Silicon（M 系列）arm64 应用 ZIP。
- iPhone 无签名编译验证 IPA；配置 Apple 签名材料后，额外生成可安装的签名 IPA。
- `SHA256SUMS-apple-windows.txt` 以及每个文件的独立 SHA-256 文件。

Pull Request 会在 GitHub 的 Windows、Intel Mac 和 Apple Silicon Mac 真机 runner 上完成编译验证。版本标签会把各平台产物追加到同一个 GitHub Release，不会覆盖 Android 产物。

侧载 APK 包含应用内更新所需的 `REQUEST_INSTALL_PACKAGES` 权限；Store AAB 在 CI 中验证不得包含该权限。所有 APK 都会经过 `apksigner` 验证，标签版本必须与 `pubspec.yaml` 一致。

配置 Repository Variable：

| 名称 | 示例 |
|---|---|
| `FLUTTER_API_BASE_URL` | `https://example.com/api/v1` |

配置 Repository Secrets：

| 名称 | 说明 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Release JKS 文件的 Base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | JKS 密码 |
| `ANDROID_KEY_ALIAS` | 签名别名 |
| `ANDROID_KEY_PASSWORD` | 私钥密码 |

iPhone 真机安装包必须使用 Apple Developer 证书和描述文件。配置以下 Repository Secrets 后，标签构建会生成 `ios-signed.ipa`：

| 名称 | 说明 |
|---|---|
| `IOS_CERTIFICATE_P12_BASE64` | Apple Development/Distribution `.p12` 的 Base64 内容 |
| `IOS_CERTIFICATE_PASSWORD` | `.p12` 导出密码 |
| `IOS_PROVISIONING_PROFILE_BASE64` | 与 `com.xiguang.xiguang` 匹配的 `.mobileprovision` Base64 内容 |
| `IOS_PROVISIONING_PROFILE_NAME` | 描述文件的精确名称 |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

可选 Repository Variables：

| 名称 | 默认值 | 说明 |
|---|---|---|
| `IOS_CODE_SIGN_IDENTITY` | `Apple Distribution` | 证书身份；开发调试可设为 `Apple Development` |
| `IOS_EXPORT_METHOD` | `ad-hoc` | 可设为 `development`、`ad-hoc` 或 `app-store-connect` |

发布新版本时先更新 `app/pubspec.yaml`：

```yaml
version: 0.3.0+3
```

合并到 `main` 后创建并推送标签：

```bash
git tag -a v0.3.0 -m "隙光 0.3.0"
git push origin v0.3.0
```

## 首次部署

服务器执行：

```bash
curl -fsSL https://raw.githubusercontent.com/dongyu23/xiguang/main/deploy.sh | bash
```

脚本在 `/opt/xiguang` 创建 `.env`，随机生成 JWT、PostgreSQL 和 MinIO 密钥。随后只需填写真实域名、TLS、AI 和支付渠道密钥。

## GitHub 配置

生产部署使用 GitHub Environment `production`。配置以下 Repository Variables：

| 名称 | 示例 | 说明 |
|---|---|---|
| `CD_ENABLED` | `true` | 配置完成后开启自动部署 |
| `CD_SSH_PORT` | `22` | 可省略 |
| `CD_DEPLOY_PATH` | `/opt/xiguang` | 可省略 |
| `CD_PUBLIC_BASE_URL` | `https://example.com` | Environment 展示地址 |
| `CD_PUBLIC_READY_URL` | `https://example.com/readyz` | 可选的公网二次验证 |

配置以下 Repository Secrets：

| 名称 | 说明 |
|---|---|
| `CD_SSH_HOST` | 服务器地址 |
| `CD_SSH_USER` | 具有 Docker 权限的部署账户 |
| `CD_SSH_PRIVATE_KEY` | 部署专用私钥 |
| `CD_SSH_KNOWN_HOSTS` | `ssh-keyscan -H HOST` 的固定结果 |

服务器的业务密钥始终只保存在 `/opt/xiguang/.env` 或 `/opt/xiguang/secrets/`，不会进入 GitHub Actions 日志。

## 手动发布与回滚

在 Actions 中运行 `Production Deployment`，输入任意本仓库 GHCR 标签或 digest。部署脚本始终将其解析/限制为 GHCR 镜像，并在失败时读取：

```text
/opt/xiguang/.deploy/backend-image
```

自动恢复上一成功镜像。成功记录保存在 `/opt/xiguang/.deploy/last-success.txt`。
