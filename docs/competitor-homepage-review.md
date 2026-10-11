# 競品首頁、公告與模型目錄研究：EMOAI 與 TiMi CC

**檢查日期：** 2026-10-04（Asia/Hong_Kong；頁面檢視於本次瀏覽器工作階段）

**目的：** 為 byte612 / Sub2API 的公開網站規劃蒐集首頁、公告、模型目錄與 onboarding 參考。
**範圍：** 公開頁面及已登入使用者可見頁面；不登入管理後台、不下單、不付款、不修改競品設定。
**時效：** 這是 2026-10-04 的設計研究；「付款尚未開放」只描述當時的
byte612。2026-10-11 已上線自訂首頁與 Stripe 充值，最新狀態見
[現況紀錄](current-state.md)。

## 摘要

- **EMOAI** 的首頁把品牌定位、服務數字、模型與價格、使用流程、FAQ、文件和 CTA 串成完整銷售旅程。可參考它的資訊層次與價格解釋方式；其服務數字、折扣、可用量及支付換算均是網站宣稱，沒有獨立驗證。
- **TiMi CC** 首頁較精簡，主要提供品牌入口、公告、狀態、教程及 Dashboard；產品解釋較多放在文件首頁和登入後的 Model Plaza。值得參考公告／狀態入口及依供應商、模型家族和分組瀏覽的方式。
- byte612 宜做**自有品牌、面向實際供應能力的首頁**，並把即將推出的付款與當前可用 API 清楚區分。首頁不宜照搬競品的品牌、行銷文案、倍率、服務指標或上游身分宣稱。
- 公開前優先建立可信的商品目錄和 onboarding：訪客能理解可用模型、實際轉送方式、計費單位、API endpoint、註冊／取得 Key 步驟及服務限制。2026-10-04 當時支付尚未開放；此項建議已由後續上線取代。

## 檢視證據與限制

| 類別 | 本次觀察 | 限制 |
|---|---|---|
| EMOAI 首頁、公告、Available Channels、Model Pricing、接入文件 | 以公開／一般使用者介面查看 | 未查看其管理後台、程式碼、供應商協議或真實服務紀錄 |
| TiMi CC 首頁、文件首頁、登入後 Dashboard、Model Plaza、公告 | 以瀏覽器呈現的使用者頁面查看 | 未查看管理後台、供應商協議或付款流程，也未驗證公告描述的上游狀態 |
| 網站數字、價格與貨幣 | 逐項記為「網站標示／宣稱」 | 未以 API 壓測、獨立支付或上游帳單驗證 |
| HTML／前端實作 | 本稿依畫面和頁面互動整理 | 未下載或保存完整 HTML；頁面可能登入後動態載入，前端可見內容不代表後端設定 |

本次沒有付款、建立訂單、建立 API Key、修改網站資料或操作管理功能。瀏覽 TiMi 公告時，開啟的公告會由網站自動標記已讀：未讀數由 13 降為 8；沒有使用「全部標為已讀」。這是瀏覽器帳戶狀態變更，並非服務設定變更。

下列首頁盤點是依頁面由上而下的可見內容和互動控制整理。為供自有設計參考，段落文案採貼近原意的摘要；短標題、按鈕名稱、數值和連結文字保留原樣。未把整頁文案逐字複製。

## EMOAI

### 首頁設計與資訊順序

首頁採深色終端／網格視覺，頂部有狀態 ticker、主導覽與醒目的雙 CTA。主要內容依序呈現：

1. 服務定位及立即註冊／查看價格入口。
2. 模擬 relay feed、模型品牌列與服務數字。
3. 服務價值、請求轉送流程與價格／倍率說明。
4. 支援的裝置或接入情境、FAQ、重複 CTA 和多欄 footer。

首頁寫有 `32 models online`、`0.38s TTFB`、`99.98% uptime` 等數字。這些是 EMOAI 頁面上的宣稱，不能當成本次測量或本站可以承諾的 SLA。可參考它讓訪客先看懂服務定位、再看商品、最後進入註冊的順序；byte612 不需要複製其暗色終端美術或裝飾性即時 log。

### 公告與價格訊息

本次看到兩則公告：

- 2026-10-02：伺服器升級遷移中，部分時段可能卡頓。
- 歡迎公告：介紹客服入口、低價主張及邀請返利。

首頁費率主打低倍率及免費模型，說明 PAYG、充值換算和合作入口。其「¥1 得 $1 balance」等屬商品規則／網站文字，不等於匯率或實際支付驗證。Byte612 應在支付正式上線並完成入帳對帳前，不展示可充值 CTA 或類似換算承諾。

### 渠道、分組與模型定價

- Available Channels 顯示 `9 channels / 9 groups / 51 models`，並可按 Images、Video、Chinese models、OpenAI、Claude、Gemini 等情境篩選。
- 展開模型後可查看渠道基礎價、計費模式、價格拆項及 notes。
- Model Pricing 頁則顯示 `14 groups / 63 distinct models`，與 Available Channels 頁面的數量不同。這可能是頁面範圍或帳戶可見性差異；原因未查明，不應自行推論。
- 價格表分別列出折後價／官方參考價、倍率、token／image／request 計費單位、上下文階梯及 cache read/write；缺少價格不表示免費，也不保證模型即時可用。
- 圖片與影片另列解析度、時長、按張或按請求計費，並附限制／實測提示。

此設計可降低「看到模型名稱卻不知道怎麼計費」的疑惑。byte612 應先提供與真實 channel mapping、group allowlist、billing model 和售價一致的清單；沒有供應、沒有明確 target 或未完成核價的模型不應公開展示為可購買項目。倍率要明示其計算基準、credit 定義及是否包含 cache／長上下文費用。

### Onboarding 文件

接入指南把第一個 API 呼叫拆為三步：建立 API Key、呼叫 `GET /v1/models` 查看目前 Key 可用模型、呼叫 `POST /v1/chat/completions` 發送請求。指南提醒 model ID 不等於分組名稱，不同分組可能有不同目錄、權限和價格；其他文件導覽包含文字／串流、圖片、影片、SDK、計費及錯誤排查。

可借鑑「先列出此 Key 可用模型，再複製一個最小請求」的方式。byte612 的公開文件應使用本站確認可用的 model ID 和 endpoint，至少提供 curl 範例、串流範例、錯誤碼、費用計算例子及客服／狀態入口。

## TiMi CC

### 首頁與文件首頁

TiMi CC 首頁是精簡 splash：品牌標誌、Status、Tutorial、公告、Support、語言／主題切換、Dashboard CTA、動態 tagline、模型品牌列和法律政策 footer。它把公告、服務狀態和教程放在容易找到的位置，但首頁本身對產品、價格與接入方式的說明較少。

文件首頁補充其服務定位，提及 Claude Code、Codex 等 CLI 中轉情境，列出使用亮點、快速開始及 CC-Switch／CLI／第三方接入導覽。網站文字稱約 10 分鐘接入、註冊充值後建立 Key；這些是頁面宣稱，不是本次計時驗收。

登入後 Dashboard 有 API Keys、用量、發票、退款申請、訂單、兌換及邀請返利等入口，另提供 status、AI Image、Model Plaza、Recharge 和 Tutorial 快捷入口。對 byte612 而言，可參考入口集中與常用任務捷徑；首頁是否展示登入後功能，要按第一版實際支援項目取捨。

### 公告模式

公告列表本次顯示 13 則未讀，內容偏營運通知：上游波動、調價、模型上下架、計費和安全政策。已讀取的五則涉及 Codex pool 波動、Codex Pro 價格調整、GPT-5.4 下架、長上下文 x2 說明及安全政策。

適合借鑑的是公告分類、日期、受影響模型／分組、影響期間、用戶需採取的行動，以及歷史公告可查。Byte612 可先採簡單公告頁或首頁最新公告區，付款或模型調整時說明生效時間和舊訂單／既有餘額如何處理。不要照搬第三方供應池名稱、未驗證成因或該站提出的安全操作指示。

### Model Plaza 與分組呈現

Model Plaza 顯示 23 個模型，供應商篩選包括 Anthropic 11、OpenAI 6、DeepSeek 4、Grok 2。頁面用供應商／模型家族搭配可切換的分組倍率呈現供應差異，例如 CodeX 官轉 Pro pool、team／plus pool、Claude 原生渠道、DeepSeek 和 Grok 分組。使用者可切換分組倍率；畫面標示充值換算 `CN¥1=$1 balance`，並以 USD/M 列 token 價格。

分組標籤能解釋同一模型為何有不同價格，但若描述中的帳戶類型、上游來源或模型身分不能被證明，對 byte612 就不應使用類似措辭。更穩妥的商品卡片欄位是：使用者可選模型 ID、服務商／協議類別（有證據才標）、可用分組、倍率或 input/output 單價、cache／上下文費率、限制、最近更新時間及狀態。

### 公告例子及計費說明

本次讀到的公告提到特定供應池波動、某分組調價、模型下架、長上下文階梯價格及安全政策。它們可作為「公告應回答哪些問題」的例子：哪些 model/group 受影響、何時生效、費率差異、使用者能否切換、已建立 Key 是否受影響。公告中的價格和供應描述屬 TiMi CC 自述，沒有獨立驗證。

## 首頁文字與元件盤點

### EMOAI：由上至下

| 區段 | 首頁文字／資訊（摘要） | 元件與互動 |
|---|---|---|
| 最上方狀態列 | `EMOAI RELAY`、網格狀態文字及每秒更新的時鐘 | 狀態 ticker；頁面顯示 `GRID NOMINAL` |
| 導覽 | 品牌、`WHY`、`网络`、`费率`、`FAQ`、進入控制台 | 頁內錨點 `#why`、`#arch`、`#rates`、`#faq`；明暗主題切換；Dashboard 入口 |
| Hero eyebrow／標題 | `AI TOKEN RELAY STATION`；標題主張一個令牌可接入多種前沿模型 | 大型標題、單一主動作「進入控制台」及「查看費率」次動作 |
| Hero 說明 | 描述把 Claude、OpenAI、Gemini、Grok 訂閱與上游通道聚合為 OpenAI 相容介面，並宣稱有統一調度、故障備援及 Token 計費 | 「FREE CREDITS ON SIGNUP · NO CARD · 60S SETUP」註冊提示；屬站方促銷文字 |
| 即時狀態及 feed | `LIVE`、`UPTIME 99.98%`；feed 模擬授權、chat/responses 請求、usage/cache、通道健康檢查和 failover 訊息 | 自動輪播終端 feed；時間戳與行內容持續變動。應視為首頁展示元件，未驗證為真實即時請求紀錄 |
| 指標列 | `32+ FRONTIER MODELS`、`0.38s MEDIAN TTFB`、`99.98% UPTIME · 90D`、`12.8M REQUESTS SERVED` | 四個大型數值指標；均為網站宣稱 |
| WHY EMOAI | 以「多、穩、省」概括服務價值；三項分別說明單 Key 聚合多模型、多路備援，以及按實際用量計費／快取折扣 | 三欄能力區：`ONE KEY`、`MULTI-PATH`、`FAIR RATE`；每欄短標題及敘述 |
| ARCHITECTURE | 說明請求由客戶端進入，經鑑權限流、調度核心、多通道路由，再送到模型 | 四層流程圖：Input、Auth/Core、Route/Channels、Output/Models；列出客戶端名稱、優先權／健康檢查／計量、主備通道和模型品牌 |
| 架構程式範例 | 將 OpenAI client 的 `base_url` 換成服務端點並設定遮罩 API key | 程式碼卡片；頁面使用 `example.invalid` 示意端點與遮罩金鑰。不是可直接使用的真實設定 |
| RATE SHEET | 標題主打低倍率；說明有免費模型與依分組倍率扣費的 PAYG | 免費模型卡與 PAYG 卡；倍率 `0.1×`；價格規則以公告為準。數值為站方標示，不是對 byte612 的定價建議 |
| 充值與換算文案 | 標示人民幣與美元額度 1:1 入帳，並用官方定價換算示例解釋倍率 | 換算視覺、Tier／Billing Note 區。貨幣換算和節省幅度未經本次付款驗證 |
| 同行合作 | 邀請下游服務商洽談批發倍率、獨立令牌／分組管理和 API 對接 | 合作說明卡及「联系站长洽谈」按鈕；檢視的 href 為首頁 `#`，沒有發現不同的公開表單目的地 |
| ANYWHERE | 說明可自訂 Base URL 的工具可共用同一 Key | 裝置／客戶端分區：iOS、Android、Desktop／CLI；例列 OpenCat、ChatBox、NextChat、LobeChat、Cherry Studio、Claude Code、Codex。不是每一項都代表本站已測試相容 |
| FAQ | 四題：支援哪些客戶端、如何計費及處理 cache、上游故障影響、資料安全 | Accordion。Q1 說明使用 OpenAI 相容端點或自訂 URL；Q2 描述按實際 Token 乘分組倍率、快取折扣及 reasoning 計價；Q3 宣稱健康檢查、摘除、切換和重試；Q4 宣稱 HTTPS、密鑰加密、計量日誌脫敏且不保存對話。以上安全及可靠度內容是站方說明，未獨立驗證 |
| GET STARTED | 標題主張約 60 秒接入，並提及註冊體驗額度及替換少量設定 | 重複「進入控制台」CTA |
| Footer | 品牌簡介及 `PRODUCT`、`RESOURCE`、`SUPPORT` 分欄 | 頁內入口包括架構／費率／能力／FAQ；其他可見標籤包括服務狀態、接入文檔、SDK 示例、聯絡、服務條款、隱私政策 |

**EMOAI 首頁連結檢查：** Dashboard CTA 指向 `/dashboard`；WHY、網絡、費率、FAQ 分別指向首頁片段。此次 DOM 可見的頁尾「服務狀態、接入文檔、SDK 示例、聯絡我們、服務條款、隱私政策」連結，其 href 均解析到 `https://emooo.cc/home#`，沒有指向相應獨立頁面。公開文件另可由 [docs.emooo.cc](https://docs.emooo.cc/) 開啟；首頁的「接入文檔」錨點本身沒有連至該處。這是連結目的地檢視，不代表判定其頁面不存在。

### TiMi CC：由上至下

| 區段 | 首頁文字／資訊（摘要） | 元件與互動 |
|---|---|---|
| 導覽列 | `TiMi CC`、`Status`、`Tutorial`、`Announcements`、`Support`、`EN`、`Dashboard` | Status 外連 `https://status.timicc.com/`；Tutorial 指向 `https://docs.timicc.com/`；公告與支援是按鈕，不是文字連結；語言選單、主題切換和 Dashboard 入口 |
| Hero eyebrow | `AI API Gateway · Global Acceleration` | 小型產品定位字樣 |
| Hero 主標 | 品牌字標 `TiMi CC` | 分字動畫／字距排版 |
| Hero tagline | 打字機效果的動態短句；本次不同快照曾顯示 `Hell…` 及 `Pay as you go, cancel any…` 等未完成片段 | 文字逐字顯示且會更換；擷取時不是穩定完整句，故不把片段補寫成完整原文 |
| Hero CTA | `Go to Dashboard` | 主要按鈕連至 `https://timicc.com/dashboard`；導覽列亦有 Dashboard link |
| 模型／品牌列 | `Claude`、`GPT`、`Gemini`、`Minimax`、`Timicc` | 水平品牌文字列／跑馬燈式展示；首頁未在此列出價格或計費細節 |
| Footer | `© 2026 TiMi CC. All rights reserved.` | Tutorial；`服务条款`、`使用政策`、`支持的国家和地区`、`隐私政策` |

**TiMi CC 首頁連結檢查：** 導覽列和 Hero 的 Dashboard 均連到 `/dashboard`；Tutorial 指向文件首頁；Footer 四個政策入口分別指向 `/legal/terms`、`/legal/usage-policy`、`/legal/supported-regions`、`/legal/service-specific-terms`（最後一項頁面標籤是「隱私政策」）。Status 指向獨立狀態子網域。`Announcements` 和 `Support` 在首頁是按鈕，DOM 沒有提供 `<a href>` 目的地；本次沒有開啟它們，以免公告讀取狀態再變更，也沒有提交任何客服表單。

### 可借用的互動模式

- 把產品定位、主要 CTA 和次要「看模型／看文件」入口放在首屏，確保使用者不用先猜服務用途。
- 用流程圖說明端點如何連到認證、路由、計費和輸出；用實際可運作的範例取代裝飾性終端 feed。
- 用 Accordion 收納支援範圍、計費、故障處理和資料政策，避免首頁文字過長；每項答案連到完整文件。
- 狀態、公告、Tutorial、Support 入口在 header 保持可見；政策頁在 footer 分開列出。
- 在首頁與模型目錄維持一致的模型名稱、價格、更新時間與 CTA；不能將動態假資料或未核實數字當成營運指標。

## 對 byte612 的設計建議

細部設定差距、現有服務狀態和 Sub2API 操作步驟已分別記在[公開服務比較](sub2api-public-service-comparison.md)、[公開服務實施計畫](sub2api-public-service-plan.md)及[功能設定操作指南](sub2api-feature-setup-guide.md)。本研究聚焦呈現方式，建議按以下次序落地：

### 第一階段：自有品牌首頁

1. **首屏：** 清楚說明 byte612 提供什麼 API relay 服務、目前支援的實際情境，提供一個主要 CTA（註冊／登入，依目前開放狀態切換）及一個次要 CTA（查看模型與價格或閱讀文件）。
2. **可用能力：** 只展示已配置、已驗收且有明確 target 的模型／協議。清楚區分原生供應與協議轉送，不把映射模型包裝成原廠模型。
3. **價格：** 在付款未上線時可展示已確認的計費規則，但標明付款狀態及何時開放；付款實作與測試完成前隱藏充值入口，避免收款預期。
4. **快速開始：** 以「建立帳戶 → 建立 Key → 列出可用模型 → 發第一個請求」呈現，連結可複製的 endpoint、最小 curl 範例和 API 文件。
5. **信任資訊：** 放服務狀態、公告、客服方式、退款／使用政策、資料處理說明及最後更新日期。沒有實測證據時不宣稱 uptime、TTFB 或容量。
6. **頁尾：** 提供文件、狀態、客服、服務條款、隱私和退款政策連結；連結目的地需在發布前可用。

### 第二階段：商品與營運頁

- **模型目錄：** 可依 provider／用途／協議篩選；欄位包含 model ID、可用 group、計費單位、輸入／輸出／cache 價格、倍率基準、限制、狀態和更新時間。
- **分組比較：** 只在同一模型確有多種可選供應時提供切換，切換時同步顯示價格與限制。避免單看倍率而看不見計價基準。
- **公告中心：** 最新公告在首頁摘要，完整列表按日期和類別查閱；調價、下架、事故與維護使用不同類型並明示影響範圍。
- **狀態頁：** 顯示實際探針／流量來源、樣本數、時間窗與最近更新；低樣本標示「資料不足」，不要以預設綠燈充當可用性證據。
- **引導文件：** 按第一次呼叫、模型清單、串流、錯誤／排障、計費和限額分頁，提供最小可執行範例。

### 視覺與文案方向

- 使用 byte612 自有名稱、配色、圖示和語氣。可借用清楚的區塊層次、產品截圖／模型表格和固定導覽，不仿作競品 logo、文案、頁面截圖或視覺識別。
- 首頁優先採用可掃讀的淺色或中性工作介面，價格與模型表格保持對比和密度；避免讓「裝飾性即時數字」搶過可驗證的服務資訊。
- 每個性能／可靠度數字都應附定義、測量窗口及來源。沒有足夠樣本時不公開百分比或延遲承諾。
- 公告以具體影響和處理方式為主，避免只寫「升級中」或未說明受影響的模型與期間。

## 建議驗收清單

- [ ] 首頁在匿名與一般使用者狀態可正常載入，CTA 指向真實可走通的頁面。
- [ ] 註冊未開放或付款未上線時，前台不暗示可立即使用該功能。
- [ ] 每個公開 model ID 都能由實際 Key 的 `GET /v1/models` 確認，且 request mapping、group allowlist 和價格規則一致。
- [ ] 公開價格與實際 debit 一致，涵蓋 cache、長上下文及不同媒體計價；缺價模型不被描述為免費。
- [ ] 公告／狀態顯示時間、影響範圍、更新來源及資料不足狀態。
- [ ] API 文件範例使用正式 endpoint；匿名瀏覽文件不洩露 Key、上游帳戶或管理資訊。
- [ ] 條款、隱私、退款、客服入口可用，且內容與實際營運流程一致。
- [ ] 手機與桌面版檢查首頁導航、價格表、公告文字及表格不重疊或溢出。

## 來源

- [EMOAI 首頁](https://emooo.cc/)
- [EMOAI 公告](https://emooo.cc/announcement)
- [EMOAI Available Channels](https://emooo.cc/available-channels)
- [EMOAI Model Pricing](https://emooo.cc/model-pricing)
- [EMOAI API 文件](https://docs.emooo.cc/)
- [TiMi CC 首頁](https://timicc.com/home)
- [TiMi CC 文件首頁](https://docs.timicc.com/)
- [TiMi CC 公告](https://timicc.com/announcement)
- [TiMi CC Model Plaza](https://timicc.com/model-plaza)
- [byte612 Sub2API 公開服務比較](sub2api-public-service-comparison.md)
- [byte612 公開服務實施計畫](sub2api-public-service-plan.md)
- [byte612 功能設定操作指南](sub2api-feature-setup-guide.md)
