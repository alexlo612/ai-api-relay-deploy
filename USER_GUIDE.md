# AI API Relay 操作指南

此 repo 管理 Sub2API、New API、PostgreSQL 與 Redis。正式 checkout 位於
`/srv/stacks/ai-api-relay-deploy`。共用入口、公開連接埠、網域 TLS 和憑證
續期由 `/srv/stacks/vps-infra` 管理。

## 網路與資料

- 此 repo 管理 private `backend` network，讓應用連到 PostgreSQL 和 Redis。
  PostgreSQL、Redis 只加入該 network。
- `sub2api` 和 `new-api` 也加入由 infra 建立及管理的 external network
  `vps-infra_ingress`，供 infra 使用 `sub2api:8080` 和 `new-api:3000` 轉送。
  Relay Compose 只引用並接用該 network，不建立、設定或維護它。
- New API 對外網址為 `https://newapi.byte612.com/`。若更換 hostname，
  除 infra 的 DNS／Nginx／TLS 外，也要同步更新 New API 設定中的
  `ServerAddress` 和 `passkey.origins`，並先檢查已註冊的 Passkeys。
- PostgreSQL 使用獨立的 `sub2api`、`newapi` database 和帳號。Redis DB 0
  給 Sub2API，DB 1 給 New API。
- `docker compose down` 保留 named volumes。不得以 `down -v` 作為日常操作。

## 初始化

在新主機先由 infra 備妥 `vps-infra_ingress`，確認 Docker Compose v2，再設定
受保護的環境檔：

```bash
cd /srv/stacks/ai-api-relay-deploy
# sudo is needed only to create the protected directory under /etc.
sudo install -d -o "$USER" -g "$(id -gn)" -m 700 /etc/vps-infra/secrets/ai-api-relay
install -m 600 .env.example /etc/vps-infra/secrets/ai-api-relay/.env
ln -s /etc/vps-infra/secrets/ai-api-relay/.env .env
```

編輯外部 `.env`：確認映像 tag 並填好所有 `change-me` 值。Hostname 和
ingress routing 由 infra 設定。接著執行：

```bash
make init
make health
```

初始化會保留已有 secret；只替換仍是 placeholder 的值。不要把 `.env` 或
備份複製到 Git。憑證與 hostname routing 由 vps-infra 維護，不要在 Relay
repo 申請第二張憑證或啟動自有 Nginx。

## 日常維運

```bash
make up
make status
make health
make logs SERVICE=sub2api
make logs SERVICE=new-api
make stop
make start
make down
```

`make health` 只檢查 Relay 容器狀態、兩個 app health endpoint、主機磁碟和
容器資源。Ingress、HTTPS、憑證和公開 DNS 都由 infra 管理及檢查。

## 備份與還原

```bash
make backup
make backup-list
make restore FILE=/home/alex/backups/ai-api-relay/backup-YYYYMMDD-HHMMSS.tar.gz
```

備份包含兩份 PostgreSQL dump、Redis volume、兩個 app volume 和 New API
logs，並附 SHA-256 checksum。備份目的地與保留日數由 `.env` 的
`BACKUP_DIR`、`BACKUP_RETENTION_DAYS` 控制。還原會停止 app 與 Redis，並
替換資料；script 驗證 checksum 後仍會要求輸入 `RESTORE`。非互動還原須
明確傳入 `--yes`：

```bash
./scripts/restore.sh --file /home/alex/backups/ai-api-relay/backup-YYYYMMDD-HHMMSS.tar.gz --yes
```

資料庫 schema 可能無法向前相容。升級前保留成功備份；若回退到舊 image，
先還原與該 image 相符的備份。

## Image 更新

已審閱版本列於 Compose image 預設值和 `.env.example`。正式環境從受保護
`.env` 讀取 tag。檢查 upstream release notes、安排維護時段，再執行：

```bash
make update
make health
```

PostgreSQL 和 Redis 使用固定 patch tag；應用版本更新可能執行 database
migration。New API 最新 release 是 RC `v1.0.0-rc.40`；最後查到的正式版是
`v0.13.2`。目前維持已部署的 RC.40，不要直接降到舊正式版。切換版本前先
讀 [官方 release notes](https://github.com/QuantumNous/new-api/releases)，並
完成資料庫相容性與還原演練。

## New API 存取稽核

```bash
make newapi-audit
```

稽核不列出 token 或渠道密鑰。停用帳號仍有啟用 token 時，先查看腳本說明及
確認已有資料庫備份，再決定是否以 `./scripts/revoke-suspended-tokens.sh
--apply` 執行撤銷。

## 排錯

```bash
docker compose config --quiet
docker compose ps
docker compose logs --tail=100 SERVICE
docker compose exec postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
docker compose exec redis redis-cli --no-auth-warning ping
docker stats --no-stream
df -h /srv/stacks /home/alex/backups
```

部署前 CI 和本機檢查命令列於 README。若 ingress、HTTPS 或 DNS 發生問題，
依 infra repo 的流程處理；Relay repo 不管理這些項目。
