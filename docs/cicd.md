# 隙光 CI/CD

## 自动链路

1. 后端 PR 或 `main` 推送运行格式检查、`go vet`、race test、覆盖率门槛和 PostgreSQL 集成测试。
2. 测试通过后构建本地候选镜像并执行 Trivy 严重漏洞扫描。
3. `main` 或版本标签构建 GHCR 镜像，写入 SBOM、provenance，并发布 `latest`、版本和短 SHA 标签。
4. `main` 镜像发布成功后，`Production Deployment` 将标签解析为不可变 digest，经 SSH 部署。
5. 服务器执行幂等 `payment-init`，检查 `/healthz`、`/readyz`；失败时恢复上一镜像。

Flutter PR 和 `main` 推送固定使用 Flutter 3.44.8，执行锁文件解析、格式检查、静态分析、全部测试和 Android Debug 编译。

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
