# byte612 Sub2API 公開服務設定建議與實施計畫

**日期：** 2026-10-01（Asia/Hong_Kong）。
**狀態：** 2026-10-01 的建議與待執行清單，不是目前後台設定。
2026-10-11 已套用 ByteAPI 自訂首頁並啟用 Stripe CNY 充值，
`1 CNY = 1 USD` 帳面額度；Sub2API 執行檔已是 `0.2.15`。其餘項目未逐一
重驗，執行前先查[現況紀錄](current-state.md)。
**依據：** [三方比較與證據](sub2api-public-service-comparison.md)、
[目前部署證據](current-state.md)、PRD、TODO、USER_GUIDE。
首頁、既有頁面入口、監控、email code 與 Alipay 的逐步操作見
[功能設定指南](sub2api-feature-setup-guide.md)。

## 建議的第一版商品

先推出小型、邀請制的 **OpenAI 相容 API 儲值按量服務**，完成付款、扣費、
限額與還原驗收後，再開放 email 自助註冊。初期只販售已實測且有可用供應的
模型，不同時推出包月訂閱、圖片／影片、affiliate 與多平台。

現有一個 OAuth Plus 帳戶可用於技術驗證，但尚未證明足以承擔公開付費
服務。商業供應需確認上游准許此使用方式、可持續配額及供應成本；優先選擇
允許服務整合／轉售的 API 或具明確合約的供應商。若沒有持續供應或故障後
退款能力，先維持私人／封閉測試服務。

emooo 值得參考的是「價格 → 註冊 → 儲值 → Key → 文件 → 用量／訂單 →
客服」的完整流程。它的 500 concurrency、低倍率與高額儲值捷徑不能當成本
站容量或價格目標。

## 設定目標表

以下數字是 **封閉 beta 的候選起始值**，需配合供應額度與壓測調整，不是
官方推薦值或本次已套用的值。付款的 USD 指實際收款／商品標價；內部額度
須先明確定義並驗收換算。

| 頁面／層級 | 2026-10-01 當時 | 建議目標 | 執行條件／驗收 |
|---|---|---|---|
| General → Backend Mode | ON | beta 準備完成後 OFF | 邀請碼、email 驗證及限制先就緒；普通使用者能進入自助入口 |
| Security → Registration | OFF | beta ON + Invitation Code ON；正式公開再取消邀請限制 | 無碼拒絕、有碼按流程註冊；不得讓直接 API 註冊繞過驗證 |
| Security → Email Verification | OFF | ON | 選定 SMTP、TLS、寄件地址；驗證及重設信實際送達 |
| Security → CAPTCHA | OFF | ON | 使用可用的 CAPTCHA provider；正常登入／註冊可完成且錯誤 token 被拒 |
| Users → Default Balance | 0 | 維持 0 | 初期不自動發補助；零餘額無法消費付費模型 |
| Users → Default Concurrency | 5 | **1**；已付款且驗證的 beta 帳戶可個別給 2 | 限制跨多個 Key 的同一 user；驗收超額拒絕／等待行為 |
| Users → Default RPM | 0 | **10** | 只套用新建帳戶；既有帳戶另盤點 |
| Groups → beta group RPM | codex 0 | **10** | group RPM 會取代 user-level fallback，不是兩者相加；以實測證明 |
| Users → 平台消費額度 | 空白 | beta OpenAI daily **USD 5**、weekly **USD 20**、rolling 30d **USD 50** 候選 | 先確認扣費／quota 的金額基準、窗口與適用範圍；拒絕超額且允許下個窗口恢復 |
| Users → Auth Source Defaults | 各來源 overrides OFF | 首期只 email；如日後開 OAuth，與全域 limits 對齊 | 防止不同來源獲得較高 concurrency 或無限額 |
| Feature Switches → Billing Mode | Recharge only | 保留 | 只提供按量儲值，不新增 subscription promises |
| Payment → Enabled | OFF | 封閉環境與付款驗收通過後 ON | provider 確有 sandbox 才使用；此版官方 Alipay 固定正式 SDK 環境 |
| Payment → 額度／pending／timeout | 隱藏，未確認 | 支付金額／credit 規則確認後設定；pending 2、timeout 15 分鐘候選 | Alipay／EasyPay 的 CNY 收款與 USD 帳面 credit 分開；不能把 USD 限額數字直接填進 CNY 欄位 |
| Feature Switches → Available Channels／Model Plaza | ON／ON | 保留；整理目錄與 pricing notes | 未供應的 `test` 群組不公開；每個商品價格與轉送一致 |
| General → API Base URL | 空白 | `https://sub2api.byte612.com` | 依各協議文件補 `/v1` 等路徑；不改指向 New API 的 `api.byte612.com` |
| Email → Recharge Page URL | 舊 IP + 8080 | `https://sub2api.byte612.com/purchase` | 收到通知後能開啟正確儲值頁 |
| General → Documentation URL | 誤填 email | 一個有效 HTTPS 文件網址 | 使用者能讀 Key、endpoint、SDK、streaming、pricing、errors 範例 |
| General → Contact Info／brand | 空白／Sub2API | 正式客服地址、服務品牌及支援時段 | 註冊頁、儲值頁和 Profile 資訊一致 |
| Agreement | OFF、空白 | 補入條款、使用政策、隱私／資料處理、退款與中斷處理；適當啟用同意流程 | 使用者審閱營運內容後再發布 |
| Security → 2FA／Step-up | OFF／OFF | 開啟 2FA，管理員完成綁定後啟用 step-up | 使用者自行輸入新認證資料，確認復原方法；之後敏感操作需再次驗證 |
| Security → Admin API Key | 已存在，未讀取完整值 | 盤點用途；不需要時安排撤銷 | 先確認整合依賴及維護時間，不在本次刪除 |
| Security → Panel rate limit | 240／60／300、admin exempt | 初期保留 | 與 model API 限流分開測；監控 heavy queries |
| Gateway → RUN_MODE | generated YAML 未列；runtime 未確認 | 明確以 `standard` 運行 | `simple` 會跳過 billing／balance，不能用於這個付費商品 |
| App／infra → Client IP | raw forwarded headers takeover ON | infra 先確認 trusted chain，再安排 secure trusted-proxy mode | 不猜 CIDR、不直接關開關；IP ACL／audit／sessions 必須正確 |

以上需逐頁設定或透過確認過的 app API；不要把所有後台 settings 當成
`.env` 變數。Compose／generated `config.yaml`、DB settings、user、group、
channel／account controls 是不同層，必須記錄每一個變更落在哪裏。

## Phase 0：可重建部署與復原，先完成既有 TODO

- [ ] 先依 TODO 完成乾淨環境 restore 演練，訂定 RPO／RTO；不要以正式
  volume 做演練。將演練時間、checksum、資料與 Key／用量核對結果寫回 evidence。
- [ ] 維護前取得現行 DB／app 資料備份，記錄 current binary version／SHA、
  image digest、schema 狀況；驗證備份 checksum。
- [ ] 調查所有容器內 update／backup 執行檔差異，選擇與 current runtime
  匹配的固定 release image（2026-10-11 應使用 `0.2.15`）。先確認 image tag、
  digest 及測試環境 schema 相容性，不直接重建 `0.2.9`。
- [ ] 在 staging 使用相符 image 與備份完成啟動／migration／health／功能檢查；
  image 與執行檔 version 一致後，才安排正式維護、受保護 override 與
  Compose 預設 tag 同步。依本 repo 的 Makefile／scripts 流程更新。
- [ ] 此後以 Compose image 更新為營運方法，不以 UI updater 替換可寫層
  執行檔。若要強制限制 UI updater，另核實支援的設定或評估修補，不能
  假造「disable updater」環境變數。
- [ ] 新備份須納入 app DB、volumes、必要的安全設定與還原材料。固定 JWT／
  TOTP keys、protected `.env` 和商戶憑證需要另行受控保存；現有 archive
  不包含 external `.env`，不可單靠 archive 認定可完整還原。
- [ ] 審查 backup script：目前 live `pg_dump` 後直接 tar app／Redis volumes，
  未建立跨 DB／Redis 的共同一致時間點。制定短維護凍結或可靠 snapshot
  流程，特別避免 AOF rewrite／正在更新 config 時拷貝不一致資料。
- [ ] 盤點自動備份排程（本次未確認）、失敗通知、保留日數與 off-host 副本。
  先以 beta RPO ≤24h／RTO ≤2h 為目標，再按演練結果調整；一天收入／
  負債不可承受時縮短 RPO。
- [ ] 備份與暫存 dump 使用 restrictive permissions；off-host 副本加密。
  目前 checksum sidecars 可讀不代表 archive 權限已驗證；付款設定在
  `v0.2.11` 的 DB 中可能是明文 JSON，必須保護 dumps。

**退出條件：** 可從乾淨環境還原，相符 image 可重建，沒有無意降版，並
留下完整維運記錄。這一階段不新增公開註冊或收款。

## Phase 1：供應、模型目錄與價格

- [ ] 選擇初期使用者地區／用途、供應商、實際收款貨幣與內部 credit 單位；
  核對上游服務條款／轉售權、repo LICENSE 與 README 提醒、商戶接納的業務。
  作者免責不等於供應商允許轉售，第三方網站在售也不是授權證據。
- [ ] 準備可持續的主供應和故障安排；若只有單一帳戶，限制邀請數與在售
  額度，披露可用性，不承諾高可用。不要用 UI capacity 10 當 throughput。
- [ ] 把空的 Anthropic `test` 群組改為非公開或停用；依實際商品重新命名
  `codex`。這是未來操作，不刪除現有資料。
- [ ] 清理 `model-1` 空 target mapping，建立明確 allowlist；同步 channel
  目錄與 actual supported models。只公開已測模型與對應價格。
- [ ] `/v1/messages` 若保留轉換，命名為「Anthropic 協議相容、轉送 OpenAI」；
  文件逐項披露 Opus／Sonnet／Haiku mappings。要提供原生 Claude，就另備
  Anthropic 供應，不能把轉換商品當原生模型。
- [ ] 釐清 channel-mapped pricing、group multiplier、personal overrides、
  account stats、cache、Fast／Flex、long context 及 tools 的計費順序。
  未核價項目先不提供；不靠 unknown-model fallback 賣所有模型。
- [ ] 以真實成本決定價格。按請求計算：`淨收入 = 收款換算後收入 − 支付費用
  − 退款／爭議準備`，再扣實際上游費用、主機與客服成本。訂閱 OAuth 的
  fixed fee／配額成本要另建模型，不能把 dashboard 的 Standard／Cost
  統計直接當現金支出。
- [ ] 測試 input／output／cache 各分項、model aliases、長上下文、priority
  與工具呼叫的已知 token case，與 user debit／usage／cost reconciliation
  對帳。一般按 token 案例可用 `Σ(tokens × 每百萬單價) / 1,000,000` 加上
  適用倍率；不得重複計入已含 cache 的 token。
- [ ] Pricing notes 清楚寫 credit、收款貨幣、換算、cache、映射與最低／
  最高額度；Available Channels、Plaza、文件和實際 debit 必須一致。

**退出條件：** 每個在售模型都有可供應帳戶、清楚身分與價格、可重現扣費
證據。profit control 是否啟用需先確認 account multiplier 與真實成本語義，
避免打開後沒有任何帳戶可被調度。

## Phase 2：註冊、身份與文件，準備封閉 beta

- [ ] 選定 SMTP provider，設定 TLS、寄件地址與 SPF／DKIM／DMARC。
  DNS 工作交由 infra／網域 owner；本 repo 只記錄 app SMTP 設定與驗收。
- [ ] 開啟 email 驗證並完成送達測試、錯誤／過期 code、重設密碼驗收；
  僅使用明確授權的測試收件地址。
- [ ] 設定 CAPTCHA、user／group RPM、concurrency、消費額度及 zero balance；
  保留 panel limits。盤點既有帳戶，因預設值不會自動改舊帳戶。
- [ ] 補 branding、Contact Info、正確 Documentation URL、API Base URL、
  Recharge Page URL；文件包含 Key revoke、API paths、supported models、
  streaming、429、餘額不足、退款及服務中斷處理。
- [ ] 使用 Home Page Content 的 HTML／URL 配置正式首頁；整理已有
  Available Channels、Model Plaza、Channel Status、Profile 的入口。
  選 V1 主動探針或 V2 被動聚合，驗收少樣本顯示與 probe 預算。
- [ ] 完成管理員 2FA／復原流程與 step-up；盤點 full-access Admin API Key。
  先保障帳戶存取，不無預警更換密碼或撤銷整合。
- [ ] 完成 agreements 內容與使用者審閱；不直接發布空白預設文件。
- [ ] 先啟用邀請限制／驗證／限額，最後才關 Backend Mode 並開 Registration；
  使用普通 user role 驗證所有自助頁，不能只用 admin 帳戶驗收。

**退出條件：** 邀請的普通使用者能安全註冊、讀文件、管理自己的 Key，零
餘額不能消費，無法存取其他帳戶／管理端資料。

## Phase 3：付款與對帳

首期選 **一個** provider。面向香港／國際使用者可先評估 Stripe；面向
Alipay／WeChat 使用者則核對官方商戶或 EasyPay provider 的資格與結算。
選擇依 merchant eligibility、費用、退款、幣種與支援地區決定，不因 emooo
顯示 Alipay 就假定你能使用相同供應商。本次沒有替使用者申請商戶或付款。

- [ ] 核實所選 provider 的測試環境能力；在 staging／mock 驗證入帳與
  錯誤路徑，確有 sandbox 支援才串接。`v0.2.11` 官方 Alipay 固定正式 SDK
  環境，沒有 UI sandbox 切換；需要 sandbox 時另評估程式修改或 provider。
- [ ] 設定最小／最大金額、pending、timeout、settlement currency、
  Balance Recharge Multiplier、Recharge Fee Rate；寫清費用與退款規則。
- [ ] Alipay 選官方或 EasyPay，填服務商設定並啟用 instance／supported type；
  前台 Alipay 按鈕額外選 `official_alipay` 或 `easypay_alipay` 來源。
- [ ] 正式 merchant secrets 由使用者放入 app 的 provider 設定；不存進
  repo、Markdown、shell history 或截圖。確保 DB／backup 存取受控。
- [ ] Stripe callback 候選為
  `https://sub2api.byte612.com/api/v1/payment/webhook/stripe`；官方指南要求
  `payment_intent.succeeded`、`payment_intent.payment_failed`。其他 provider
  路徑為相同 prefix 下的 `easypay`、`alipay`、`wxpay`。以選定版本與
  provider 官方文件核對後註冊 endpoint。
- [ ] 由 infra 處理 callback 的 HTTPS／WAF 可達性，讓 provider 能送達
  app；仍由 app 驗簽。不得為方便 callback 廣泛解除整站保護。
- [ ] 驗證 PENDING → PAID → COMPLETED；只有服務端可信結果可以加值，
  return page／成功畫面不能作為付款證明。
- [ ] 驗證重送 callback 不重複加值、無效簽名／錯誤 amount／currency 不
  入帳、失敗／逾時／取消不加值、瀏覽器提早關閉仍可完成並查單。
- [ ] 測 provider 暫時失敗、PAID 但 fulfillment 失敗的重試／告警與恢復，
  保留可對帳的 order IDs，避免再造一筆付款補救。
- [ ] 驗證低餘額與不足餘額的 API debit，兩個並行請求不造成未預期負債；
  限額生效，user ledger／order／provider settlement 可核對。
- [ ] 驗證退款、已消費 credit、重複退款、失敗退款及人工例外政策。
  本次沒有實際進行付款、退款或產生外部訂單。
- [ ] 每日對帳收入、完成 orders、入帳 credit、API debit、退款與 provider
  settlement；先人工核對少量 beta orders 再自動化。

**退出條件：** 可用測試環境與入帳／錯誤驗收通過後，由使用者完成小額正式付款／退款測試，
驗證實際到帳及帳目一致。之後才對外宣稱可收款。

## Phase 4：公開 API 與 beta 容量驗收

此 repo 保持無 host ports、private DB／Redis 和 external ingress 宣告。
Nginx／TLS／CDN／DNS／firewall 的操作與驗收交由 `/srv/stacks/vps-infra`，
不能在 Relay 加第二套公開 Nginx 或直接公開 8080。

| 驗收 | 負責 | 成功條件 |
|---|---|---|
| 無瀏覽器 API | Relay 功能 + infra 入口 | 外部 SDK 正常鑑權及回覆；不要求 Cloudflare browser cookie／challenge |
| SSE／WebSocket | Relay + infra | 長回覆逐段到達；不被 gzip／buffering／不適當 write timeout 中斷；client cancellation 正確傳播 |
| TLS／DNS／IPv4／IPv6／webhook | infra | 客戶網路與 provider 可達；憑證／路由正確 |
| Client IP／ACL／rate limits | Relay + infra | 合法 proxy chain 提供正確 client IP；偽造 headers 不可繞過；NAT 客戶不誤判 |
| user／group／Key isolation | Relay | 多 Key 不繞過 user concurrency／RPM；其他 user 的 Key、usage、orders 不可讀取 |
| 付費限額 | Relay | 餘額不足、消費 quota、concurrency、RPM 各有可預期錯誤，未轉送或未扣錯款 |
| 上游失敗 | Relay | 429／失效 token／容量滿／provider outage 不錯扣；自動／人工恢復流程清楚 |
| Restore／recreate | Relay | 可還原、重新建立相符 image，資料和限額不丟失；正式 restore 仍需明確確認 |

以使用者核准的測試成本上限壓測 1／2／5 個並行串流，逐步增加，不先用
大量付費 token。記錄成功率、TTFT、p95 latency、429、queue／timeouts、
memory peak、DB connections、Redis eviction、磁碟與上游 quota；據此
決定邀請數。單次 69 MiB memory 或 UI capacity 10 不能代替測試。

Redis 與 PostgreSQL 同時供 New API 使用；Redis DB 0／1 是邏輯分開，
不是獨立容量。`allkeys-lru` eviction、連線與 CPU 必須連同兩個 app 觀察，
不為 Sub2API 測試改動 New API 設定。

## Phase 5：由封閉 beta 到公開註冊

- [ ] 先邀請約 5–10 位測試使用者，觀察至少一個完整對帳與備份周期；
  人數與觀察時段依實測容量決定，不是發布時間承諾。
- [ ] beta 沒有未處理的錯扣、付款漏帳、私密資料跨帳戶存取、容量失控；
  告警、客服、退款、備份排程及供應故障流程可執行。
- [ ] 所有驗收通過後才取消邀請限制，保留驗證、CAPTCHA、zero starting
  balance 與保守限額。公開容量逐步增加，保留暫停新註冊／新付款能力。
- [ ] 公開後按實際需求才評估訂閱、原生 Claude／Gemini、affiliate、
  圖片／影片及工單客製；不把它們列成第一版必要功能。
- [ ] emooo 的工單、影片工作室、公開排行及 QQ bot 綁定各自評估；
  不將 Custom Menu Pages 誤當完整 backend 功能。模組範圍見功能設定指南。

## 決策與變更責任

執行前需由使用者決定主要客群、供應商、商戶 provider、收款貨幣、credit
定義及可承擔的 beta 損失。技術端可先做復原／版本／目錄準備，不因這些
尚未定案就套用 emooo 的參數。

Relay repo 管理 app image、config、備份及驗收；app DB settings 的變更需
另外記錄。任何 infra route／firewall／DNS／CDN 修改循 infra repo 流程，
正式備份還原或 secret 替換仍遵守 AGENTS.md 的明確確認要求。

停止擴張的條件包括：付款與 credit 對帳不一致、無法復原、供應不持續、
正常 SDK 被 challenge、長串流不穩定或限額不能約束消費。此時先停止新
註冊／新收款，處理現有客戶及未完成 orders；不要以清空 volumes 或降版
到舊 schema 修復。
