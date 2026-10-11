# byte612 功能差異與設定操作指南

**日期：** 2026-10-01（Asia/Hong_Kong）。
**基準：** byte612 實際運行 `v0.2.11`，官方 commit
`96f4c115c9749078f90cbf210a01d39baf3f53b6`。
**狀態：** 2026-10-01 的唯讀查核與操作參考；當時的「未啟用」欄位已過時。
2026-10-11 正式站已套用 ByteAPI 自訂首頁並啟用 Stripe CNY 充值，
付款頁提供微信支付或信用卡，執行檔為 `0.2.15`。請先讀
[現況紀錄](current-state.md)；下列 `v0.2.11` 程式碼連結保留作歷史參考，
不能直接當作現行 UI 或商戶狀態。
配套：[三方比較](sub2api-public-service-comparison.md)、
[公開服務實施計畫](sub2api-public-service-plan.md)。

## 1. 哪些功能已有，哪些需要額外實作

2026-10-01 查核時，byte612 已有可用渠道、渠道狀態／探針、模型廣場及個人資料。
註冊 email 驗證碼與 Alipay 也是內建功能，當時尚未啟用。emooo 的完整工單、影片
工作室、公開排行榜及 QQ 機器人綁定，則超出這個官方版本的前台模組。

| 使用者提出的功能 | emooo 實際頁面 | byte612／官方於 2026-10-01 的狀態 | 設定或開發方式 |
|---|---|---|---|
| 客製首頁 | `/home`，EMOAI landing page、FAQ、CTA、網路與費率介紹 | `/home` 是官方預設；Home Page Content 空白 | General → Home Page Content，填 HTML 或可嵌入 URL |
| 可用渠道 | `/available-channels`，8 channels／8 groups／41 models | [Available Channels](https://sub2api.byte612.com/available-channels) 已有 `openai-real-sub` | Feature Switches + Channels → Channel Pricing；整理商品資料 |
| 渠道探針 | `/monitor`，真實請求被動採樣、TTFT、cache、矩陣及額外能力測試 | [Channel Status](https://sub2api.byte612.com/monitor) 已有 `test-01` 主動探針 | V1／V2 監控模式與管理設定；額外 benchmark 另開發 |
| 模型廣場 | `/model-plaza?embedded=1`，用途篩選、8 groups／41 models、折扣／參考價 | [Model Plaza](https://sub2api.byte612.com/model-plaza) 已有 `codex` 價格表 | Feature Switches → Model Plaza；入口在頁首及首頁 |
| 我的工單 | `/support`，提交入口、狀態列表及對話區 | core router／backend routes 未見對應工單模組 | 額外工單服務或 frontend／backend 模組 |
| 影片創作 | `/video-studio`，prompt、首幀上傳、Key、model、時長及解析度 | core 有 Videos API，但未見這個工作室 route；此帳戶在 emooo 無可用影片 Key／model | 額外工作室 + 真正支援影片的供應與計費 |
| 排行榜 | `/leaderboard`，token／邀請／儲值、時段及 Top 10 | 未見此獨立公開頁；管理／監控中的 user ranking 並非同一產品 | 額外聚合與公開頁，訂定匿名化／參與規則 |
| 個人資料 | `/profile`，帳戶與安全資訊重新排版 | [Profile](https://sub2api.byte612.com/profile) 已存在 | 原生頁面；2FA／Passkey／OAuth 功能另有前置設定 |
| QQ 帳號綁定 | `/qq-bot/binding`，私訊機器人「綁定」取得連結；綁定後可查餘額 | 未見此 route 或 QQ bot 設定 | QQ bot + 一次性綁定流程 + 最小權限查詢 backend |
| 註冊 email code | 使用者報告註冊時收到驗證碼；本次未重新註冊或寄信 | Email Verification OFF，SMTP 表單隱藏 | Security → Email Verification；Email → SMTP |
| Alipay | `/purchase` 顯示 Alipay；未建立訂單或付款 | Payment OFF；官方 Alipay／EasyPay 都有實作 | Payment → provider + 前台支付方式來源 + 全域啟用 |

「帳戶與更多」是導覽分組，不能據此判斷缺少功能。管理員頁左側亦有
MY ACCOUNT 區塊；模型廣場主要在頁首，與側欄不同。以上 byte612 頁面
是在已登入管理員 session 觀察；Backend Mode ON，目前沒有證明匿名或
普通使用者可以完成所有流程。

## 2. 客製首頁、品牌與自訂選單

進入 [Settings](https://sub2api.byte612.com/admin/settings) → **General**：

1. 設定 Site Name、Site Subtitle、Site Logo、Contact Info、Documentation URL。
   文件網址填有效 HTTPS 文件頁；客服 email 可放 Contact Info。
2. API Base URL 使用 `https://sub2api.byte612.com`；SDK 範例按協議補 `/v1`。
   `api.byte612.com` 是另一套 New API，不能當作同一 Sub2API endpoint。
3. **Home Page Content** 可放自行編寫的 HTML，或以 `https://` 開頭的
   外部首頁 URL。非空內容會取代官方首頁；URL 以全頁 iframe 顯示。
4. 此版本 UI 提示 Markdown／HTML，但 `HomeView.vue` 的非 URL 分支
   實際使用 `v-html`，未做 Markdown rendering。首頁優先使用 HTML；
   不要預期貼入 Markdown 就得到完整排版。
5. 若採外部 URL，該網站需允許被嵌入，並與站點 CSP 的 frame 規則相容；
   X-Frame-Options／frame-ancestors 可能造成空白。相關 infra 改動另循
   `vps-infra` 流程。首頁 HTML 只使用可信、自有內容。
6. 若只需要簡潔官方頁，Home Page Content 留空並選 Compact Home Page。
   客製全頁 HTML 要自行提供登入、註冊、價格、文件、客服及條款連結。

建議首頁內容：商品與模型身分、API endpoint、透明價格、註冊／儲值／Key
使用步驟、服務狀態、退款與客服。emooo 的 uptime、TTFB 等是其頁面宣稱，
不是本站實測；不要複製成 byte612 的服務承諾。其首頁標示「¥1 得 $1 額度」，
本次未以付款驗證。

**Custom Menu Pages** 可增加側欄入口，設定 label、URL、user／admin 可見性
及排序，生成 `/custom/:id`。URL 入口主要是 iframe；官方也有 Markdown
頁面模式。新增「工單」選單不會自動建立工單資料庫、客服後台或共用登入。
完整重做 dashboard、側欄分組及 emooo 的版面，通常需修改 frontend；
單一 Home Page Content 只替換首頁。

## 3. 可用渠道與模型廣場

兩頁均已啟用。管理端到 **Settings → Feature Switches** 核對 Available
Channels、Model Plaza，以及是否要求登入；再到
[Channel Pricing](https://sub2api.byte612.com/admin/channels/pricing) 維護內容。

- Channel 要綁定真正可供應的 groups，model IDs／aliases／target mappings
  與上游及 group allowlist 一致。
- 填 input、output、cache 等適用價格及 billing notes；清楚寫倍率、帳面
  credit、實際收款貨幣、原生模型或協議轉送。目錄價格不是可用性保證。
- 現有 `model-1` 沒有明確 target／價格；先釐清並整理，避免出現在公開商品。
  `test` Anthropic group 沒有供應，不能讓客戶誤以為有原生 Claude。
- `gpt-6-luna` 在目前 Plaza 顯示 input 0.10、output 0.50、cache write
  0.125、cache read 0.01（每百萬 tokens）。這是現有自訂價，不是核實成本。
- ordinary user 與匿名視角另行驗收：能看目錄、不洩露上游帳戶／token，
  並能依文件選擇可用 group／model。

## 4. 渠道探針：V1 主動與 V2 被動

byte612 現在是 **V1 active probes**。`test-01` 顯示 OpenAI／`gpt-6-luna`、
Operational；本次頁面快照 latency 2599 ms、endpoint ping 321 ms、7 日
availability 100%。它只代表此 monitor 的採樣結果，不能當作全站 SLA。
本次未按 Run Now。

| 模式 | 資料來源 | 適用情況 | 注意事項 |
|---|---|---|---|
| V1 active probes | 定時 probe；另有 quota／quota+probe 模式 | 沒有使用者流量時也希望探活 | 含 probe 的模式可能消耗 token／配額；頻率及模型數要有預算 |
| V2 passive monitoring | 真實 usage 被動聚合 | 希望看真實錯誤率、TTFT、cache、RPM／TPM | 無流量／少樣本不能推斷成功；與 synthetic availability 不同 |

若保留 V1，到
[Channel Monitor 管理頁](https://sub2api.byte612.com/admin/channels/monitor)
維護 monitor：name、provider、check mode；含 probe 時設定 API mode、endpoint、
專用且有限額的 API Key、primary／extra models，並配置 interval、jitter、enabled。
quota 模式還需關聯帳戶；是否支援組合依 provider 而定。不要使用 full-access
Admin API Key 作為模型 probe Key。

若想接近 emooo 的真實流量視角：

1. Settings → Feature Switches 將 Channel Monitor 模式選 **V2 passive**。
2. Channel Monitor → **V2 data monitor config**，配置 aggregation enabled、
   cadence、platform／model／group、minimum samples、error categories 及
   health thresholds，儲存。
3. 等 background history aggregation 及實際使用量，核對 `/monitor`。
   官方 V2 有 90m／24h／7d／30d、矩陣／趨勢、錯誤率、TTFT P50 和 cache。
4. V1／V2 是系統模式選擇；官方說明切到 V2 後 V1 active probes 不跑，
   反之 V1 時 V2 聚合不跑。僅切到管理頁的 V2 tab 不代表改了系統模式。

emooo 的頁面明示被動採樣，並有官方狀態、9 個 monitor groups／10 條線及
額外 SVG「智力參考」測試中心。這些完整版面與能力測試不能保證靠切 V2
就全部得到；少樣本／預設綠色亦不等於實測 100% 可用。

## 5. 註冊 email 驗證碼：SMTP 操作步驟

這是官方內建功能，不需額外註冊外掛。byte612 的 **Registration OFF**、
**Email Verification OFF**、**Backend Mode ON** 需要配合處理。

1. 先選 SMTP provider，取得 host、submission port、username、SMTP password／
   app password、已驗證的 From address。這些尚未選定／驗收；不把一般
   email 登入密碼當作任何 provider 都接受的 SMTP password。
2. Settings → **Security → Email Verification** 設為 ON。保留 Registration
   關閉，先準備寄信。Email tab 的 SMTP 區只在驗證開關開啟時顯示。
3. Settings → **Email** 填以下欄位，並保持 TLS enabled：

   | UI 欄位 | 設定 identifier | 如何填 |
   |---|---|---|
   | SMTP Host | `smtp_host` | provider 提供的 SMTP hostname |
   | SMTP Port | `smtp_port` | provider 指定，常見 587 或 465 |
   | SMTP Username | `smtp_username` | provider 帳號／SMTP username |
   | SMTP Password | `smtp_password` | provider 的 SMTP credential，由使用者安全輸入 |
   | From Email | `smtp_from_email` | provider 已驗證的寄件地址 |
   | From Name | `smtp_from_name` | 正式品牌名稱，例如 byte612 |
   | Use TLS | `smtp_use_tls` | ON；不要為解決寄信失敗關閉 TLS |

4. 執行 **Test SMTP Connection**，再對明確授權的測試收件地址執行
   **Send Test Email**。連線成功不等於送達；查看 inbox／spam 及 provider log。
   此版本會先嘗試 implicit TLS，遇 587 類型 greeting 轉強制 STARTTLS，
   依 provider 要求使用正確 port。
5. **Save Settings** 保存 SMTP 與驗證設定。測試按鈕可使用尚未保存的表單，
   真正註冊寄信從 DB settings 讀取；測試成功後沒儲存仍可能失敗。
6. Email Templates 可調整 Email Verification Code 的 subject／HTML，保留
   `{{verification_code}}`、`{{expires_in_minutes}}` 等必要 placeholders。
   先沿用官方模板即可；另把 Recharge Page URL 改為
   `https://sub2api.byte612.com/purchase`，不要保留舊 IP／8080。
7. 完成 SMTP、邀請限制、CAPTCHA 與使用限額後，才 General → Backend Mode
   OFF、Security → Enable Registration ON；先邀請制測試，再公開。
8. 用普通 user 測試寄 code、正確 code、錯誤／過期 code、重送、註冊及
   password reset；核對不驗證不能完成受限註冊。不要只用 admin session 驗收。

寄件網域的 SPF／DKIM／DMARC 依 provider 配置，由 DNS／infra owner 處理。
這些不會因 Sub2API SMTP 表單儲存而自動完成。SMTP 設定主要在應用資料庫，
不是把上述 identifiers 全寫入部署 `.env` 就完成。

### 免費寄信：建議先用 Resend Free

Sub2API 的 email verification 功能本身不收額外費用，SMTP 可以使用免費
方案，無需為此先升級 Cloudflare。2026-10-01 查閱 provider 官方頁面：

| 方案 | 免費額度 | 適用方式 |
|---|---|---|
| Resend Free | 每月 3,000 封、每日最多 100 封 | SMTP + 自有 verified domain |
| Brevo Free SMTP | 每日最多 300 封 | 交易郵件 SMTP；依帳戶啟用／審核要求 |

這些是郵件數，不是新用戶數；重送 code、password reset、付款通知及其他
郵件都要納入配額。正式送給其他使用者前需完成寄件網域驗證及 provider
要求，免費方案仍有配額／濫用政策；超額不代表仍能正常寄出驗證碼。

建議操作：註冊 Resend Free → 加入寄件網域／子網域 → 由 DNS owner 在
Cloudflare 加入 Resend 畫面指定的 records → 等 verified → 建立專用寄信
API Key → 填 Sub2API SMTP → 測試與儲存 → 最後開邀請制註冊。

| Sub2API 欄位 | Resend 設定 |
|---|---|
| SMTP Host | `smtp.resend.com` |
| SMTP Port | `465` |
| Use TLS | ON |
| SMTP Username | `resend` |
| SMTP Password | 專用 Resend API Key，由使用者安全輸入 |
| From Email | verified domain 下的地址，例如 `noreply@byte612.com` |

資料及 DNS 已就緒時，設定與寄信驗收預留約 30–60 分鐘；DNS 驗證／provider
審核可能延長，這是工作估算，不是送達承諾。本次未建立 provider 帳戶、
API Key 或變更 DNS，也未測試正式寄信。

來源：[Resend pricing](https://resend.com/pricing)、
[Resend SMTP](https://resend.com/docs/send-with-smtp)、
[Brevo Free SMTP](https://www.brevo.com/free-smtp-server/)。

### Cloudflare 網域與 SMTP 的關係

在 Cloudflare 註冊／續租 `byte612.com` 提供網域及 DNS 管理，不會自動
產生 SMTP 帳號。Email Routing 是收信／轉寄，例如把 `support@byte612.com`
收到的信轉到自己的信箱；它和寄出註冊驗證碼是不同的服務。

2026-10-01 再查官方文件，Cloudflare 已提供 **Email Sending Beta**，
可由 SMTP 寄交易型郵件，overview 標示一般 outbound sending 適用 Workers
Paid plan。若帳戶有此服務，先在 **Compute → Email Service → Email Sending**
開通並 Onboard Domain，完成寄件網域驗證，再準備具 **Email Sending: Edit**
權限的 API token。實際可用資格、配額及費用以帳戶和當時官方說明為準。

| Sub2API SMTP 欄位 | Cloudflare Email Sending 對應值 |
|---|---|
| SMTP Host | `smtp.mx.cloudflare.net` |
| SMTP Port | `465` |
| Use TLS | ON，implicit TLS |
| SMTP Username | 固定字串 `api_token` |
| SMTP Password | 專用 Cloudflare API token；不是 Cloudflare 登入密碼／Global API Key |
| From Email | 已 onboard 網域的寄件地址，例如 `noreply@byte612.com` |

Cloudflare 此 SMTP endpoint 不提供 587 STARTTLS；不要將一般 SMTP 範例的
587 原樣套過來。依 Sub2API 的 implicit TLS／AUTH 實作，介面具備對接條件，
但本次沒有檢查使用者 Cloudflare 帳戶或實測寄信。帳戶若未開通此 beta，
可另選提供 SMTP 的交易郵件服務；Cloudflare 繼續管理寄件驗證 DNS。

參考：[Cloudflare Email Service](https://developers.cloudflare.com/email-service/)、
[Email Sending 開通步驟](https://developers.cloudflare.com/email-service/get-started/send-emails/)、
[SMTP 官方參數](https://developers.cloudflare.com/email-service/api/send-emails/smtp/)。

## 6. Alipay 收款：官方或 EasyPay 兩條路徑

官方內建付款，不需為基本儲值另裝 Sub2ApiPay。emooo 的 Alipay 按鈕不能
辨認其使用官方直連、EasyPay 或客製整合；本次未付款、未取得其商戶設定。

| 路徑 | 必要資料 | 特性與前置條件 |
|---|---|---|
| 官方 Alipay | AppID、RSA2 應用私鑰、支付寶公鑰 | 自己具備商戶／應用及所用支付產品權限；直接對接官方 |
| EasyPay Alipay | PID、PKey、API Base URL；可選 Alipay channel ID | 兼容易支付協議的商戶服務；資格、費用、結算及退款依 provider |

官方文件包含第三方商戶推薦與宣傳費率；本指南沒有核實或背書那些條件。
選擇依實際商戶資格、使用者地區、結算貨幣、費用、退款與可接受的業務決定。

### 官方 Alipay 是商戶 API 流程，帳戶可為合資格個人經營者或企業

對照 `v0.2.11` 實作，官方 provider 使用 AppID、RSA2 應用私鑰及支付寶
公鑰建立 SDK client，以商戶訂單編號／金額建單，再驗證非同步通知。
桌面預設呼叫 `alipay.trade.precreate`（當面付），失敗時回退
`alipay.trade.page.pay`；mobile 預設 `alipay.trade.wap.pay`。回退產品同樣
需要開通權限，並不是當面付失敗就能無條件完成付款。

因此它面向自動收款營運，沒有用個人靜態收款碼取代支付 API。程式要求
API 憑證與產品權限，不以「是否有限公司」作判斷；合資格個人經營者若
已取得適用權限可評估接入，但普通個人錢包／有收款碼並不足夠。

2026-10-01 追加 emooo 10 元 checkout 測試：QR 指向 `qr.alipay.com/bax…`，
形態與商戶 QR 流程相容，但仍不足以辨識帳戶類型或 provider。沒有付款，
待付款訂單已取消，詳見三方比較的追加證據。

### 路徑 A：官方 Alipay

**已有中國內地個人支付寶的情況：** 2026-10-01 核對
[官方當面付申請資料](https://opendocs.alipay.com/b/09ihsa)，文件列出個人
帳戶可申請，需經營名稱、地址及場景照片；營業執照非強制，但未提供時
收款額度受限。這不等於普通個人錢包／靜態收款碼已有 API 權限，也不保證
適合純線上 AI API relay。需要分別確認商戶身份、業務類目、當面付或
網站支付等產品及使用場景，不能套用不實門店資料申請。

1. 完成官方商戶／應用準備，取得同一應用的 AppID 及 RSA2 keys，確認
   已開通要使用的產品。不要把「應用公鑰」誤填成「支付寶公鑰」。
2. Settings → **Payment → Enable Payment**，展開基本設定與 Providers。
   這是預備操作；在封閉／staging 環境配置驗收，正式不先曝光未完成付款。
3. **Add Provider → Alipay**：填 `appId`、`privateKey`、`publicKey`，
   supported payment types 選 Alipay，確認 instance enabled 及實例限額。
4. 確認自動產生的 Notify URL 及 Return URL domain 都是 Sub2API 網域。
5. 前台可見支付方式啟用 **Alipay**，來源選 **Official Alipay**
   （`official_alipay`），再儲存設定。
6. 桌面預設當面付 QR 優先，無法使用時回退電腦網站支付；mobile 預設 WAP。
   只有開通當面付後才評估 mobile precreate deep link，不必為顯示按鈕開它。

### 路徑 B：EasyPay Alipay

1. 取得選定 provider 的 PID、PKey、正式 API Base URL，核實 Alipay 已開通。
2. Payment → **Add Provider → EasyPay**，填 `pid`、`pkey`、`apiBase`；
   有指定渠道才填 `cidAlipay`。supported types 包含 Alipay、instance enabled。
3. 核對 callback domain、全域／實例限額及 provider 要求的支付模式。
4. 前台 Alipay 來源選 **EasyPay Alipay**（`easypay_alipay`），儲存。
   同時存在兩類 provider 也只為這個按鈕選一個來源，不是自動雙來源。

### 儲值換算與 callback：兩條路徑都要完成

- **Balance Recharge Multiplier**（`payment_balance_recharge_multiplier`）
  控制每 1 CNY 基本金額獲得多少帳面 USD 餘額。例如 multiplier 1、
  recharge amount 10、fee 0 時，支付 10 CNY、增加 10 USD 帳面額度；這是
  商品 credit 換算，不是現金 USD 或市場匯率。應按上游成本及售價決定。
- **Recharge Fee Rate**（`payment_recharge_fee_rate`）是額外向客戶收的
  手續費；與 provider 從結算收入扣的商戶費用不同。
  **Subscription USD to CNY Rate** 用於訂閱換算，不要拿它代替餘額充值倍率。
- 設置 minimum／maximum amount、daily cap、max pending orders、timeout、
  instance limits 及退款規則，頁面說明與實際入帳必須一致。

| URL 類型 | byte612 正確路徑 |
|---|---|
| 官方 Alipay 非同步 Notify | `https://sub2api.byte612.com/api/v1/payment/webhook/alipay` |
| EasyPay 非同步 Notify | `https://sub2api.byte612.com/api/v1/payment/webhook/easypay` |
| Browser Return | `https://sub2api.byte612.com/payment/result` |

Return 是瀏覽器跳轉，不是可信付款證明。應用驗簽／查單後由 PENDING →
PAID → COMPLETED 才完成入帳。callback 建議自動產生，但仍需核對
API Base URL／domain。provider 必須能送達 HTTPS callback；WAF／TLS／
proxy 的必要調整屬 `vps-infra`，不能直接公開 app 8080 或解除整站保護。

**測試限制：** 此版本 Alipay `getClient()` 固定 `alipay.New(..., true)`，
provider dialog 沒有 sandbox／gateway 欄位；不能保證換成 sandbox keys
即可測試。先以 staging／mock 驗證入帳與錯誤路徑；如需真實 sandbox，另
評估小範圍程式修改或使用已確認提供測試環境的 provider。最後由使用者
完成小額正式付款／退款，核對商戶實收、order、user credit 及 ledger。

驗收至少包括：重送 callback 不重複入帳、無效簽名／錯誤金額不入帳、
逾時／取消、關閉瀏覽器後仍能完成、支付成功但入帳失敗的重試、退款與
已消費 credit 處理。本次沒有建立訂單、付款、寄測試信或填入商戶秘密。

### 接入時間、WeChat Pay 與 Stripe

以下是安排工作的估算，不是支付平台審核 SLA：已有有效商戶憑證及支付
產品權限時，provider／callback／前台設定約 30–90 分鐘，端到端付款、
重送、取消、入帳與退款驗收另預留半日至一日。若要從零申請商戶，審核／
補件／產品開通可能需數個工作日至數週，甚至因地區或資格不符合無法開通；
應先向實際 provider 確認，不能承諾同日收款。

官方亦有 WeChat Pay 與 Stripe。WeChat Pay 可用官方 APIv3 或 EasyPay；
官方路徑需 AppID、MchID、商戶私鑰、APIv3 key、微信支付公鑰及 ID、證書
序號。Stripe 需 Secret Key、Publishable Key、Webhook Secret；其可用支付
方法依帳戶地區、資格及開通狀態，不是勾選後就全部可用。

### 香港個人：優先評估 Stripe，再在 Stripe 內啟用 Alipay

使用者已說明申請身份為香港個人，尚未確認是否已有商戶帳戶。Stripe
香港官方支援頁提及 individual 申請與 HKID 驗證；沒有 HKID、但有 BRN
者可選 Sole Proprietorship。這表示不應一概認定必須有限公司，但是否
接納此人／此業務及實際文件要求仍以 Stripe onboarding 為準；支付平台
帳戶類型亦不代替香港本地商業登記要求。

Stripe 官方 Alipay 文件列出 HK 為支援商戶地區，提供另一條路徑：
**申請 Stripe → 在 Stripe 開通 Alipay → Sub2API 使用 Stripe provider**。
這條路徑不需要在 Sub2API 再填官方 Alipay AppID／RSA2 keys。

1. 準備身份、銀行／結算資料、真實業務描述、服務網址、價格、客服與退款
   政策，建立 Stripe 帳戶及完成 Dashboard 要求的驗證。業務描述應如實
   說明 AI API relay／按量使用額度；不假稱一般商品，也不保證平台接納。
2. 先使用 Stripe sandbox 的 test Secret／Publishable Keys。
3. Sub2API → Settings → Payment，啟用 Stripe 支付類型、Add Provider →
   Stripe，填 `secretKey`、`publishableKey`、`webhookSecret` 及 currency。
   首先只選 `card`；不要保留不明確的貨幣預設或假設自動換算成 USD 額度。
4. 在對應 test 環境建立 webhook endpoint：
   `https://sub2api.byte612.com/api/v1/payment/webhook/stripe`，事件依官方
   Sub2API 指南選 `payment_intent.succeeded`、`payment_intent.payment_failed`。
   對應 endpoint 的 signing secret 填入 provider；正式 endpoint／keys
   與 test 環境分別配置，不能混用。
5. 設定支付限額、充值倍率／費用、instance enabled 及全域 Payment。
   在封閉環境完成測試卡、callback 重送、入帳、失敗及退款驗收。
6. Stripe Dashboard → Payment methods，開通 **Alipay**；若要求額外
   審核先完成。Sub2API Stripe instance 的 supported methods 加上 `alipay`，
   即讓 Stripe PaymentIntent／Payment Element 提供此方法。
7. Stripe 內的 Alipay 和 Sub2API 頂層「Alipay → official／EasyPay」按鈕
   來源不同。這條路讓使用者進入 Stripe 付款頁後選 Alipay，不需把
   頂層 Alipay 來源改成 Stripe（該來源選項沒有 Stripe）。
8. 只有商戶 live mode 可用、實際貨幣／credit 換算及測試全部核對後，
   才換正式 keys／endpoint secret，由使用者完成小額正式付款並驗實收。

Stripe Alipay 支援不代表一定支援 AlipayHK 錢包；實際錢包與方法依 Stripe
文件／帳戶及付款頁為準。付款通知亦需 infra HTTPS／WAF 可達，由 infra
owner 處理；本次沒有檢查或修改入口設定。

工時估算：有效商戶及 keys 已就緒時，Sub2API／Stripe webhook 設定約
1–2 小時，完整測試另預留半日至一日。新商戶驗證／補件及 Alipay 開通
可能需數個工作日至數週；沒有官方固定核准時間，也可能不獲接納。
技術設定完成、可正式收款、款項實際結算到銀行是三個不同時間點。

來源：[Stripe 香港商戶要求](https://support.stripe.com/questions/requirements-for-hong-kong-based-businesses)、
[Stripe 帳戶啟用](https://docs.stripe.com/get-started/account/set-up)、
[Stripe Alipay](https://docs.stripe.com/payments/alipay)、
[Sub2API Stripe 實作](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/payment/provider/stripe.go)。

## 7. 工單、影片、排行榜及 QQ 的建議實作範圍

這四項建議放在核心收費服務穩定之後，逐項追加。不能只靠新增 Custom
Menu Pages 或 Contact Info 取得 emooo 的 backend 能力；也無證據可確認
其原始碼／外掛公開可取得。

| 功能 | 第一階段可行方案 | 完整實作需要 |
|---|---|---|
| 工單 | 正式客服 email + 文件／Contact Info；需要工單再整合現成系統 | 使用者／客服角色、ticket ownership、對話、附件、通知、狀態及管理端 |
| 影片 | 首版先維持 API 服務；有穩定影片供應才做工作室 | upload、async jobs、polling、結果保存、失敗退款、模型與時長計價、user quota |
| 排行榜 | 首版保留私人的用量／訂單；公開排行另訂規則 | 聚合窗口、匿名化、opt-out、幣種分開、資料存取與防灌榜 |
| QQ 綁定 | 先公開一般客服聯絡方式；需要 bot 才開發 | bot 平台接入、短效一次性綁定連結、user confirmation、解除／重綁、防冒綁與受限查詢 |

整合外部服務需設計身份與存取，不把 Sub2API JWT、完整 Key、Admin API
Key 放 iframe URL 或前台 JavaScript。將導覽分組改名為「帳戶與更多」
只是 UI 工作；若要維護 fork，使用固定 image、可重建 build、版本更新與
回歸驗收流程，避免直接改正式容器檔案。

**QQ bot 是甚麼：** QQ 是騰訊的即時通訊平台；bot 是用程式自動回應
訊息的機器人，不一定使用 AI。emooo 頁面所描述的例子是私訊 bot「綁定」，
開啟它提供的連結確認帳戶關聯，之後傳「查餘額」取得該網站帳戶的餘額。
本次只確認頁面說明，未綁定或實際操作 bot；不知道 emooo 使用哪套 bot
技術。這屬方便既有 QQ 使用者的附加功能，不是註冊／API／付款的必要條件。

## 8. 建議執行順序與尚待提供的資料

以下是 2026-10-01 的規劃順序；品牌首頁與 Stripe 充值已在 10 月 11 日上線，
但未完成的驗收項目仍需按最新狀態逐項確認。

1. 完成既有 restore TODO，並將 Compose image 與 runtime 固定在相同的
   `0.2.15`；整理在售 models／價格／供應。
2. 核對品牌、客製首頁、文件與客服入口；沿用已有渠道／Plaza／Profile。
3. 選 V1 或 V2 監控，明確定義少樣本／無流量的顯示及 probe 成本。
4. 準備 SMTP、email code、邀請註冊與限額，普通 user 完成 beta 流程。
5. 核對現有 Stripe 微信支付或信用卡的 callback、入帳、失敗與對帳流程；
   Alipay 官方或 EasyPay 僅作備選，不視為已上線。
6. 根據實際客戶需求再增加工單；影片、排行與 QQ 各自評估供應與開發成本。

後續設定所需資料：SMTP provider／verified sender／credentials、付款商戶
provider／credentials／資格與支付產品、充值倍率／手續費／限額、正式品牌
與文件內容。敏感資料由使用者安全輸入，不放此文件或 Git。

## 官方固定版本參考

- [Frontend routes](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/frontend/src/router/index.ts)
- [Settings UI](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/frontend/src/views/admin/SettingsView.vue)
- [HomeView](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/frontend/src/views/HomeView.vue)
- [CustomPageView](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/frontend/src/views/user/CustomPageView.vue)
- [V1 Monitor form](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/frontend/src/components/admin/monitor/MonitorFormDialog.vue)
- [V2 Monitor 設定與介面說明](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/frontend/src/i18n/locales/en/channelMonitorV2.ts)
- [SMTP service](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/service/email_service.go)
- [付款指南](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/docs/PAYMENT_CN.md)
- [Provider fields／callback paths](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/frontend/src/components/payment/providerConfig.ts)
- [Alipay provider](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/payment/provider/alipay.go)
- [訂單與 credit 換算](https://github.com/Wei-Shaw/sub2api/blob/96f4c115c9749078f90cbf210a01d39baf3f53b6/backend/internal/service/payment_order.go)
