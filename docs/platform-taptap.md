# TapTap 平台研究

> 用途：為 R-B1（自發佈熱更新）、R-B2（桌面端 TapTap 啟動）、R-E1（雲存檔）提供事實基礎。
> 最後更新：2026-10-18
> 驗證等級：`直讀`＝讀過原文；`摘要`＝搜尋結果內文尚未逐字核對；`待驗`＝轉述或推測。

## 1. 這個專案目前在 TapTap 的形態

來源：上游 `文档/云存档_接入说明.md`、`文档/APK与其他平台发布路径.md`、`安卓包装/README.md`（`直讀`，2026-10-18）

| 項 | 事實 |
|---|---|
| 發行形態 | **TapTap 小遊戲（H5）**；雲存檔、廣告都走 `window.tap` |
| 標識 | app_id `921745`、開發者 id `455373`（見雲存檔後台 URL） |
| 雲存檔 | 已接入 TapTap 小遊戲雲存檔 v4（規則見第 3 節） |
| 桌面端 | **目前由 TapTap 用戶端啟動**（使用者陳述，2026-10-18；具體形態待確認，見 Q-1） |
| Android 包 | `安卓包装/` 獨立發行包（包名 `top.guyuyizhang.game`），**未上架商店**；v1.13 於 2026-10-18 完成打包校驗 |
| 作者規劃 | 2026-10-07 文件：維持 H5；Capacitor→APK；itch.io；Electron→Windows→Steam。（注意：該文件的「尚未製作 APK」已被後續 `安卓包装/` 進度超越） |

## 2. TapTap 的發行通路（目前理解）

- **小遊戲（H5）**：跑在 TapTap 容器內，有 `window.tap`（雲存檔、廣告、檔案系統 API）。
- **Android**：APK 上架 TapTap 手機用戶端（需審核）。
- **PC（電腦端）**：TapTap 有 PC 商店與桌面用戶端；支援「電腦＋手機同一遊戲頁」或「獨立遊戲頁」。桌面遊戲由 TapTap 用戶端啟動，並可接入啟動校驗（Windows 平台；Unity／C++ SDK）。
- **自更新（熱更新）**：TapTap PC **官方支援**「遊戲透過自身熱更新完成版本升級」的接入方式（見第 4 節）。

## 3. 已接入的 TapTap 小遊戲雲存檔 v4（官方規則）

來源：上游 `文档/云存档_接入说明.md`（作者 2026-09-18 查證 `developer.taptap.cn` 並實作，`直讀`）

| 項 | 規則 |
|---|---|
| 可用範圍 | TapTap 小遊戲（基礎庫 2.0.0+）；Android／iOS／PC 要走 TapTap 登入 SDK |
| 入口 | `tap.getCloudSaveManager()` 全域單例 |
| 方法 | `createArchive`／`updateArchive`／`getArchiveList`／`getArchiveData`／`getArchiveCover`／`deleteArchive` |
| 上限 | 單檔 **10 MB**（封面 512 KB）；單玩家 **100 檔 / 100 MB** |
| 頻次 | `createArchive`／`updateArchive` **每分鐘最多 1 次**（錯誤碼 400001） |
| 名稱 | 60 位元組內、不允許漢字 |
| 前置 | 先用 `tap.getFileSystemManager()` 寫本地檔案，再把路徑交給 API |
| 前提 | **必須有 `window.tap`**（小遊戲容器）；電腦瀏覽器直接開 `index.html` 沒有 |

**重寫含義**：小遊戲容器外的通路（APK／桌面／網頁）拿不到這層；R-E1 需要自有雲同步方案，或「容器內用 TapTap 雲存檔、容器外用自有方案」的雙軌。

## 4. PC 更新機制與自更新協調（關鍵：官方支援）

來源：`https://developer.taptap.cn/docs/pc/update-rules/`、`https://developer.taptap.cn/docs/pc/launcher-update-reporting/`、`https://developer.taptap.cn/docs/pc/hosted-update/`（`直讀`，2026-10-18）

### 4.1 平台更新判定

- TapTap 用戶端的更新提示**以「與線上包比對」為準**（不是比版本號）：玩家本地包 ≠ 開發者中心當前線上包 → 提示／下發更新。
- 下發方式由平台自動選擇（開發者不可選）：自測模式（包體尚未提審）→ **增量更新**（塊級）；正式線上、本地非當前線上包 → **差量更新**（二進位 diff）。

### 4.2 自更新協調（`.taptap/meta.json`）

適用於「透過自身熱更新（自帶啟動器等）完成版本升級」的遊戲。包體必須含 `.taptap/meta.json`，放在開發者中心配置的**啟動項同目錄**（固定路徑）：

```json
{ "version": "v1.3.0", "app_id": 12345 }
```

- TapTap 上傳包體時自動提取版本號；並校驗 `app_id` 防止傳錯遊戲。
- 比對：`meta.version` **≥** 線上包版本 → 不提示更新；**<** → 提示更新；**缺失或未隨熱更更新** → 反覆提示（必須修）。
- 熱更新**開始時**就把 `version` 寫成**目標版本**（不必等完成）；失敗不需要回寫。
- 開發者中心若有多餘的高版本包體，需清理，避免比對誤判。
- 版本號格式 `vX.X.X`：三段非負整數、小寫 `v`、逐段比較；建議由 CI 自動生成。

### 4.3 包體更新規則（檔案／目錄清單）

TapTap 以上傳包體的**檔案／目錄清單**做新舊比對（不掃描玩家本地即時狀態）：

| 舊→新 | 行為 |
|---|---|
| 檔案舊無 → 新有 | 下載新檔 |
| 檔案舊有 → 新無 | **刪除**（不檢查本地內容） |
| 檔案內容相同 | 忽略 |
| 檔案內容不同 | **只下差異塊**（前提：舊檔未被運行期改寫） |
| 目錄舊有 → 新無 | **遞迴刪除整個目錄**（含運行期寫入的日誌、快取、**使用者資料**） |
| 目錄保留 | 目錄不動；內部按檔案規則 |

**官方最佳實踐**：存檔、設定放**包體之外的專用目錄**（如 `Saves/`、`UserSettings/`，打包時排除）；包體內檔案運行期**唯讀**、禁止動態改寫；路徑與檔名跨版本穩定；目錄結構不帶版本號；刪除不再使用的資源以縮小補丁。

**重寫含義**：

- **熱更產物與存檔必須放包體目錄之外**（自有內容目錄＋存檔目錄）。寫進包體目錄有兩個後果：破壞唯讀／差量前提；目錄調整時被平台遞迴刪除，連玩家資料一起清掉。
- `.taptap/meta.json` 是「TapTap 啟動＋自發佈熱更」並存的官方協調途徑（R-B2）：自更新維護 meta 版本，平台不會反覆彈更新。
- 平台更新只動包體（外殼＋基底），熱更內容在包體外，兩條更新路徑互不干擾。

相關頁面（待直讀）：遊戲分發系統 `/docs/pc/download-feature/`、更新常見問題 `/docs/pc/update-faq/`。

## 5. PC 上架流程（要點）

來源：`https://developer.taptap.cn/docs/pc-store/guide/document-guide/`（`摘要`，2026-10-18）

- 兩種上架方式：與手機端**同一遊戲頁**（共享資料、評分、論壇）或**獨立遊戲頁**。
- 上架前可設「預約／敬請期待」（敬請期待＝心願單，可打通 Steam 願望單）。
- 測試功能分級：內部測試（不開放用戶）等。
- PC 遊戲需接入**啟動校驗**（Windows；Unity SDK／C++ SDK）。雲存檔文件亦載明「Windows 平台使用前還需接入啟動校驗」。

## 6. 商店審核規範（要點）

來源：`https://developer.taptap.cn/docs/store/release/store-agree/`（同文另有 `/docs/store/release/publish/agree/`）（`摘要`，2026-10-18；全文待直讀）

- **5.2（欺诈行为）**：「游戏在审核前后通过服务端控制应用内容，在上架后开启违规服务将被下架，严重者会被封禁账号。」
- **重寫含義**：**熱更新本身不違規**（PC 自更新是官方支援路線，見第 4 節）；紅線是「審核時隱藏、上架後用服務端開啟違規內容」。自發佈熱更必須全程合規：送審所見與上線所見不得出現此類分歧。
- 同頁相關（摘要可見）：1.2 遊戲內付費須明碼標價、禁止誘導付費；1.3 廣告與捆綁下載限制。
- 待查：「純淨包」相關要求的原文出處。

## 7. TapSDK（Android／iOS／PC 路線）

來源：`https://developer.taptap.cn/docs/sdk/tap-cloudsave/guide/`（`摘要`，2026-10-18）

- TapTap 雲存檔模組依賴 **TapTap 登入**模組；需在開發者中心創建應用並開啟雲存檔服務。
- Unity 依賴（NPMJS 方式）：`com.taptap.sdk.core` / `login` / `cloudsave`（範例版本 4.10.9）；亦提供 GitHub 與本機 unitypackage 方式。
- 需要網路權限與網路狀態權限。

## 8. 開發者 CLI（`@taptap/cli`）

來源：`https://developer.taptap.cn/v3/cli/`（`摘要`，內容含完整指令；待安裝後實測）

| 項 | 內容 |
|---|---|
| 安裝 | `npm i -g @taptap/cli --registry=https://registry.npmjs.org/` |
| 版本 | `taptap-cli version` |
| 認證 | `taptap-cli auth login` → 開啟 CLI 給出的 TapTap 登入連結完成授權，憑證存本地 |
| 更新 | `taptap-cli update`（`--force` 強制同步 AI 能力說明） |
| 能力 | 遊戲創建、素材上傳、資料發布、運營管理；包體管理、測試計劃、上架資質、圖片素材庫 |
| 常用路徑 | `taptap-cli developer +list`；`taptap-cli app +list --dev-id <developerId> --kw <keyword>`；`taptap-cli --help`；`taptap-cli app --help`；`schema` 核對參數與返回結構 |
| AI 取向 | 官方明言「可以把本頁內容提供給 AI 助手」；高風險操作前 AI 會先說明再等確認 |
| 本專案狀態 | **已安裝實測**（2026-10-18）：`@taptap/cli@2026.10.15`（bun 全域安裝，bin 在 `~/.bun/bin/taptap-cli`）；`doctor`：伺服器可達、metadata 就緒（**81 個操作**）；**不登入**（工作區規則：未經明確允許不得登入） |

### 8.1 內建技能（12 個，隨 CLI 版本內嵌）

`taptap-cli skills list` 顯示：`taptap-cli`（總入口／執行規範）、`taptap-identity`（身分與 scope 發現）、`taptap-publish-game`（新遊戲創建）、`taptap-app-edit`（資料維護／提審／發布／版本歷史）、`taptap-package-management`（包體庫診斷與測試 QR）、`taptap-materials`（本機物料盤點與上傳編排）、`taptap-asset-library`（圖片素材庫／影片／AI 生圖）、`taptap-qualification`（上架資質：版號／備案／隱私／AI／IP）、`taptap-test-plan`（CBT／OBT 測試計劃與激活碼）、`taptap-player-feedback`（玩家評價查詢）、`taptap-community-management`（論壇唯讀查詢）、`taptap-dashboard-stats`（下載／曝光／轉化等指標）。

### 8.2 與本專案直接相關的命令

`upload-apk`、`upload-pc-package`（Windows 包體）、`upload-h5-package`（H5 zip）、`upload-mini-app-package`（Tap 小遊戲包）、`package-management`（包體版本狀態／測試二維碼）、`test-plan`（測試招募與激活碼）、`qualification`（資質缺口分析）、`event`（即時事件）、`task`（長任務續跑）。

## 9. 伺服器對伺服器（S2S）上傳 API

來源：`https://developer.taptap.cn/docs/sdk/common/api/`（`摘要`，2026-10-18）

- 廠商請求 TapTap 域名：`https://cloud.tapapis.cn`；GET／POST；`application/json`。
- 簽名：header 帶 `x-tap-ts`（秒級時間戳）、`x-tap-nonce`（8 位隨機字串）、`x-tap-sign`＝`Base64(HMAC-SHA256(secret, SignParts))`。
- `SignParts` = `{method}\n{url_path_and_query}\n{headers}\n{body}`；headers 取 `x-tap-` 前綴（除 `x-tap-sign`）、小寫、按 ASCII 排序、`key:value`、以 `\n` 連接。
- 例：`/apk/v1/upload-params?file_name=taptap.apk&client_id=tapclientid1234567`（APK 上傳參數取得）。
- **重寫含義**：未來可自動化上傳包體／素材（配合 CLI 或直接 S2S），納入 CI 的發布流程。

## 10. 已辦與待辦

| 項 | 狀態 |
|---|---|
| 上游文件核對（小遊戲形態、雲存檔、包體） | 已完成（2026-10-18） |
| 網路研究第一輪（CLI、PC 上架、自更新、S2S、TapSDK） | 已完成（摘要級） |
| 下載並安裝 `@taptap/cli`，跑 `version`／`--help`／`doctor`／`skills list` | 已完成（2026-10-18）：v2026.10.15；81 操作、12 技能 |
| `auth login` 鏈接式授權 | **已停止**：使用者明令未經允許不得登入；逾時作廢，無殘留憑證 |
| `overview`／`developer +list`／`app +list` | **不做**（需登入；依工作區規則禁止） |
| 登入後的後台操作（包體上傳、提審、發布、測試計劃） | **未經允許不做** |
| 第二輪直讀 | **進行中**：PC 更新機制／自更新上報／包體更新規則已完成（§4，`直讀`）；待辦：遊戲分發系統、更新常見問題、PC 上架全文、啟動校驗 SDK、小遊戲文件 |
| 審核規範回查 | **部分完成**：「服務端控制應用內容」條款＝**5.2**（§6，`摘要`，待全文直讀）；「純淨包」待查 |

## 11. 來源清單

| 來源 | URL | 日期 | 等級 |
|---|---|---|---|
| TapTap CLI 使用文檔 | https://developer.taptap.cn/v3/cli/ | 2026-10-18 | 摘要 |
| TapTap PC 遊戲更新機制 | https://developer.taptap.cn/docs/pc/update-rules/ | 2026-10-18 | 直讀 |
| TapTap PC 包體更新規則 | https://developer.taptap.cn/docs/pc/hosted-update/ | 2026-10-18 | 直讀 |
| 遊戲自更新版本上報 | https://developer.taptap.cn/docs/pc/launcher-update-reporting/ | 2026-10-18 | 直讀 |
| TapTap 商店審核規範細則 | https://developer.taptap.cn/docs/store/release/store-agree/（另有 `/docs/store/release/publish/agree/`） | 2026-10-18 | 摘要 |
| PC 遊戲上架指南 | https://developer.taptap.cn/docs/pc-store/guide/document-guide/ | 2026-10-18 | 摘要 |
| TapTap 雲存檔開發指南 | https://developer.taptap.cn/docs/sdk/tap-cloudsave/guide/ | 2026-10-18 | 摘要 |
| 接口公共說明（S2S 簽名） | https://developer.taptap.cn/docs/sdk/common/api/ | 2026-10-18 | 摘要 |

## 12. 變更記錄

| 日期 | 變更 |
|---|---|
| 2026-10-18 | 建立；併入上游文件核對與網路研究第一輪 |
| 2026-10-18 | 第二輪直讀：PC 更新機制／自更新協調／包體更新規則（§4 重寫，`直讀`）；新增商店審核規範（§6）；§6 起章節順移；CLI 授權改記「已停止」（依工作區規則不登入） |
