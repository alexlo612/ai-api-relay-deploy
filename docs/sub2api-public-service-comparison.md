# Sub2API 公開服務比較：emooo、官方與 byte612

**檢查日期：** 2026-10-01（Asia/Hong_Kong，首輪 19:45–20:00；功能補查約 20:20–20:34）。
**目的：** 找出從私人 Relay 轉成「使用者可註冊、付款、取得 Key、使用 API」的差距。
**配套文件：** [設定建議與實施計畫](sub2api-public-service-plan.md)、
[首頁／渠道／SMTP／Alipay 操作指南](sub2api-feature-setup-guide.md)。
**時效：** 下表是 2026-10-01 的歷史快照，不代表目前設定。2026-10-11
已使用 ByteAPI 自訂首頁、啟用 Stripe CNY 充值（微信支付或信用卡），
Sub2API 執行檔為 `0.2.15`。最新部署與付款驗證範圍見
[現況紀錄](current-state.md)；未獨立重驗本文件的其他功能欄位。

## 判斷與證據範圍

2026-10-01 當時，byte612 的容器與內部健康端點正常，但應用仍以私人管理用途運作：
`Backend Mode` 開啟，註冊與付款關閉，只有一個可供應的 OpenAI OAuth Plus
帳戶。公開營運主要缺口在應用設定、商品與供應、付款驗收和可重建性。

emooo 的前台具備完整的儲值型服務入口，適合參考使用者流程；不能據此
推斷其後台、主機容量、付款供應商、利潤或實際服務品質。

| 證據類型 | 本次取得內容 | 可支持的結論與限制 |
|---|---|---|
| emooo 使用者頁面 | Codex 瀏覽器查看 dashboard、purchase、keys、available-channels、profile；補查 home、monitor、model-plaza、support、video-studio、leaderboard、qq-bot/binding | 可確認這個帳戶看見的功能／價格；沒有 emooo 管理員或 SSH 存取 |
| byte612 管理頁 | 使用者完成管理員登入；唯讀查看 Settings、Groups、Accounts、Channel Pricing；補查 home、model-plaza、monitor、profile 及 monitor 管理頁 | 可確認畫面設定；沒有按 Save／Update、Run Now，或建立 Key、帳戶、訂單 |
| byte612 VPS | `alex@89.167.21.176`，僅 Relay 容器、內部健康端點、檔案 metadata、選定非機密 config 欄位、migration 數量 | 可確認運行狀態與版本差異；沒有修改服務、讀取 secret 值或完整業務資料 |
| 官方 repo | 讀取 `v0.2.9`、`v0.2.11` 及此次取得的 `main` 原始碼 | 官方功能／預設值與操作建議有分別；範例預設值不是公開營運容量保證 |

本文件不保存登入 email、密碼、cookie、API Key、上游 token、商戶憑證或
資料庫匯出。公開瀏覽器成功登入不等於無瀏覽器的 SDK 或付款 webhook 可用。

## 版本：需要先處理的部署差異

| 項目 | 官方基準 | byte612 實測 | 影響 |
|---|---|---|---|
| Compose image | repo 支援版本化 image；官方快速入門範例也使用 `latest` | `weishaw/sub2api:0.2.9` | 本專案固定 tag 的做法應保留 |
| 容器執行檔 | `v0.2.11` commit `96f4c115c9749078f90cbf210a01d39baf3f53b6` | `/app/sub2api -version` 顯示 `0.2.11`，commit 與官方 tag 一致 | 實際執行版本已高於 image tag |
| 容器檔案變化 | 官方線上更新程式會替換執行檔並留下 `.backup` | `docker diff` 顯示 `/app/sub2api` 已改變，新增 `/app/sub2api.backup` | 與容器內線上更新的結果一致；本次未確認由誰或何時操作 |
| 持久化路徑 | `/app/data` 保存 app config | volume 只掛載 `/app/data`；執行檔在容器可寫層 | restart 通常保留可寫層，recreate 會回到 image 所帶執行檔；不能假設是安全降版 |
| 已套用 migrations | 官方啟動會套用 migrations，回退需相容備份 | `schema_migrations` 有 289 筆 | 筆數僅為現況證據，沒有核對所有 checksum 或 schema 相容性 |

Image ID：`sha256:1f4a15d278fdedfa80188a0de538b81222bcc9a6bbe93bf91522c864737a90e3`。
運行執行檔 SHA-256：`e041e8d03feba01913093de9dc4ab220620e190c987ddba8e04b3044c42ad46e`。

官方本次取得的 `main` 是 `d6adebd22de00478cd021119ba755f37bcb94fb5`，它是移動中
的開發基準。本比較以匹配運行執行檔的 `v0.2.11` 為主要功能基準，不直接建議
部署 `main`。emooo 未顯示可核實的版本，無法確認 fork 或 commit。

## 三方功能與設定比較

「官方」欄的功能表示上游具備實作；標示為預設的值只代表初始化行為。

| 項目 | emooo 使用者頁面 | 官方 `v0.2.11` | byte612 於 2026-10-01 的設定 | 公開服務含意 |
|---|---|---|---|---|
| 服務定位 | EMOAI 品牌、自助 workspace | 可自訂品牌、首頁、API Base URL、文件與聯絡方式 | 品牌仍是 Sub2API；API Base URL 空白；Contact Info 空白 | 補齊正式商品說明及客服 |
| 公開／後台模式 | 一般使用者能登入及進入儲值頁 | Backend Mode 會限制註冊及使用者自助入口 | Backend Mode **開啟** | 這是自助營運的主要阻礙 |
| 註冊 | 登入頁有 Sign up；使用者已自行註冊，本次未重跑流程 | 註冊預設開啟，可加邀請碼／email domain 規則 | Enable Registration **關閉**；Invitation Code 關閉；domain whitelist 空白 | 應分階段開放，先邀請制 |
| Email 驗證／SMTP | 使用者報告註冊收到 email code；agent 未重新註冊或寄信 | 支援 SMTP、驗證、重設密碼與通知；email 驗證預設關閉 | Email Verification **關閉**；Email 頁提示需先開啟才顯示 SMTP 設定 | SMTP 是否已保存無法從畫面確認；具體步驟見操作指南 |
| CAPTCHA | 本次登入未出現可見 CAPTCHA；不能推斷其他流程 | 有 CAPTCHA 設定能力 | **關閉** | 開放註冊前完成 bot 防護 |
| 使用者預設餘額 | 此帳戶餘額為 0；不是全站預設證據 | 預設 0 | **0** | 建議維持，不先發無限制試用額度 |
| Concurrency | Profile 顯示此帳戶 **500** | 預設 5，可個別設定 | 新使用者預設 **5**；上游帳戶容量 10 | 不應複製 emooo 的 500；這不是其實際吞吐量證明 |
| RPM 與配額 | 此帳戶的 RPM／平台配額未能確認 | 預設 user RPM 0＝不限；group RPM 可覆蓋 user fallback | 預設 user RPM **0**；codex group RPM **0**；新使用者平台額度欄空白 | 需設定有界限制並驗證生效層級 |
| 付款 | Top Up 頁只顯示 **Alipay** | 內建 EasyPay、官方 Alipay、官方 WeChat、Stripe；原始碼另有 Airwallex 路由 | Enable Payment **關閉**；其餘設定隱藏 | 不需為基本儲值另部署 Sub2ApiPay；供應商是否已保存仍未知 |
| 付款範圍 | 快捷數字 10–5000；自訂金額 `$`、確認付款 `¥`；首頁標示 ¥1 得 $1 額度 | 金額、餘額充值倍率、fee、daily cap、pending、timeout、可見方式來源可設定 | 尚未從關閉狀態檢查到這些值 | 首頁是商品換算宣稱，未付款驗證；不照抄數字或視為外匯匯率 |
| 訂閱 | Subscribe 顯示 **No subscription plans available** | 支援 subscription groups、plans、期限與配額 | Site Billing Mode = **Recharge only**；沒有 default subscriptions；現有群組都是 Standard (Balance) | 第一階段採儲值按量較簡單；不要把有入口當成有商品 |
| API Key | 已有一個 active Key；建立／使用／測試入口存在 | 使用者自助管理 Key、group、到期與限制 | 私人管理帳戶可用，普通使用者流程未測 | 本次沒有建立新 Key 或測試扣費 |
| API endpoint | Key 頁列出 `https://api.emooo.cc` | 可設定 API Base URL 與 custom endpoints | API Base URL 空白，會使用目前站點 URL | byte612 的 `api.byte612.com` 是 **New API**，不能直接拿來當 Sub2API endpoint |
| 目錄與透明度 | 8 channels／8 groups／41 models；顯示倍率、cache 價格與 billing notes | Available Channels、Model Plaza、channel/group pricing | 兩項都啟用；Plaza 不要求登入；pricing notes 空白；目錄見下節 | 先整理商品目錄，再公開宣傳 |
| 使用統計／訂單 | 使用量、實際支出、參考價、cache 比例；導覽有 My Orders | 內建 usage 與 payment order lifecycle | 管理端統計正常；付款未啟用 | 本次沒有付款及訂單狀態變更證據 |
| 客服／附加功能 | 工單有列表／對話；影片有 Key／model／時長等表單；排行有 token／邀請／儲值；QQ 私訊 bot 綁定 | 對照 core routes 未見這四項獨立前台；Videos API、affiliate 或管理端 ranking 不等於這些頁面 | Contact Info 空白；Affiliate 關閉 | 需額外整合或開發；Custom Menu 僅提供入口 |
| 2FA／Passkey | Profile 明示管理員未啟用 2FA；Passkey 未設定 | 支援 TOTP、step-up、Passkey 設定 | 2FA／step-up 關閉；Passkey 未設定 | 管理員安全不應照 emooo 現況複製 |
| Panel 限流 | 後台值未知 | 支援每帳戶與 public IP panel limits | 開啟；240 req/min，heavy 60，public 300；admin exempt 開啟 | 保留；不等於模型 API RPM 限制 |
| 來源 IP 信任 | 代理與 origin 狀況未知 | EDGE_SECURITY 要求精確 trusted proxies 或受保護 origin | Trust forwarded client IP **開啟**；custom headers 空白；generated config 未列 trusted_proxies | 需 infra 協同確認 header 覆寫與 origin 邊界，不能單靠這個開關認定安全 |
| 協議／營運資訊 | 本次未讀到 emooo 條款或完整退款政策 | 支援 Markdown agreement documents | agreement 關閉；四個預設文件內容空白 | 收費前補齊定價、退款、資料處理及支援政策 |

## 補查：已有頁面、入口差異與客製程度

byte612 的以下頁面已實際開啟，不能列為缺失功能：

| 頁面 | byte612 觀察 | 與 emooo 的差異 |
|---|---|---|
| `/home` | 官方 default landing page；General Home Page Content 空白 | emooo 是完整客製 landing page；官方可填 HTML／iframe URL，但未證實 emooo 使用哪種方式 |
| `/available-channels` | `openai-real-sub`，`codex` 1x、兩個 model entries | emooo 有更多 groups／models／notes；差距主要是供應與目錄設定 |
| `/model-plaza` | `codex` 價格表；`gpt-6-luna` 有價格、`model-1` 為 `-` | emooo 有用途篩選及折扣／參考價；不能只看側欄判斷不存在，byte612 入口在頁首與首頁 |
| `/monitor` | `test-01` OpenAI／`gpt-6-luna`，Operational；V1 active；latency 2599 ms、ping 321 ms、7d 100% 快照 | emooo 明示真實流量被動採樣；官方有 V2，但其額外 SVG 能力測試與客製版面另計 |
| `/profile` | username／email、OAuth、password、2FA／Passkey 入口 | emooo 重排帳戶及安全資訊；byte612 已有基本個人資料 |

emooo monitor 顯示 9 個 monitor groups／10 條線，部分等候樣本；無樣本
預設綠色不能當作實測成功。其 homepage 的 99.98% uptime／0.38 TTFB 等
數字是行銷宣稱，不是本次測量。footer 若只指向 `/home#`，不能據此認定
已有完整條款／文件。

以上在已登入 session 檢查，沒有完成 byte612 匿名／普通 user 驗收；
Backend Mode ON 仍是自助公開服務的阻礙。操作路徑、監控模式選擇、
SMTP 及 Alipay 設定詳見[功能操作指南](sub2api-feature-setup-guide.md)。

## 模型與計費：不要直接複製倍率

emooo 目前前台列出 Claude `0.4x`、Gemini `0.25x`、GPT Pro／企業組 `0.4x`、
GPT 混號組 `0.13x`、國模 `0.3x`，及圖片組獨立 `1x`。這些是其頁面的
商品標示，不是已驗證的成本或官方模型身分。其 Gemini notes 也明示模型別名
不保證原廠身分，美元和人民幣基準的組別各有自己的計費說明。

例如 emooo 的 `claude-opus-4-6` 展開頁顯示 base prices（每 1M tokens）：
input `$5`、output `$25`、cache write 5m `$6.25`、1h `$10`、cache read `$0.5`。
畫面明示這些尚未包含 group／個人倍率。因此不能把 input `$5` 誤當最終售價，
也不能未驗證帳面額度與收款貨幣就與其他網站比較折扣。

byte612 有以下更具體的商品一致性問題：

- `codex`：OpenAI、Public、Standard (Balance)、`1x`，一個可用帳戶；
  group RPM 0，Model Allowlist 關閉，profit control 關閉。
- `test`：Anthropic、Public、Standard (Balance)、`1x`，**沒有帳戶**。
- 唯一上游類型為 **OpenAI OAuth Plus**，UI 顯示容量 10。這是管理設定，
  不是壓測結果或供應商可持續保證；畫面有多種到期欄位，本次未測 refresh。
- `codex` 允許 `/v1/messages` dispatch：Opus family → `gpt-6.1-sol`；
  Sonnet／Haiku → `gpt-6-luna`；另有 exact overrides。
  這是協議／模型轉換，不能把它銷售為原生 Claude。
- 唯一 channel `openai-real-sub` 綁定 `codex`。Available Channels 僅列
  `gpt-6-luna` 及 `model-1`，但 dashboard 的歷史模型包含其他名稱。
- Channel 中 `model-1` mapping 的 target 空白；Restrict Models 關閉；
  billing model 為 `Bill by channel-mapped model`。
- `gpt-6-luna` custom prices 為 input `0.1`、output `0.5`、cache write 5m
  `0.125`、cache read `0.01`（`$/MTok`）；另有 account stats pricing rule
  的價格欄位空白。這是自訂設定，本次未確認它等於真實供應成本。

公開前應把「可購買模型、實際轉送模型、價格 lookup model、使用紀錄 model」
逐一對齊；未核價或未供應的模型不應只靠 fallback 價格對外販售。

## 官方部署建議與目前 Docker 配置

| 項目 | 官方 `v0.2.11` 文件／範例 | byte612 | 評估 |
|---|---|---|---|
| 部署方法 | 建議 Docker Compose；local bind directories 方便搬移，亦支援 named volumes | Compose + named volumes + Makefile／backup scripts | 沿用即可，不需為了模仿官方換 volume 型態 |
| 資料庫 | README 說 PostgreSQL 14+／Redis 6+；當前 Compose 範例用 PostgreSQL 18／Redis 8 | PostgreSQL `16.15-alpine`，Redis `7.4.11-alpine` | major 版本不同不等於必須升級；保留現行版本並另測相容性 |
| 網路 | app 快速範例公開 8080；資料服務不公開 | 四服務均無 host port；僅 web apps 接 ingress；DB／Redis 僅 backend | 保留現有界線；公開 8080 無助自助營運 |
| restart／health | `unless-stopped`、健康依賴；Postgres probe 含簡單 SQL | 四容器 healthy；Postgres 使用 pg_isready；SQL 唯讀查詢另成功 | 後續可把 SQL readiness 納入 probe，非目前首要阻礙 |
| 資源與 logs | 範例有高 nofile；pool 等預設偏通用 | app 各 768 MiB／1 CPU；PG 768 MiB；Redis 320 MiB；bounded logs | 適合小型起步，不能從 idle snapshot 推算付費容量 |
| DB／Redis pools | 範例 DB 50／10，Redis pool 1024／min idle 10 | repo 宣告 DB 20／5，Redis pool 64／min idle 5 | 小 VPS 的配置合理；未核對全部 runtime overrides，不建議照抄 1024 |
| Secrets | 固定 JWT_SECRET、TOTP_ENCRYPTION_KEY；首次 auto setup | Compose 要求固定 secret；external `.env` mode 0600 | 必須保留及安全備份；不把完整 Compose 展開輸出貼進文件 |
| URL allowlist | 範例預設關閉，文件列出 allow_private_hosts／HTTP 等控制 | repo 宣告 `SECURITY_URL_ALLOWLIST_ENABLED=true` | 保留並核對允許的上游；未確認所有 runtime hosts／DB overrides |
| 備份／更新 | migration forward-only；上線更新前準備備份 | 有 scripts、9/28 的三份備份 checksum sidecar；restore 演練仍未完成 | 需補最新備份、一致性、restore 與 runtime/image 一致性 |

VPS 實測 Sub2API／New API 內部 health 成功、Redis `PONG`、PostgreSQL 查詢成功。
瞬時記憶體約為 Sub2API 69 MiB、New API 53 MiB、PG 133 MiB、Redis 4 MiB；
磁碟使用 45%（約 20 GiB 可用）。這些是一次快照，沒有執行負載或長串流測試。

官方 `v0.2.11` payment provider 儲存程式明確以 **plaintext JSON** 寫入新設定，
舊 AES-GCM 資料只保留相容讀取；UI 遮罩不代表資料庫加密。因此付款啟用後，
DB dumps、backup archives 與其讀取權限都要按商戶憑證保護。

## emooo 是否也是 Sub2API

其「Subscription to API Conversion Platform」副標、group／channel 倍率、
Key 管理、purchase／orders／redeem 等概念與官方相符，**很可能是 Sub2API
或其衍生版本**。但品牌、workspace 排版、工單和其他入口也顯示客製內容。
沒有伺服器版本、image、source attribution 或 commit 證據，不能寫成已證實，
更不能假設所有差異只需在 Settings 打開開關。

## 追加：使用者授權的 10 元 Alipay 收銀台查核

2026-10-01 約 21:35–21:41 HKT，使用者另行授權嘗試 10 元 Alipay 儲值，
目的為查看付款網址／頁面。建立一筆待付款訂單，頁面為 Alipay QR Payment，
顯示 Waiting for payment 及約 30 分鐘倒數；沒有實際付款。

從畫面 QR 圖像解析出的網址為 `https://qr.alipay.com/bax…`（訂單識別部分
省略）。這證明 QR 指向支付寶官方網域，但不能只憑它判斷是個人經營者、
企業商戶、官方直連或第三方支付 provider；第三方亦可能取得官方 QR。
一般桌面瀏覽器開啟後跳轉至 `render.alipay.com` 的支付寶首頁，未顯示
收款方或商戶名稱。

查核後取消該訂單；畫面確認 **Order Cancelled / You have cancelled this
payment**，帳戶餘額仍為 0。沒有付款或增加 credit。待付款及取消截圖
保留在本機暫存目錄，未加入 repo；完整 QR URL／order identifiers 未寫入文件。
本節是首次唯讀比較後新增的授權測試，與前文當時「未建立訂單」的範圍不同。

## 官方來源與未驗證部分

以下連結固定到實際運行版本的 commit，避免 `main` 更新後失去比較基準：

- [README 與重要提醒](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/README_CN.md)
- [Deployment README](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/deploy/README.md)
- [Compose 範例](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/deploy/docker-compose.yml)
- [Config 範例：standard／simple、trusted proxies 等](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/deploy/config.example.yaml)
- [付款指南](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/docs/PAYMENT_CN.md)
- [付款路由](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/server/routes/payment.go)
- [付款憑證儲存實作](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/service/payment_config_providers.go)
- [初始 Settings 預設值](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/service/setting_parse.go)
- [Edge／SSE／可信 IP 建議](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/deploy/EDGE_SECURITY.md)
- [線上更新實作](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/service/update_service.go)
- [LICENSE（LGPL v3）](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/LICENSE)

官方 README 同時有「無商業授權」、上游服務條款風險與免責聲明；LICENSE 是
LGPL v3。不能把作者未背書與授權條文的商業使用權利混為一談，也不能把
emooo 已在營運當成你已獲上游轉售許可。計畫把確認實際供應商條款、授權及
收款商戶資格列為收費前的營運決策，不在本次作法律結論。

未驗證：emooo 後台／版本／SMTP／付款供應商／實際支付與 API 品質；byte612
普通使用者完整旅程、SMTP 送達、付款 provider 狀態、webhook、非瀏覽器
公開 API、SSE／WebSocket、TLS／DNS／WAF 設定、負載、restore。9/28 的
Cloudflare challenge 是歷史證據，不能當成 10/1 仍存在的結論。Infra 設定
與驗收仍由 `/srv/stacks/vps-infra` 負責，本次未檢查或修改其設定。
