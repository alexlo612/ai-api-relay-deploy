# AI API Relay Web 操作指南

本指南說明如何在單台 4 GB RAM Hetzner VPS 上，以 Docker Compose 部署與維運 Sub2API、New API、Nginx、Certbot、共用 PostgreSQL、共用 Redis。

## 1. 部署模式

### 1.1 IP 模式

初期使用 VPS public IP 與兩個 HTTPS port：

- Sub2API：`https://89.167.21.176:8080`
- New API：`https://89.167.21.176:3000`

兩個 port 都由 Nginx 接收，再代理至 Docker 內部應用。Sub2API 與 New API 容器本身不 publish host port。

IP 模式使用 Let's Encrypt short-lived IP certificate。此類憑證有效期約 6 天，因此至少每 12 小時應執行一次 renewal。建議以 Hetzner Firewall 或 UFW 限制 3000/8080 的來源 IP。

### 1.2 Domain 模式

日後取得網域後使用：

- Sub2API：`https://sub2api.your-domain.com`
- New API：`https://newapi.your-domain.com`

Domain 模式只 publish 80/443，不再公開 3000/8080。

## 2. VPS prerequisites

建議環境：

- Ubuntu 24.04 LTS 或 Debian 12
- Docker Engine 26+ 與 Docker Compose v2 plugin
- `make`、`openssl`、`curl`、`gettext-base` 或提供 `envsubst` 的套件
- 4 GB RAM、至少 20 GB disk、2–4 GB swap
- SSH 只允許管理員 IP
- Port 80 必須公開供 ACME HTTP-01 challenge 使用

安裝 Docker 請依 Docker 官方文件操作。部署前可用：

```bash
docker --version
docker compose version
free -h
df -h
```

## 3. 共用 PostgreSQL 與 Redis

為節省 4 GB VPS RAM，只運行一個 PostgreSQL 容器及一個 Redis 容器，但資料隔離：

- PostgreSQL：Sub2API 與 New API 使用不同 database、user、password。
- Redis：Sub2API 使用 DB 0；New API 使用 DB 1。

PostgreSQL 與 Redis 不 publish host port。

## 4. 首次安裝

```bash
cp .env.example .env
chmod 600 .env
nano .env
make init
```

`make init` 會：

1. 生成仍為 placeholder 的 secret，且不覆寫既有非 placeholder 值。
2. 驗證 `.env`。
3. Render Redis 與 Nginx config。
4. 執行 `docker compose config`。
5. 啟動 stack。
6. 執行健康檢查。

首次 TLS 建議先用 staging：

```dotenv
LETSENCRYPT_STAGING=true
```

```bash
make enable-tls
```

staging 成功後改為：

```dotenv
LETSENCRYPT_STAGING=false
```

再執行：

```bash
make enable-tls
```

## 5. 日常操作

啟動或套用設定：

```bash
make up
```

底層仍可直接使用：

```bash
docker compose up -d
```

查看狀態與健康：

```bash
make status
make health
```

查看 logs：

```bash
make logs
make logs SERVICE=sub2api
make logs SERVICE=new-api
make logs SERVICE=nginx
```

暫停及恢復：

```bash
make stop
make start
```

重新啟動：

```bash
make restart
make restart SERVICE=new-api
```

停止並移除容器，但保留所有資料：

```bash
make down
```

不要隨意執行 `docker compose down -v`；`-v` 會刪除 PostgreSQL、Redis、應用資料、憑證與 ACME state volumes。

## 6. TLS 與 certificate renewal

手動 issuance 或 renewal：

```bash
make enable-tls
./scripts/certbot.sh renew
./scripts/certbot.sh expiry
```

IP certificate 使用 Certbot 5.4+ 的 `--ip-address` 與 `--preferred-profile shortlived`。若 renewal 成功，script 會先執行 `nginx -t`，再 reload Nginx。

建議在 VPS 上用 cron 或 systemd timer 每 12 小時執行：

```bash
cd /opt/ai-api-relay && ./scripts/certbot.sh renew >> /var/log/ai-api-relay-certbot.log 2>&1
```

## 7. 從 IP 切換至 Domain 模式

1. 建立兩個 DNS A record 指向 VPS IPv4。
2. 若 IPv6 未正確配置，不建立 AAAA record。
3. 修改 `.env`：

   ```dotenv
   DEPLOYMENT_MODE=domain
   SUB2API_DOMAIN=sub2api.your-domain.com
   NEW_API_DOMAIN=newapi.your-domain.com
   LETSENCRYPT_EMAIL=you@example.com
   LETSENCRYPT_STAGING=true
   ```

4. 測試 staging certificate：

   ```bash
   make enable-tls
   ```

5. staging 成功後將 `LETSENCRYPT_STAGING=false`，再次執行 `make enable-tls`。
6. 驗證 HTTPS 後，在 firewall 關閉公網 3000/8080。

切換模式不會清除 PostgreSQL、Redis 或 application volumes。

## 8. 更新與回滾

更新前先修改 `.env` 中的 image tag，再執行：

```bash
make update
```

流程：

1. 驗證設定。
2. 建立本機備份。
3. Pull `.env` 指定的 image tag。
4. Recreate 有變更的 container。
5. 執行健康檢查。

回滾時，將 `.env` image tag 改回上一個已知正常版本：

```bash
make up
make health
```

若上游已執行不可逆 database migration，需從更新前備份還原。

## 9. 備份與還原

```bash
make backup
make backup-list
make restore FILE=backups/backup-YYYYMMDD-HHMMSS.tar.gz
```

備份內容：

- Sub2API PostgreSQL dump
- New API PostgreSQL dump
- Sub2API `/app/data`
- New API `/data` 與 `/app/logs`
- SHA-256 checksum

TLS certificate 可重新申請，不視為最關鍵備份資料。

還原前 script 會驗證 checksum 並要求確認。若要非互動執行，可直接使用：

```bash
./scripts/restore.sh --file backups/backup-YYYYMMDD-HHMMSS.tar.gz --yes
```

## 10. Firewall

IP 測試模式：

| Port | 用途 | 建議來源 |
|---:|---|---|
| 22 | SSH | 只允許管理員 IP |
| 80 | ACME challenge | 公開 |
| 3000 | New API via Nginx | 只允許信任 IP |
| 8080 | Sub2API via Nginx | 只允許信任 IP |

Domain 公開模式：

| Port | 用途 | 建議來源 |
|---:|---|---|
| 22 | SSH | 只允許管理員 IP |
| 80 | ACME、HTTPS redirect | 公開 |
| 443 | HTTPS Web/API | 公開 |

PostgreSQL 5432 與 Redis 6379 不可向公網開放。

## 11. 排錯

```bash
make status
make health
make logs
docker compose config
docker compose exec nginx nginx -t
docker compose stats
```

某服務持續 unhealthy：

```bash
make logs SERVICE=服務名稱
docker inspect --format '{{json .State.Health}}' 容器名稱
```

檢查資料庫與 Redis：

```bash
docker compose exec postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
docker compose exec redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping
```

檢查記憶體與 OOM：

```bash
free -h
docker stats --no-stream
docker inspect --format '{{.State.OOMKilled}}' 容器名稱
```

## 12. Repository checks

```bash
./scripts/validate-env.sh
docker compose config
shellcheck scripts/*.sh postgres/init/*.sh
```

CI 會執行 Compose config、ShellCheck、YAML lint、Markdown lint、secret scan 與 Nginx config test。

## 13. New API 私人使用與定價稽核

私人分享模式建議關閉公開註冊、演示站點及新用戶免費額度。不要把 New API
管理 token 或渠道密鑰放進 Git；只為朋友建立個別帳號及有限額 token。
定期檢查：

```bash
make newapi-audit
./scripts/revoke-suspended-tokens.sh
```

稽核只顯示開關、數量與啟用渠道的模型計價覆蓋情形，不顯示 token 或渠道密鑰。
若已停用帳號仍有啟用 token，可先檢查完整資料庫備份空間，再執行：

```bash
./scripts/revoke-suspended-tokens.sh --apply
```

此命令會在忽略 Git 的 `backups/` 目錄建立及驗證 New API 資料庫備份，
只停用已停用、非 `admin`、`alex-user-test`、`alex-user-test-02` 帳號的啟用 token。
New API 的 Redis token 快取可能短暫保留舊狀態；已停用帳號仍應被帳號狀態阻擋。

New API 的系統設定／倍率設定有「同步上游倍率」，可比較上游
`/api/ratio_config`、`/api/pricing`、OpenRouter 及內建 `models.dev` 價格預設。
它能提供新模型價格候選值，但不是 OpenAI、Anthropic 官方價格的保證，
也不能推斷 `claude-opus` 等自訂別名對應哪個實際上游型號。
不要未經審核就批量覆寫既有 `tiered_expr` 計費。
新模型上線時，先確認渠道路由、實際上游型號及官方輸入／輸出／快取價格，
再預覽同步差異或在管理介面設定計費，最後執行 `make newapi-audit`。
稽核中的 `UNSET` 代表沒有明確的模型價格或倍率；
Self-use mode 可能套用預設倍率，應先核對再開放朋友使用。
稽核亦顯示啟用帳號持有的無限額、永不到期和未限制模型的 token 數量。
依朋友的使用需求設定明確額度與期限，避免憑證外洩後產生無上限費用；
管理員自己的 token 亦應分用途建立、定期撤銷。不要在未決定每人預算前
任意套用同一額度。

## 14. Claude Code 相容模型別名

`config/model-bindings.json` 定義 New API 對外提供的三個自訂別名：
`claude-fable` 對應 `gpt-6-astra`、`claude-opus` 對應 `gpt-6-sol`、
`claude-sonnet` 對應 `gpt-6-luna`。這些名稱只是 Claude Code 相容入口，
實際上游是 OpenAI 模型，不是 Anthropic 官方 Claude 模型 ID 或價格。
不要隨 Anthropic 發布新版型號，自動改動這些別名的上游目標。

Sub2API OpenAI 群組負責 Messages dispatch 映射；New API 維持公開模型名、
channel 和對外計價。New API 的 model mapping 保持空白，避免兩層重複
將 Claude 別名改成不同的實際型號。別名價格由對應 GPT-6 型號的
`ModelRatio`、`CompletionRatio`、快取倍率、`billing_mode` 與
`billing_expr` 複製而來；不以 Anthropic 官方價格計價。

在 VPS 上先檢查，再套用：

```bash
make model-bindings-check
make model-bindings-apply
```

套用命令會在忽略 Git 的 `backups/model-bindings-*/` 建立兩份 PostgreSQL
dump 和 SHA-256 checksum，更新 New API 計價後短暫重啟該服務，
再透過 Sub2API admin API 更新群組。管理 API key 預設讀取
`~/.config/ai-api-relay/sub2api-admin-api-key`，也可用
`SUB2API_ADMIN_API_KEY_FILE` 指定 mode `0600` 的檔案。指令不會輸出 key。
套用失敗不會自動還原資料；應先檢查狀態和備份，再按還原指南操作。
