# 架構

## 系統組成

系統由內容、客戶端與服務端三層組成。

- 內容層：版本化的內容包，包含劇情、畫面、美術、語音、音效與資料。manifest 記錄版本、檔案清單、雜湊與簽章。
- 客戶端：遊戲引擎、顯示層、存檔服務與更新器。引擎以 TypeScript 實作，不依賴 DOM；顯示層以 Solid 2.0 建構 DOM/CSS 場景，效果層使用 Canvas 2D。
- 服務端：帳號、存檔同步與發佈分發三個獨立服務；不提供遊戲伺服器。

平台殼負責載入 Web 產物、驗證簽章、管理內容快取、原子切換與回滾。內容快取與存檔位於包體之外的使用者資料目錄；包體內檔案在執行期唯讀。

## 渲染

- 場景本體以 DOM/CSS 呈現；效果層使用原生 Canvas 2D；影片使用原生 `<video>`。
- UI 採細粒度響應式更新，節點身分保持穩定；禁止對容器以 `innerHTML` 整棵重建。
- 互動畫布在確有需要時使用 Konva；Pixi、Fabric、Paper 不採用。
- 客戶端框架為 Solid 2.0，直接操作真實 DOM。

## 內容

- 內容以 schema 驗證；引擎只透過穩定 ID 引用內容，不直接依賴檔案路徑。
- 內容包與程式分離，可獨立版本化與更新。
- manifest 記錄每個內容包的版本、依賴、檔案清單、雜湊與簽章。

## 引擎

- 引擎以 TypeScript 實作，不依賴 DOM，可在 Bun／Node 中 headless 執行。
- 模擬、數值、時間與存檔邏輯位於引擎；顯示層只讀取引擎狀態並渲染。

## 存檔

存檔格式、本地持久化、遷移與雲端同步見 [`save-system.md`](save-system.md)。

## 更新與發佈

打包、簽章、manifest、原子切換與回滾見 [`build-and-release.md`](build-and-release.md)。

## 目錄

```text
apps/
  game/           Web 客戶端
  shell-android/  Android 殼
  server/         帳號、同步、發佈
packages/
  engine/         無 DOM 引擎
  schema/         內容 schema
  ui/             UI 元件
  save/           存檔與同步
  content/        內容包
tools/
  pack/           打包與簽章
  verify/         驗證閘門
  golden/         golden 測試
docs/
```

## 模組邊界

- `engine` 不依賴 DOM、UI 或內容檔案的具體路徑。
- `ui` 依賴引擎型別與 schema，不直接讀取內容檔案。
- `save` 依賴引擎的存檔型別；同步協定與 UI 分離。
- `content` 只包含資料與素材，不含程式邏輯。
- `tools` 可依賴上述套件，反向依賴禁止。
- 以 dependency-cruiser 檢查邊界。

## 技術棧

- 執行環境：Node 26、bun。
- 套件管理與工作區：bun workspaces。
- 任務層：Nx 23（快取與 affected）。
- 建置：Vite 8。
- 測試：Vitest 5。
- 語言：TypeScript 7。
- UI：Solid 2.0、Tailwind v4（CSS 變數主題）。
- 檢查與格式化：oxlint、oxfmt。
- 屬性測試：fast-check；隨機種子：pure-rand。

## 開發與測試

- 開發以單一 Vite dev server 提供 HMR。
- 引擎以固定種子與腳本化輸入驅動，確保可重現。
- 客戶端提供 `window.__game` 觀測介面，供自動化操作與斷言。
- 測試以 Vitest 5 為唯一 runner；golden harness 使用假 DOM，比對固定劇本的狀態快照。
- 屬性測試使用 fast-check。
