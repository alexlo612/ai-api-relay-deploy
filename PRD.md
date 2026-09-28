# AI API Relay 部署需求

**版本：** v1.0（2026-09-28）
**狀態：** 本文件描述此 repo 的目標部署；VPS 實際狀態及驗證證據見
[`docs/current-state.md`](docs/current-state.md)。

## 1. 範圍與責任

本 repo 在單台 4 GB Hetzner VPS 部署 Sub2API、New API、PostgreSQL 與
Redis。它只管理 app 容器、資料、設定、備份及 app 層檢查；不包含上游
app 原始碼。

獨立的 `/srv/stacks/vps-infra` repo 管理共用 Nginx、主機公開 ports
80／443、hostname TLS、ACME challenge 及憑證續期。各 repo 有自己的 Git
checkout、Compose project 及資料 owner。Relay 不 clone 或更新 infra repo。

## 2. 正式主機配置

- Relay checkout：`/srv/stacks/ai-api-relay-deploy`
- Compose project：`ai-api-relay`
- Compose secret 檔：`/etc/vps-infra/secrets/ai-api-relay/.env`，mode `0600`
- repo 內 `.env` 是指向上列外部 secret 檔的 symlink。
- Relay 備份：`/home/alex/backups/ai-api-relay/`（由 `alex` 管理，不需 sudo）
- 私有 `backend` network 由 Relay 管理；共用 `vps-infra_ingress` 由 infra
  建立及管理，Relay 只將兩個 web app 接上該 external network。
- 正式 hostname：`sub2api.byte612.com` 與 `api.byte612.com`。

Relay Compose 只有四個服務：

| Service | Networks | Container port | Persistent volume |
|---|---|---:|---|
| `sub2api` | `backend`, `vps-infra_ingress` | 8080 | `/app/data` |
| `new-api` | `backend`, `vps-infra_ingress` | 3000 | `/data`, `/app/logs` |
| `postgres` | `backend` | 5432 | PostgreSQL data |
| `redis` | `backend` | 6379 | Redis AOF data |

Relay 管理 private `backend` network。四個服務都使用此 network，讓兩個 app
連到 PostgreSQL 和 Redis；只有兩個 app 另外加入 `vps-infra_ingress`。Relay
只將 ingress 宣告為 external 並接用，不建立、設定或檢查該 network。PostgreSQL
和 Redis 不得加入 ingress，也不得 publish host ports。

Infra Nginx 的 routes 必須使用 `sub2api:8080` 及 `new-api:3000`。Relay
不得啟動第二個公開 Nginx 或 Certbot、不得管理 hostname TLS，也不得
要求 app 使用 host network 或固定容器 IP。

## 3. Compose 與設定

- `compose.yaml` 是 Relay 唯一的 runtime 定義，不含 obsolete `version` 欄位。
- Makefile 是常用 Compose 及 script 入口；可直接用 Docker Compose 排錯。
- Compose project 固定為 `ai-api-relay`，讓 checkout 移動後仍沿用原有 volumes。
- 正式 image 必須指定固定 tag；不使用 `latest`。版本預設值寫在
  `compose.yaml`，實際部署使用的 tag 記錄在受保護的 `.env`。
- 每個長期執行服務定義 `restart`、資源限制、日誌輪替、最小權限設定和
  有效 healthcheck。應用須等 PostgreSQL 和 Redis healthy 才啟動。
- 設定可在 `.env` 修改；範例和用途記錄於 `.env.example`。Secret 不進 Git。

目前選定的服務版本：

| Service image | 固定 tag | 備註 |
|---|---|---|
| `weishaw/sub2api` | `0.2.9` | stable；升級須先備份並檢查 migration |
| `calciumion/new-api` | `v1.0.0-rc.40` | 最新 RC；`v0.13.2` 是較舊正式版。維持現行 tag，避免未驗證的降版 |
| `postgres` | `16.15-alpine` | PostgreSQL 16 patch release |
| `redis` | `7.4.11-alpine` | Redis 7.4 patch release |

PostgreSQL 為兩個應用建立獨立 database 及帳號。Redis 啟用 AOF 和密碼，
Sub2API 使用 DB 0、New API 使用 DB 1。應用 data、PostgreSQL、Redis 和
New API logs 都用 Compose named volumes 持久化。

截至 2026-09-28，上游 Release 頁將 `v1.0.0-rc.40` 標為最新 release；
`v0.13.2` 是最後查到的非 RC 正式版，發布於 2026-04-27。RC.40 不是
stable。由於現行部署已使用 RC.40，建議維持該 tag，等 v1.0.0 正式版或
完成獨立相容性與還原演練後再評估切換。參考：
[官方 release list](https://github.com/QuantumNous/new-api/releases)、
[v0.13.2](https://github.com/QuantumNous/new-api/releases/tag/v0.13.2)、
[v1.0.0-rc.40](https://github.com/QuantumNous/new-api/releases/tag/v1.0.0-rc.40)。

## 4. Secret、備份與復原

- `.env` 由使用者建立並保護；`make init` 不得覆寫已有 secret。
- `docker compose down` 保留資料；不可將刪除 volumes 用作部署、更新或
  還原的常規步驟。
- `make backup` 匯出兩份 PostgreSQL database，封存 Redis 及兩個 app 的
  volumes，產生 SHA-256 checksum，並依保留期清除舊備份。
- 備份寫入 `BACKUP_DIR`，此 VPS 預設路徑為 `/home/alex/backups/ai-api-relay/`。
- `make restore FILE=...` 必須驗 checksum、明確指定檔案及取得互動確認，
  還原前停止會寫入目標資料的服務。
- image 或 DB schema 升級前先備份。需要 schema rollback 時，從相符備份
  復原，不能假設較舊 image 可讀取新 schema。

## 5. 健康與維運

- 每個長期服務都有 Docker healthcheck；app 使用 `/health` 及 `/api/status`。
- `make health` 顯示 Relay 容器狀態、app endpoints、磁碟與容器資源。
- Ingress network、routes、TLS certificate、DNS、CDN 和防火牆檢查都由
  infra 管理，不屬於 Relay healthcheck。
- `make update` 先建立備份，再 pull `.env` 指定版本、重建容器並執行健康檢查。
- Relay 只接用 infra 建立的 external ingress network；只有 infra owner
  維護該 network、Nginx routes 和憑證。
- New API audit script 不可輸出 token、密鑰或密碼。

## 6. 驗收基準

部署完成時確認：

- [x] Repo 與 Compose project 使用正式路徑及名稱。
- [x] 四個 Relay containers healthy，使用固定且確認過的 image tags。
- [x] 僅兩個 app service 接入 `vps-infra_ingress`。
- [x] PostgreSQL、Redis 無 host port，僅在 `backend` network。
- [x] Relay 將兩個 app 接到 infra 管理的 external ingress network；Relay
  不建立或修改該 network。
- [x] named volumes 在 checkout 移動及一般 Compose recreate 後仍被使用。
- [ ] 備份 checksum 成功，且乾淨環境的 restore 已演練。
- [x] Compose、ShellCheck、YAML、Nginx config、secret scan 與健康檢查結果有紀錄。
- [x] `/home/alex/ai-api-relay-deploy` 不再保有部署用 `.env` 或 active Relay containers。

## 7. 明確不包含

- Relay 自有公開 Nginx、hostname TLS 或 Certbot renewal。
- Kubernetes、多主機、高可用、外部備份供應商或應用程式功能修改。
- Relay repo 管理 infra firewall、systemd、DNS provider 或 vps-infra 設定。
- 自動執行 app schema migration 的回滾。

DNS、防火牆、TLS hostname 或 infra upstream 設定若要改動，另循 infra repo
流程處理；app-specific 設定和維護留在此 repo。
