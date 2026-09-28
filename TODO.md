# AI API Relay 待辦事項

此清單僅追蹤 Relay 專案本身。VPS 帳號、主機目錄、共用入口及未來主機架構規劃已移至獨立的 `vps-infra` 工作目錄。

## 維運與可靠性

- [x] 2026-09-28：`sub2api`、`new-api` 加入 infra-owned external network
  `vps-infra_ingress`，保留原 `edge`／`backend`；PostgreSQL、Redis 仍只連
  `backend`。`docker compose --env-file .env.example config --quiet` 通過；
  `yamllint compose.yaml` 因既有全檔格式問題（缺少 `---`、多處超過 80
  字元）未通過。尚未建立主機 network、啟動服務或驗證實際跨 project
  routing；infra owner 須先建立 network。
- [ ] 修正自動 Certbot renewal 成功後未 reload Nginx 的問題，並驗證新憑證已載入。
- [ ] 建立憑證續期失敗及憑證到期告警。
- [ ] 在乾淨環境完成本機備份還原測試。
- [ ] 檢查已固定版本的映像更新，並以設定測試處理 Nginx 棄用／hash table 警告。

## 後續韌性強化

以下超出 PRD 首版範圍，不阻擋目前部署倉庫的首版驗收：

- [ ] 建立加密異地備份並定期測試還原。
- [ ] 在乾淨 VPS 演練完整部署及災難復原流程。

## 發布檢查

- [ ] 每次公開推送前檢查此次差異及 secret scan 結果，不提交機密、正式環境資料或產生檔。
