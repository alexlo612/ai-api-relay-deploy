# AI API Relay 遷移與維運待辦

依序完成下列項目。只有實際驗證成功後才能勾選；VPS 證據記錄在
[`docs/current-state.md`](docs/current-state.md)。

## 遷移到 shared ingress

- [x] 2026-09-28：唯讀檢查確認 Relay 原工作目錄、Compose project、容器、
  network、volumes 與映像；repo `main` 和本機 checkout 同為
  `173db9a`。檢查範圍及 Cloudflare 403／origin 200 差異見
  [`docs/current-state.md`](docs/current-state.md)。
- [x] 簡化 PRD、操作文件、agent instructions 和 CI，統一 infra 與 Relay
  責任邊界，移除 app 自有 Nginx／Certbot 流程。
- [x] 固定各服務映像版本；應用與資料服務升級前先建立並驗證備份。
- [x] 驗證 Compose、ShellCheck、YAML、Markdown、secret scan 及 Redis 設定。
- [x] 在 `/home/alex/backups/ai-api-relay` 備份 PostgreSQL、Redis 及 app
  volumes；確認 checksum 並保存 image digests。此 VPS 的 `alex` 無法以
  `sudo -n` 寫入 `/var/backups`，因此使用由 `alex` 管理的備份路徑。
- [x] 將 checkout 放到 `/srv/stacks/ai-api-relay-deploy`，把正式 `.env` 移到
  `/etc/vps-infra/secrets/ai-api-relay/.env`，並確認 mode `0600`。
- [x] 以既有 Compose project name `ai-api-relay` 在新路徑啟動，確認原有
  named volumes 被重用，只有兩個 app 接上 `vps-infra_ingress`。
- [x] 驗證所有 app／資料服務健康、private backend 網路與 host ports；
  確認共用 ingress network 由 infra 建立及管理。
- [x] 清除舊 checkout 的部署 `.env`，確認原路徑沒有執行中的 Relay
  containers；保留舊 repo 工作樹供參考。回退需先還原升級前備份及使用舊 tag。
- [x] 更新部署完成證據與未解決的公開 Cloudflare／DNS 檢查。

## 後續工作

- [x] 2026-10-02 08:24 UTC：將 New API 正式入口與持久化的
  `ServerAddress`、`passkey.origins` 改為 `newapi.byte612.com`；確認 Passkey
  登入停用且無已註冊 Passkey，重啟 `new-api` 後四個 Relay 容器 healthy，
  `/api/status` 回報新網址。公開與 origin HTTPS 各回 `200`；DNS／TLS／
  Nginx 驗證詳見 infra repo，app 設定與未涵蓋範圍見
  [`docs/current-state.md`](docs/current-state.md)。
- [ ] 為 New API 正式版規劃相容性與資料庫 migration 測試。現行部署維持
  `v1.0.0-rc.40`；舊正式 tag 不可未經備份及相容性審查直接降版。
- [ ] 在乾淨環境完成備份還原演練，記錄操作時間、結果與 RPO／RTO。
- [ ] 公開推送前檢查此次差異及 secret scan 結果；不提交機密或正式資料。
