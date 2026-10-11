# Current deployment evidence

## 2026-10-11 核對與同步進行中

以下為 2026-10-11 的新觀察；下文各節保留原日期的歷史結果，不能把
2026-10-01 的 Payment OFF、空白首頁或 runtime `0.2.11` 當作現況。

- Sub2API 管理頁顯示 `v0.2.15`；自訂 ByteAPI 首頁已載入，繁體充值 FAQ
  答案為「支援微信支付或信用卡」。支付設定已啟用，Stripe CNY 實例勾選
  銀行卡及微信支付；最低 ¥5、最高 ¥1000、充值倍率 1 CNY 入帳 1 USD。
  充值頁幫助文本提供付款步驟與客服微信，沒有 WeChat Pay HK 相容性註記。
  這是 UI 設定與顯示查核，未於本輪執行付款、退款或 webhook 測試。
- VPS 以 `alex` 唯讀檢查：四容器均 healthy、無公開 host ports；Compose
  image 仍是 `weishaw/sub2api:0.2.9`，但容器執行檔 `-version` 回報
  `0.2.15`（commit `f2669c8cf62555cd92389b3f55920e9e6e7c6ff2`）。
  五個 app／資料 named volumes 仍在；另有兩個舊 infra 遺留 volumes，
  本次不處理。VPS checkout 的 `config/sub2api/` 有三個未追蹤歷史 HTML，
  同步時須保留。
- 查核時 `origin/main` 已包含首頁 v3 的 PR #7，VPS checkout 尚未更新；
  上游最新正式 Sub2API release 為 `v0.2.15`（2026-10-09 發布）。
  本次預備改用固定映像 `0.2.15`，保留舊備份並先建立新備份。
- New API 上游在 2026-10-10 發布 RC.43；本部署仍固定 RC.40，未在本輪
  變更。下文 2026-09-28 稱 RC.40 為最新，僅代表當時查核結果。

## New API public hostname

**Observed:** 2026-10-02 08:24 UTC, on the deployment host as `alex`.
The infra Nginx route serves New API at
`https://newapi.byte612.com/api/status`: local origin and public Cloudflare
requests both returned HTTP 200. Public DNS for `api.byte612.com` now returns
NXDOMAIN, so infra removed the temporary old-host redirect and reissued the
certificate for newapi/sub2api only. Certificate and renewal checks are
recorded in the infra repo.

New API's persisted `ServerAddress` and `passkey.origins` were changed from
the old hostname to the new hostname in one PostgreSQL transaction. Passkey
login was disabled and `passkey_credentials` had zero rows before the change.
Only the `new-api` container was restarted to load the settings; it and the
other three Relay containers were healthy afterward. `/api/status` reports
`server_address=https://newapi.byte612.com` and
the Passkey RP ID is `newapi.byte612.com`. The Relay Compose definition and ingress
network attachment did not change.

## Direct observation before the move

**Observed:** 2026-09-28 UTC, on `ubuntu-4gb-hel1-01` as `alex`.
**Scope:** local Docker state, checkout metadata, configured images, local origin
and public hostname requests. Secret values, application data, firewall rules,
and DNS provider settings were not read.

- The Relay project was running as `ai-api-relay` from
  `/home/alex/ai-api-relay-deploy/compose.yaml`. The checkout and remote `main`
  both pointed to `173db9a` (`Connect Relay backends to shared ingress`).
- Sub2API `0.1.138`, New API `v1.0.0-rc.40`, PostgreSQL `16.10-alpine`, Redis
  `7.4.5-alpine`, Certbot `v5.4.0`, and Relay Nginx `1.29.1-alpine` were
  configured. Sub2API, New API, PostgreSQL, and Redis were healthy; Relay
  Nginx was stopped. No Relay service was listening on host ports 3000/8080.
- Both apps were connected to `vps-infra_ingress`; only the apps joined that
  external network. The project also had private `backend` and `edge` networks.
- Compose volumes existed for both databases, Redis, both apps, logs, Certbot
  certificates, and the shared ACME webroot. The infra repo also referenced
  `ai-api-relay_acme_webroot`; that volume must remain intact.
- Local requests through infra Nginx returned HTTP 200 for
  `https://api.byte612.com/api/status` and
  `https://sub2api.byte612.com/health`. Requests to the same hostnames through
  the public Cloudflare path returned HTTP 403 with `cf-mitigated: challenge`.
  This shows the local origin routes were working; public client access still
  needs an external check.
- The old `.env` described IP mode and placeholder domains although infra
  routed `api.byte612.com` and `sub2api.byte612.com`. This made the old health
  script test the wrong endpoints. `/var/backups/vps-infra` did not yet exist.

## Migration and update result

**Completed:** 2026-09-28 14:50 UTC, on `ubuntu-4gb-hel1-01` as `alex`.

- Relay now runs from `/srv/stacks/ai-api-relay-deploy` with Compose project
  `ai-api-relay`. All four containers report healthy. The old checkout remains
  for reference, with its deployment `.env` removed. The only Relay containers
  have Compose working-directory labels for the new path. Rollback requires
  restoring the pre-upgrade backup and using the previous image tags.
- The protected `.env` is
  `/etc/vps-infra/secrets/ai-api-relay/.env`, mode `0600`; the new checkout's
  `.env` symlink resolves there. Secret-bearing settings were preserved while
  hostnames, backup location, and image tags were corrected.
- Upgraded and running tags: Sub2API `0.2.9`, PostgreSQL `16.15-alpine`, Redis
  `7.4.11-alpine`. New API remains `v1.0.0-rc.40` because the available stable
  tag is older and its database compatibility has not been reviewed.
- Pulled image digests:
  - `weishaw/sub2api:0.2.9` — `sha256:1f4a15d278fdedfa80188a0de538b81222bcc9a6bbe93bf91522c864737a90e3`
  - `calciumion/new-api:v1.0.0-rc.40` — `sha256:37c0f99a76ed0a5d5b376b8486173415efd1ec416042b392bd564eb0ae6a55ef`
  - `postgres:16.15-alpine` — `sha256:721873c34ceb9f8d8fc265984940dc982404c105f19ad51be9fdc5970a6080ea`
  - `redis:7.4.11-alpine` — `sha256:858f009f9709ce576febc734aa78b8f6d624b82571f9ddb6bda4377c833b3499`
- `sub2api` and `new-api` alone join `vps-infra_ingress`; PostgreSQL and Redis
  stay on `ai-api-relay_backend`. None of the four containers publishes a host
  port. Existing named volumes were reused: `ai-api-relay_postgres_data`,
  `ai-api-relay_redis_data`, `ai-api-relay_sub2api_data`,
  `ai-api-relay_new_api_data`, and `ai-api-relay_new_api_logs`.
- Pre-upgrade backup:
  `/home/alex/backups/ai-api-relay/backup-20260928-143700.tar.gz`;
  SHA-256 `acba72028955df1273e8997281cae133f510dacdf25ef795434308525e5452e4`.
  `sha256sum -c` passed; archive listing confirmed both PostgreSQL dumps and the
  Redis/application volume archive. The earlier pre-migration backup is also
  retained in the same directory.
- `nginx -t` passed for the infra Nginx container; it was gracefully reloaded
  after the app move so its Docker DNS entries resolved the recreated apps.
  Local HTTPS requests through that Nginx returned success for both app health
  paths. Both certificates expire `Dec 27 08:19:52 2026 GMT`.
- Those ingress checks were one-time cutover verification. Relay's ongoing
  `make health` now checks only Relay containers and internal app endpoints;
  ingress, Nginx, routes, and TLS checks belong to `vps-infra`.
- Public requests through Cloudflare previously returned HTTP 403 with
  `cf-mitigated: challenge`. External DNS, IPv4/IPv6 client access, and CDN
  behavior remain unverified.
- The first `make update` health check ran before the Sub2API Docker health
  state completed. A subsequent `make health` passed. Update and bootstrap now
  use Compose `--wait --wait-timeout 180` before running their full checks. A
  repeat `make update` then passed with all four services healthy. Its backup,
  `/home/alex/backups/ai-api-relay/backup-20260928-144938.tar.gz`, passed
  `sha256sum -c` with digest
  `0b235297777f84f2049fa7e69d0797f21a558b709d245101ec87c9ea917ea70e`.
- Validation tools installed for the `alex` account: ShellCheck 0.11.0,
  yamllint 1.37.1, and markdownlint-cli 0.49.1. Compose 5.2.0,
  `scripts/validate-env.sh`, ShellCheck, yamllint, markdownlint, `bash -n`,
  `git diff --check`, Redis authenticated `PING`, and a credential-pattern scan
  passed. Infra Nginx `nginx -t`, container health, and both local HTTPS routes
  also passed.
- Removed the obsolete Relay-owned Nginx/Certbot Compose services, their tracked
  templates and scripts, and unused generated Nginx/Redis configuration files.
- New API release review on 2026-09-28: GitHub marks `v1.0.0-rc.40` as the
  latest release; it is an RC. The most recent non-RC release found is `v0.13.2`
  from 2026-04-27. Recommendation: keep the already deployed RC.40 pinned and
  do not downgrade its database to v0.13.2 without a separate compatibility and
  restore rehearsal. See the official
  [release list](https://github.com/QuantumNous/new-api/releases),
  [v0.13.2 notes](https://github.com/QuantumNous/new-api/releases/tag/v0.13.2),
  and [RC.40 notes](https://github.com/QuantumNous/new-api/releases/tag/v1.0.0-rc.40).

## 公開服務比較的唯讀查核

**觀察時間：** 2026-10-01 19:45–20:00 Asia/Hong_Kong（11:45–12:00 UTC）。
**文件驗證時間：** 2026-10-01 20:00–20:03 Asia/Hong_Kong。
**範圍：** 使用者明確授權比較 emooo 與 byte612，並 SSH 查閱 Relay；未部署、
重啟、更新 image、改 app settings、建立／刪除資料、付款或修改 infra。

完整比較與待執行計畫見
[三方比較](sub2api-public-service-comparison.md)及
[公開服務計畫](sub2api-public-service-plan.md)。既有 TODO 完成狀態未改動。

- 本機 `vps-personal` SSH 名稱無法解析；使用專案指定的
  `alex@89.167.21.176` 成功連線，不需 sudo。
- VPS checkout 的 `git status --short` 無變更。Compose project 仍為
  `ai-api-relay`，正式路徑 `/srv/stacks/ai-api-relay-deploy`。
- 四容器均 healthy，image tags 與 9/28 記錄相同。`docker inspect` 的
  PortBindings 均空白；僅兩個 app 接 ingress，PG／Redis 僅 backend。
  檢查的是 Relay 容器的附件，沒有檢查或修改 infra network 本身。
- 內部 Sub2API `/health` 回傳 `{"status":"ok"}`，New API `/api/status`
  回傳 `success=true`；只輸出選定狀態欄位，沒有保存完整 status body。
  Redis authenticated PING 為 `PONG`，PostgreSQL 唯讀查詢成功。
- **版本漂移：** Sub2API image 為 `weishaw/sub2api:0.2.9`，但
  `docker compose exec -T sub2api /app/sub2api -version` 顯示 `0.2.11`，
  commit `96f4c115c9749078f90cbf210a01d39baf3f53b6`。
  `docker diff ai-api-relay-sub2api-1` 顯示 `/app/sub2api` 改變及新增
  `/app/sub2api.backup`。`/app/data` 是 volume，執行檔本身不是；重建前
  必須先處理 image／runtime 一致性與 schema 相容性。
- `schema_migrations` 計數為 289；未逐項核對 checksum。不能據此宣稱
  可安全回到 `0.2.9`。本次未執行 `make update`、backup 或 restore。
- Protected `.env` metadata 確認 mode `0600`、owner `alex`，symlink 正確。
  沒有輸出 `.env`／container environment 的 secret 值。
- Codex 瀏覽器：emooo 登入成功；byte612 由使用者完成管理員登入。
  byte612 Backend Mode ON、Registration OFF、Payment OFF；只有一個
  OpenAI OAuth Plus 帳戶、沒有 Anthropic 供應。群組／channel／Settings
  的非機密觀察列於比較文件，沒有按儲存或更新。
- 官方參考以匹配 runtime 的 `v0.2.11` commit 為主，同時讀取 `v0.2.9`
  與 `main`（`d6adebd22de00478cd021119ba755f37bcb94fb5`）。只下載及閱讀
  原始碼，沒有執行上游安裝腳本。

檢查命令及結果：

| 檢查 | 結果 |
|---|---|
| VPS `docker compose config --quiet`／`docker compose ps --all` | 通過；四容器 healthy |
| VPS `docker inspect` 選定 fields／internal `wget` health／Redis PING／PG count query | 通過；網路與 host ports 符合 PRD |
| VPS `docker diff`／`/app/sub2api -version`／執行檔 SHA-256 | 成功取得；發現 image／runtime 版本差異 |
| 本機 `docker compose --env-file .env.example config --quiet` | 通過；使用 placeholder 範例，不建立或覆寫 `.env` |
| 本機 `shellcheck scripts/*.sh postgres/init/*.sh` | 通過 |
| 本機 `yamllint .github/workflows/ci.yml .github/dependabot.yml compose.yaml` | 通過 |
| 本機 `markdownlint README.md USER_GUIDE.md PRD.md TODO.md AGENTS.md docs/*.md`、`git diff --check` | 通過 |
| 本機 `gitleaks git --redact --no-banner`、`gitleaks dir docs --redact --no-banner` | 通過；22 個 commits 與文件掃描未發現機密 |
| 文件相對連結檢查 | 11 個本機連結通過 |

初次 Docker inspect 的 mount template 假設所有 mounts 都有 Name，遇到
PG bind mounts 而失敗；改用 Source 後完整重跑成功。沒有因此變更部署。

**未涵蓋：** 普通使用者端到端註冊、SMTP、付款／退款、webhook、公開 SDK、
長串流／WebSocket、TLS／DNS／CDN／firewall、負載及 restore。9/28 的
Cloudflare challenge 紀錄仍只是歷史觀察；本次瀏覽器登入成功不證明
非瀏覽器 API 或 provider callback 通過。備份排程、archive permissions、
off-host backup、一致性及完整 runtime overrides 未驗證。

## emooo 功能差異與操作指南補查

**觀察時間：** 2026-10-01 約 20:20–20:34 Asia/Hong_Kong。
**文件驗證時間：** 2026-10-01 約 20:37–20:40 Asia/Hong_Kong。
**範圍：** Codex In-app Browser 中的已登入頁面與本機官方 source；本輪
沒有再 SSH、部署、切換設定、按 Save、寄信、建立訂單／工單或觸發模型測試。

新增[功能設定指南](sub2api-feature-setup-guide.md)，並補充
[三方比較](sub2api-public-service-comparison.md)及
[實施計畫](sub2api-public-service-plan.md)，README 已加入入口。

- byte612 `/home` 使用官方預設首頁，Home Page Content 空白；頁首／首頁
  已有 Model Plaza。`/model-plaza` 有 `codex` 及 `gpt-6-luna` 價格，
  `model-1` 價格為 `-`。Available Channels 與 Profile 亦已存在。
- byte612 `/monitor` 的 `test-01` 有資料；本次快照 latency 2599 ms、
  endpoint ping 321 ms、7 日 availability 100%。管理頁明示系統模式
  V1 active probes；沒有按 Run Now 或修改 monitor。
- Settings 再核對：Backend Mode ON、Registration／Email Verification／
  Payment OFF。Email 頁明示需開啟驗證才顯示 SMTP；通知的 Recharge
  Page URL 仍為舊 IP／8080。沒有讀取 SMTP password 或商戶憑證。
- emooo `/home` 是客製 landing page，標示 ¥1 得 $1 額度及服務指標，
  都只是頁面宣稱；部分 footer 指向 `/home#`。`/model-plaza?embedded=1`
  顯示 8 groups／41 models 與折扣／參考價；`/purchase` 顯示 Alipay。
- emooo `/monitor` 明示真實請求被動採樣，另有 SVG 能力測試中心；無樣本
  的顏色不能視為實測可用。`/support` 有列表／對話，`/video-studio`
  有影片參數但此帳戶無可用 Key／model，`/leaderboard` 有 token／邀請／
  儲值維度，`/qq-bot/binding` 要求由 QQ bot 私訊取得綁定連結。
- 使用者報告 emooo 註冊收到 email code；agent 未重新註冊或驗證送達。
  所有瀏覽器觀察均為登入後視角，普通使用者／匿名流程尚未完成驗收。
- 核對匹配 runtime 的官方 source：router／sidebar、HomeView、
  CustomPageView、SettingsView、V1 monitor form、V2 monitor 說明、
  email_service、PAYMENT_CN、providerConfig、Alipay provider 及 payment_order。
  四項額外前台 routes 未見於 core；Videos API／ranking 能力不能直接
  等同 emooo 的影片工作室／公開排行榜。
- 重要修正：官方 Alipay provider 固定 `alipay.New(..., true)`，沒有
  sandbox UI 欄位，計畫改為 staging／mock、確認可用測試環境及使用者
  小額正式驗收。餘額充值倍率與訂閱匯率／手續費已分別說明。

本輪文件檢查：`markdownlint README.md USER_GUIDE.md PRD.md TODO.md
AGENTS.md docs/*.md`、`git diff --check`、`gitleaks dir docs --redact
--no-banner` 通過；本機相對連結檢查全部通過。純文件補充沒有修改 Compose
或 scripts，未重跑 runtime／部署檢查，亦未勾選任何未執行的 TODO。

**仍未驗證：** emooo 版本／fork／客製模組來源與商戶 provider；byte612
SMTP／註冊端到端、付款／退款／webhook、V2 實際聚合、匿名視角、infra
與公開 API。後續需要選定 SMTP、商戶及商品換算，文件沒有保存秘密。

2026-10-01 約 21:03–21:08 HKT 補查 Cloudflare 官方文件：舊 Email Routing
入口轉向 Email Service；目前有 Email Sending Beta 與 authenticated SMTP。
SMTP 頁（標示 2026-09-16 更新）指定 `smtp.mx.cloudflare.net:465`、implicit
TLS、username `api_token`、具 Email Sending: Edit 權限的 token 作 password。
Overview 標示一般 outbound sending 適用 Workers Paid plan，寄件網域需另
onboard；購買網域／收信轉寄不自動提供寄信帳號。已補入功能指南，沒有
登入 Cloudflare dashboard、開通方案、改 DNS、建立 token 或實測寄信。
另補支付接入工時估算、WeChat Pay／Stripe 與 QQ bot 說明；商戶審核時間
未向任何 provider 核實。文件 Markdown／diff／secret 檢查通過。

2026-10-01 約 21:17–21:25 HKT 補查免費 SMTP 與香港收款路徑：使用者
說明以香港個人身份申請。Resend 官方 pricing 顯示 Free 每月 3,000 封、
每日 100 封；SMTP 文件指定 `smtp.resend.com`、username `resend`、API Key
作 password，465 支援 implicit TLS。Brevo 官方 Free SMTP 顯示每日 300
封。Stripe 香港支援頁提及 individual／HKID 及 sole proprietor／BRN；
Alipay 文件列出 HK 商戶地區，且可在 Stripe Dashboard 開通。對照
Sub2API Stripe provider，instance sub-methods 包含 card／alipay／wxpay／link，
並用 PaymentIntent／Payment Element；這與頂層官方／EasyPay Alipay 來源
不同。指南已補免費 SMTP 與 Stripe 內 Alipay 的設定步驟。
沒有建立商戶／寄信帳戶、輸入新憑證、申請支付方法、寄信、付款或改 DNS／
正式設定。未確認此使用者已有商戶、HKID／BRN、業務是否獲接納、寄件送達
或付款端到端；工時只是規劃估算。Markdown、diff 及文件機密掃描通過。

2026-10-01 約 21:35–21:43 HKT：使用者另行授權以 10 元 Alipay 查看 emooo
付款頁。建立一筆待付款訂單，頁面顯示 Alipay QR Payment／Waiting for
payment／約 30 分鐘倒數。解析畫面 QR 得到 `qr.alipay.com` 的 `/bax…`
網址；桌面開啟跳轉到 `render.alipay.com` 首頁，未顯示商戶名稱。查核後
取消，頁面確認 Order Cancelled，餘額仍為 0；沒有付款或增加 credit。
截圖保存於 `/tmp/emooo-payment-check-20261001`，未加入 repo，完整 QR
識別網址未寫入文件。本次亦核對官方 Alipay provider 的 RSA2 憑證、
precreate／pagepay／wappay 及非同步驗簽流程，補充「商戶 API 不等於僅限
企業帳戶」說明。未登入支付寶、查私人身份或變更 byte612 設定。

## byte 品牌首頁正式套用

**時間：** 2026-10-09 20:08–20:12 Asia/Hong_Kong。
**授權範圍：** 使用者要求核對 Sub2API 配色與連結，並在 VPS 套用自訂首頁。

- 正式 HTML 當時為 `centered-sub2api.html`（歷史設計稿保留本機），
  居中極簡 B 版型，使用 Sub2API teal／slate palette、預設深色、提供首頁淺色切換。
- 先核對 service／volume 狀態與 Compose config，備份 `home_content` row 後，
  以 transaction 更新單一設定。其他 settings 的聚合雜湊前後一致。
- 備份位於 `/home/alex/backups/ai-api-relay/homepage-20261009-120812/`，含原 row、
  回退 SQL 和部署 metadata；目錄 `0700`、檔案 `0600`，沒有提交正式資料。
- VPS HTML 存於 `/srv/stacks/ai-api-relay-deploy/config/sub2api/homepage/centered-sub2api.html`。
  SHA-256：`b98c34445884acdecbc59f8a3ea9ad8b23a64c379990f0a2c5512c31bd358de4`。
  無 cookie 的公開 HTTPS 回應注入相同內容。
- 使用 `make restart SERVICE=sub2api` 刷新沒有 TTL 的首頁 HTML cache，沒有重建
  容器或升級 image。既有 runtime `0.2.11`／image `0.2.9` 漂移仍存在。
- 正式瀏覽器實際確認 `/` → `/home`、首頁模型廣場 → `/model-plaza`、控制台 →
  `/dashboard`；四題 Q&A、頁尾同頁錨點及淺色切換正常。390px DOM 無水平溢出。
- `docker compose config --quiet` 通過；Docker inspect 選定欄位確認四容器 healthy、
  PortBindings 空白、只有 apps 接 ingress；Sub2API 內部 `/health` 回 `status=ok`。
  初次 inspect template 遇到 shell 展開問題，改用 Python 解析後重跑成功。
- 未變更其他 app／infra／付款／商品設定。未執行整庫備份或還原、image upgrade、
  schema migration、匿名瀏覽器登入端到端、計費或對話留存驗證。

現行首頁來源及部署方式見[首頁部署紀錄](sub2api-homepage-deployment.md)；
當時的歷史設計稿保留在本機。

### ByteAPI 三語首頁與灰綠淺色正式部署（2026-10-10 02:10–02:15 HKT）

- 使用者選定灰綠並授權分支開發及 VPS 部署。沿用 `codex/brand-homepage`；
  `git fetch origin` 後 `HEAD...origin/main` 為 `0 / 0`，沒有需要補拉的提交。
- 正式來源為 `config/sub2api/homepage/centered-sub2api-v2.html`，白色圖標與
  ByteAPI 字標、單一登入入口、模型價格 CTA、三語及四題 Q&A。
  移除 20% 區塊、三步教學與首屏控制台按鈕；加入指定接入工具、無需 VPN
  及充值 1:1 文案。預設仍是深色，淺色改為灰綠 `#e8efeb`。
- 部署前核對 Compose、service 與 volume 狀態。備份原首頁到
  `/home/alex/backups/ai-api-relay/homepage-20261009-181053/`，
  目錄 `0700`、檔案 `0600`；含原 row、回退 SQL、部署 metadata。
  備份和部署工具留在 VPS／暫存目錄，沒有加入 Git。
- Transaction 鎖定並核對原首頁 SHA-256 後，只更新 `settings.home_content`；
  其他 settings 的聚合雜湊一致。以 `make restart SERVICE=sub2api` 刷新快取。
  正式檔案保存於 VPS 同一相對路徑。
- 新版 SHA-256：`58514420ff87e5d1027c6b909643c467f7de0de19585cd6e22607370fa2c10d2`。
  無 cookie 的公開 HTTPS 回應為 200，注入內容與本機 fragment 逐字一致。
- `docker compose config --quiet` 通過；選定 Docker inspect 欄位確認四容器
  healthy、無 host PortBindings、只有 web apps 接 ingress；Sub2API 內部
  `http://127.0.0.1:8080/health` 回 `status=ok`。
- 正式瀏覽器確認簡中／繁中／英文切換，灰綠 computed background 為
  `rgb(232, 239, 235)`、logo fill 為白色，1280px 無水平溢出。
  `/` 導向 `/home`，首屏 CTA 開啟 `/model-plaza`；登入 href 為 `/login`，
  現有已登入帳戶正常導向 `/dashboard`。頁尾 `#byte-faq` 留在首頁，
  充值 Q&A 可展開，內容仍明示支付寶充值準備中。
- 正式截圖：`config/sub2api/homepage/previews/b-sub2api-v2-live-gray-green.jpg`。
  `git diff --check` 通過。沒有修改 Compose、shell scripts 或 TODO 勾選。
- 語言與主題選擇目前不持久化；重載回到簡中／深色，不同步控制台偏好。
  自訂 select 樣式適用目前 Codex 瀏覽器，其他瀏覽器可能使用原生選單。
  匿名 HTTPS 內容已確認，匿名註冊端到端、計費換算、工具相容性與資料
  留存行為未在本次部署驗證；付款服務尚未實作。
- 分支改動保留未提交；未 push。既有 image `0.2.9`／runtime `0.2.11`
  漂移維持既有紀錄，本次只重啟原容器。

## ByteAPI 固定深色首頁 v3 與 GitHub

**時間：** 2026-10-10 02:34–02:40 Asia/Hong_Kong。
**授權：** 使用者確認最新手機設計並要求使用 GitHub 及部署 VPS。

- 正式來源 `config/sub2api/homepage/centered-sub2api-v3.html`；移除主題切換
  及小標、還原登入配色，地球語言選單配合手機單行 header。
- 原設定備份：`/home/alex/backups/ai-api-relay/homepage-20261009-183450/`，
  權限驗證為目錄 `0700`／檔案 `0600`。Transaction 核對原值後只更新
  `home_content`；其他 settings 聚合雜湊一致，重啟既有 Sub2API 清除快取。
- 公開 HTTPS 200 與本機逐字一致；SHA-256：
  `3c07c94fa463a2ac824db93e730f2b46744882ef989cde36969de70298f6967e`。
- `docker compose config --quiet` 通過；四容器 healthy、無 host ports、
  網路符合 apps／private databases 分工；Sub2API 內部 `/health` 回 `ok`。
- 正式瀏覽器確認三語、模型價格、登入、FAQ；根網址導向 `/home`。
  390px 繁中、320px 英文的語言及登入 y 均為 20px，clientWidth 與
  scrollWidth 分別相同為 382／312，沒有換行或溢出；viewport 已還原。
- GitHub 分支 `codex/brand-homepage` 已推送 commit
  `9d912db184f9430e7dbcae81848db12559b4d14a`；
  [PR #7](https://github.com/alexlo612/ai-api-relay-deploy/pull/7) 尚未合併。
  VPS fetch 後核對 commit source 與部署檔案一致，保留 VPS checkout main。
- 只提交最終 HTML、兩張正式公開首頁截圖及
  [部署 handoff](sub2api-homepage-deployment.md)；既有研究文件和歷史稿
  仍保留本機。`markdownlint`、`git diff --cached --check`、
  `gitleaks stdin --redact --no-banner` 掃描 staged diff 通過。
- 未變更 image／schema／secrets／Compose／infra／付款，也未完成匿名
  註冊、實際計費與資料留存驗證。既有 runtime／image 漂移維持原紀錄。

GitHub CI run `37974737113` 已完成，結論為 `success`；`gh pr checks 7`
確認 checks 通過。PR 保留 OPEN，未執行 merge。部署 source 與 PR HEAD
`9d912db184f9430e7dbcae81848db12559b4d14a` 相同。

2026-10-10 02:42 HKT：使用者明確要求合併 PR #7。核對 HEAD `9d912db`、
checks SUCCESS 與 mergeState CLEAN 後，使用 head commit guard 完成 merge。
GitHub 狀態為 MERGED，merge commit 為
`93bf5ef65e65d41773355d5bf3ef83ca6aa6fa52`。本機 fetch 後確認
`origin/main` 包含已部署的來源 commit；沒有修改本機既有工作樹或重新部署。
