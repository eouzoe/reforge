# 存檔機制

## 存檔模型

- 存檔以 JSON 表示，包含 `schemaVersion`、遊戲狀態與 checksum。
- 每次寫入先產生新版本，再以原子方式取代現有主檔。
- schema 變更以 migrations 處理；舊版本存檔在載入時自動升級。
- 提供可攜存檔碼，供無帳號情境匯出與匯入。

## 本地持久化

- 本地存檔是遊戲進度的主要來源。
- 寫入採暫存檔→校驗→原子替換；不得直接覆寫主檔。
- 保留多份滾動備份與最近一次有效版本。
- 讀取時驗證 checksum；損壞時依序回退備份。
- 無法回復的存檔保留原檔供診斷，不直接刪除。

## 雲端同步

- 同步以本地存檔為真相；離線時照常遊玩，連線後補傳。
- 每次上傳攜帶 `revision`；伺服器以 compare-and-swap 接受或拒絕。
- 版本衝突不自動合併；本地與遠端各保留一份，由玩家選擇。
- 帳號可使用平台登入或遊客身分；遊客資料在綁定後遷移。
- 同步失敗不阻塞遊戲；佇列保留待傳內容。

## 匯入與遷移

- 舊版存檔碼經匯入器轉換為目前格式。
- 匯入前驗證 checksum 與欄位範圍；不合法資料不寫入主檔。
- 破壞性 schema 變更必須提供 migration，並在發佈前驗證。

## 程式碼對應

| 職責 | 位置 |
|---|---|
| 存檔格式與 checksum | `packages/save/src/format.ts` |
| 本地持久化與備份 | `packages/save/src/local-store.ts` |
| 遷移 | `packages/save/src/migrations/` |
| 舊存檔匯入 | `packages/save/src/import.ts` |
| 雲端同步 | `packages/save/src/sync.ts` |
