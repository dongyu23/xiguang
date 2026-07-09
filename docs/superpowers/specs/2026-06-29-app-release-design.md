# 在线更新模块设计（app_release / app_update）

> 用 module-developer 流程产出。本 spec 是"设计已落地代码"的回溯固化，方便后续维护与扩展。

## 业务对象

唯一核心对象 **AppRelease**：一次客户端版本发布。
- version（展示用）/ build_number（比较用，唯一依据）
- channel（stable/beta/canary，一期只用 stable）/ platform（android/ios，一期只用 android）
- apk_file_name + apk_size_bytes + sha256（APK 存 Nginx 静态目录，不入 MinIO）
- min_supported_build + force_update（强更策略）
- release_note
- published_at / deleted_at（软删除，可追溯）

不引入的对象：Channel 独立表（用枚举）、Device/Installation（不追踪设备）、ReleaseDownloadLog（不做下载统计）、User×Release 忽略记录（客户端 SharedPreferences）。

## 关系

独立对象，不与任何业务模块强关联。只依赖 shared + infra。APK 文件不进 media_files 表——公开资产走直链，可被 HTTP 缓存。

## 生命周期

- **创建（发布）**：文件先 scp 到 Nginx 目录 → `POST /admin/releases` → service 校验文件存在 + SHA-256 + build 递增 + 路径穿越防护 → INSERT。
- **查询（普通用户）**：`GET /app/version?channel=&platform=` → FindLatest → PublicView。无发布返回 data:null，前端容错。
- **查询（piggyback）**：`/users/me` 响应里带 `meta.latest_build / min_supported_build`，零额外请求拿到提示。
- **改策略**：`PATCH /admin/releases/{id}` 只允许改 release_note / force_update / min_supported_build。version/build/apk 不可变。
- **下架**：`DELETE /admin/releases/{id}` 软删除。下架后查询回退到上一个未下架版本。

## 存储

- PostgreSQL `app_releases` 表（migration 002）。`(channel, platform, build_number)` 唯一。`idx_app_releases_latest` 部分索引。
- `users.is_admin BOOLEAN` 列。
- Nginx 静态目录 `/media/app/` serve APK。
- 不加 Redis 缓存——版本接口 QPS 极低，直接走 PG。

## 接口

公开：`GET /api/v1/app/version`
管理（需 admin）：`GET/POST/PATCH/DELETE /api/v1/admin/releases[/{public_id}]`

## 边界

✅ 做：客户端轮询 + piggyback、Nginx 静态分发、SHA-256 校验、强更、admin 鉴权。
❌ 不做：长连接推送、FCM/极光、灰度、增量包、断点续传、下载统计、iOS（字段保留）。

## 选型理由

- 推送方式：客户端轮询 + piggyback。自有服务器、不引第三方、符合"不打扰"产品边界。
- APK 存储：Nginx 静态目录。公开资产、直链、不污染 MinIO。
- 版本对比：只比 build_number（INT）。简单可靠，不解析 SemVer。
- 管理员：JWT + 查 `is_admin`。不放 claims——降权即时生效。
