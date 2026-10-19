# 重寫計畫

> 這份文檔是**單一事實來源（single source of truth）**。計畫有變就地改寫，並在文末變更記錄留一筆。
> 最後更新：2026-10-18
> 需求：[`requirements.md`](requirements.md)；平台事實：[`platform-taptap.md`](platform-taptap.md)
> 上游基線：`8c1b1a3`（2026-10-18T19:04+08:00，v1.13-20261018-004416）

## 0. 一句話

把原版（單檔 IIFE＋全量 innerHTML 重繪＋手寫打包）重寫成**引擎／內容／外殼三層分離**的專案：引擎可 headless 驗證、內容可獨立熱更新、外殼極薄且多渠道共用同一份產物。

## 1. 現況快照

### 1.1 規模與耦合

| 項目 | 數字 | 來源 |
|---|---|---|
| `js/game.js` | 6,984 行／542 函式；`const Game = (() => {…})()` | 上游 v1.13 |
| 共享可變狀態 | `S.` 出現 **1,849** 次（模組級單例狀態） | 上游 v1.13 |
| 匯出面 | `Game` 匯出 **356** 成員；`ui.js` 只用到 254，**106 個沒人用** | 靜態分析 |
| `js/ui.js` | 5,212 行／189 函式；`innerHTML` 51 次、`addEventListener` 47 次 | 上游 v1.13 |
| 計時器 | `setTimeout` 30、`setInterval` 3、`requestAnimationFrame` 8 | 上游 v1.13 |
| 最大單一函式 | `bindModal` **593 行**（UI）；`showModal` 167、`buildShareCard` 149 | 上游 v1.13 |
| DOM 滲入核心 | `game.js`：`document` 2 處、`window` 8 處、`localStorage` 65 處（集中約 19 個函式） | 上游 v1.13 |

**診斷**：架構債的本質不是「函式太多」（`game.js` 函式中位數只有 6 行），而是 **(a) 全模組共享可變狀態、(b) 萬用 API 表面、(c) 全量重建式渲染**。

### 1.2 閃爍根因（R-A2 的病根）

```
Game.bind({ onChange: () => render(), ... })      // ui.js：任何狀態變更 → 全量重繪
function render()  { ... renderInner() ... }      // ui.js:443
function renderInner() {                          // ui.js:491
  renderTut(); renderTopbar(); renderObjective(); renderMap()/renderScene(); renderExtras(); ...
  // 每個子渲染內部直接 container.innerHTML = `...`
  // 例：`#status-badges`.innerHTML=...（:635）；家具層 wrap.innerHTML=''（:904）後逐個 new Image（:916）
}
```

每次互動 → 狀態變更 → 面板子樹被銷毀重建 → 圖片重新解碼重繪、CSS 動畫重新開始、`position:sticky` 合成層失去子樹（iPad Safari 漏重繪）、滾動位置與焦點丟失。

**作者已打四輪補丁（症狀級）**：

| 出處 | 症狀 | 當時補法 |
|---|---|---|
| `文档/玩家反馈_v1.30_改动记录.md:38` | `#fight-targets` 每回合重建子樹 → iOS 上整段不重繪 | 逐案處理 |
| `文档/维护现状.md:826` | 室內刷新反覆重建底圖與家具 → 閃屏 | 同房間保留原圖 |
| `文档/维护现状.md:252` | 雨雪動 `background-position` → 整層重繪 | 加 `contain: paint`＋`will-change` |
| `文档/维护现状.md:208` | 場景圖透明淡入 → 閃 | 取消淡入動畫 |

結論：**這是渲染模型問題，不是個別 bug**；重寫版的渲染層必須以「節點身分穩定＋細粒度更新」為第一原則。

### 1.3 存檔機制

| 面 | 現況 | 重寫含義 |
|---|---|---|
| 本局存檔 | localStorage 主檔＋滾動備份＋cookie 鏡像＋`_rev`＋損壞留底 | 機制保留，格式重設計 |
| 存檔碼 | `codeChecksum`:5879（FNV-1a，無密鑰）、`readSaveCode`:5884、`inspectCode`:5896、`exportCode`:5901、`importCode`:5911 | 需向後兼容匯入（R-E2） |
| 已知缺陷 | 校驗非防竄改（作者自述「防損壞，非防作弊」）；`readSaveCode` **不檢查 `t`（build 版本）**；`preserveMetaGrowth`:5790 會把魂點夾擠回本機舊值（玩家誤以為還原失敗） | 重寫版改為 JSON＋schemaVersion＋migrations＋checksum，並保留「存檔碼」為無帳號路徑 |
| 上限 | 5992 行：`soul ≤ 1,000,000`、`adCoins ≤ 100,000`（匯入驗證） | 遷移時明確定義 |
| 雲存檔 | TapTap 小遊戲雲存檔 v4：`window.tap` 注入、單檔 10 MB、100 檔/100 MB、**1 分鐘 1 次**；僅小遊戲容器可用 | R-E1 需自有方案覆蓋 APK／桌面／網頁 |

### 1.4 打包與發佈現況

| 面 | 現況 |
|---|---|
| Android 包 | `安卓包装/build.py` 手寫（aapt2/javac/D8/zipalign/apksigner，不用 Gradle）；WebView 載 `https://appassets.androidplatform.net/assets/index.html`；唯一原生橋 `onJsPrompt` 攔 `guyu-backup:export\|import`；包名 `top.guyuyizhang.game`；minSdk 26／targetSdk 36 |
| APK | 249.72 MiB（v1.13，2026-10-18 打包校驗通過）；**未上架**；未真機驗收（本輪） |
| TapTap | 以**小遊戲（H5）**形態營運；雲存檔、廣告走 `window.tap`；作者文件記載 app_id 921745 |
| 桌面 | 目前由 **TapTap 用戶端啟動**（使用者陳述）；作者文件中的桌面版尚屬規劃（Electron→Steam） |
| 更新路徑 | 重新打包 APK／重新上傳 TapTap；**無自發佈熱更新**（TapTap PC 有官方的自更新協調機制，上游未使用；見 `platform-taptap.md` §4） |
| 素材 | 全量進包（264 MB 素材的大部分）；無按需下載 |

### 1.5 流程缺口

- 無 CI、無 `package.json`、無 lockfile。
- 39 組回歸測試只能由作者在 Windows PowerShell 手跑（`回归测试/run.js`；`--browser` 探針需 Chromium）。
- 無架構閘門、無型別檢查（純 JS）、無依賴圖。

### 1.6 原版做對的地方（重寫要保住）

1. `data.js` 是真資料層（可直接成為第一個內容包）。
2. 核心近乎 headless（已實測 bun 無瀏覽器跑 `exportCode`／`importCode`）。
3. 存檔多層防護（主檔＋滾動備份＋cookie 兜底＋損壞留底）。
4. 39 組回測覆蓋面廣（含大量邊界）。
5. 執行期零外部相依。
6. 測試用假 DOM harness（`开发工具/检查/_verify_save_safe.js`）可直接重用來跑 golden。

## 2. 目標架構

### 2.1 三層

```
┌─ 內容包（可獨立更新、簽章、版本化）────────────────┐
│  content-art  content-audio  content-voice        │
│  content-story  content-data  content-ui          │
│  每個包：manifest（id、version、schema、依賴、雜湊、簽章）│
└──────────────┬───────────────────────────────────┘
               │ 只以 id＋schema 引用
┌─ 客戶端 ──────▼───────────────────────────────────┐
│  引擎（純 TS，無 DOM）：模擬、存檔、時間、數值      │
│  顯示層：細粒度響應式 UI ＋ 獨立場景層             │
│  存檔服務：本地多層＋雲同步客戶端                   │
└──────────────┬───────────────────────────────────┘
               │ manifest／同步 API
┌─ 服務端 ──────▼───────────────────────────────────┐
│  內容分發（manifest＋檔案 CDN）                    │
│  雲同步（存檔 CAS）／帳號／遠端設定                 │
└───────────────────────────────────────────────────┘
```

外殼（Web／Android／桌面）只做四件事：**載入器、公鑰驗章、內容快取、原子切換與回滾**；內容快取置於**包體之外**的使用者資料目錄，包體內檔案運行期唯讀（TapTap 包體規則，見 `platform-taptap.md` §4.3）。

### 2.2 目錄骨架（提案）

```
guyu/                        （重寫版新程式庫；bun workspaces＋Nx 任務層）
├─ apps/
│  ├─ game/                  Vite＋Solid 客戶端（引擎＋UI＋場景層）
│  ├─ shell-android/         薄殼（WebView＋驗章＋快取）
│  └─ server/                內容分發＋雲同步（後端選型待決）
├─ packages/
│  ├─ engine/                模擬核心（純 TS、無 DOM，可 headless）
│  ├─ schema/                內容 schema（單一來源）
│  ├─ ui/                    面板元件（Solid）
│  └─ content/               內容包（art/audio/voice/story/data/ui）
├─ tools/
│  ├─ pack/                  內容打包＋簽章
│  ├─ trace/                 上游 golden 產生器（跑 upstream 取基準）
│  └─ verify/                驗證與閘門
└─ docs/                     決策與規格
```

- 桌面**不自建外殼**：PC 通路由 TapTap 用戶端承載（同一份 Web 產物；見 D-14）。
- 工具鏈已實測可跑（見 §4 M0 註）。

### 2.3 關鍵資料流

- **熱更新**：manifest（簽章）→ 比對本地 → 下載差異 → 驗雜湊 → 原子切換 → 失敗回滾。
- **雲同步**：本地先寫 → 佇列上傳（`if-revision == N`）→ 409 即分叉 → 兩份保留由玩家選。
- **存檔**：JSON＋`schemaVersion`＋migrations＋checksum；舊存檔碼經「匯入器」轉換。

## 3. 關鍵決策

| 編號 | 決策 | 狀態 | 說明 |
|---|---|---|---|
| D-1 | 重寫，新程式庫；上游保留為 oracle（保真度基準） | 已確認 | 不 merge 上游程式碼；移植資料與行為 |
| D-2 | 渲染＝細粒度響應式＋節點身分穩定；禁止對容器做 `innerHTML=`（以 lint 規則擋）；UI 與場景層分離 | 已定 | 解 R-A2。渲染階梯：**場景本體＝DOM/CSS**、**效果層＝原生 Canvas 2D**（零依賴）、互動畫布備位＝Konva v10.9、影片＝原生 `<video>`；Pixi／Fabric／Paper 出局；效能紅利＝**重構本身**（全量重建 → 細粒度更新：DOM 操作量、解析與 GC 成本大降，體感＝順、不閃、秒開） |
| D-3 | 內容包＋schema 驗證；引擎只認 id | 已確認（方向） | 粒度與打包策略見 M1 |
| D-4 | 熱更新：manifest＋Ed25519 簽章＋雜湊＋原子切換＋回滾；引擎與內容皆可熱更；外殼極薄 | 已確認（方向） | 與 TapTap `.taptap/meta.json` 機制協調（R-B2）；**熱更產物與存檔放包體目錄之外**（平台依清單刪除／覆寫；包體檔案須唯讀，見 `platform-taptap.md` §4.3）；離線可玩（已下載內容），熱更檢查與下載需網路 |
| D-5 | 雲同步：revision CAS、離線優先、**不自動合併**、衝突保留兩份 | 已確認（方向） | 後端選型受 Q-2 影響 |
| D-6 | 開發迴路：單一 dev server（Vite HMR）＋確定性驅動介面（固定種子、腳本化輸入）＋agent 觀測介面（`window.__game`） | 已確認 | 同時是 golden 測試基礎 |
| D-7 | 客戶端框架：**Solid 2.0**（TSX；細粒度、無 VDOM；Rust/Oxc 編譯器） | 已定（2026-10-18 由 Svelte 5 改判） | 取捨與改判見下；備案 Svelte 5 |
| D-8 | 服務端：gstack 全套（Workers＋D1＋R2＋KV＋better-auth＋oRPC＋Drizzle）；**全鏈統一 TypeScript（後端亦 TS）**；形狀＝**三個小服務**（帳號／存檔同步／發佈分發），**無遊戲伺服器** | 待決（僅剩 Q-2 落腳） | 同步核心＝一列存檔（revision CAS、衝突保留兩份）＋檔案櫃；若換大陸雲，只換 provider、不動協議；runtime（Bun／Node）降級為小事（請求／回應＋檔案分發），自架時再拍 |
| D-9 | 引擎語言：TypeScript，無 DOM | 已確認 | 可 headless 驗證 |
| D-10 | 存檔格式：JSON＋schemaVersion＋migrations＋checksum；附上游存檔碼匯入器 | 已確認 | R-E2 |
| D-11 | 測試：**Vitest 5 為唯一 runner**；golden trace 沿用自製 harness（假 DOM）＋裸 `fast-check`；不引入第二套 runner | 已定（2026-10-18 修訂） | spike 已實測（core 單元＋client jsdom 元件測試） |
| D-12 | 素材沿用上游（不重製）；以 manifest 對應 id→檔案 | 已確認 | 尊重作者產出，降低工作量；「結構重新蓋、整體遷移」見 §5 |
| D-13 | 工具鏈：bun（套件管理器）＋Bun workspaces；**Nx 23 為唯一任務層**（cache／affected；`vp run` 不另做一層）；Vite 8、Vitest 5、oxlint／oxfmt（淘汰 Biome）、Tailwind v4（CSS 變數主題）、pure-rand；dependency-cruiser 守模組邊界 | 已定 | 2026-10-18 比較後拍板；實測可跑 |
| D-14 | 通路：桌面走 TapTap 用戶端（不自建桌面殼）；手機獨立 Android 殼（WebView）；網頁直出同一份產物 | 已定（Android 殼技術 M5 再定） | R-B3 大部分收斂；首發通路 M5 定 |
| D-15 | 帳號：**TapTap 登入＋遊客模式**（自建不做；原 Q-3 三選一收斂） | 已定 | 遊客＝裝置匿名身分：可玩、可存檔、雲同步可用（同機）；綁定 TapTap 後跨裝置同步與存檔遷移；PC／Android 用官方 SDK，純網頁先遊客。備忘：非 TapTap 通路（Steam／itch 等）之帳號另議 |
| D-16 | 首包與分發：包體＝殼＋**基底快照**（引擎＋首章可玩最小集）；美術／語音**按需下載**；熱更只補差異 | 已定（目標值 Q-6 待定） | 初次下載盡量走平台 CDN（TapTap），自有伺服器承擔增量與按需；避免首包極端瘦身把首啟壓力全丟自有側（Q-2 未定時尤甚） |

**D-7 取捨與改判**：Svelte 5（runes）與 Solid 2.0（signals）同屬細粒度、無 VDOM，都滿足 R-A2。改判 Solid 2.0 的理由：**全鏈統一 TS 零缺口**——Solid 的 TSX 由 Oxc 系工具鏈完整支援（lint／format／編譯皆無缺口），Svelte 模板不在 Oxc 檢查範圍（language plugins RFC 未出貨）；且 Solid 直接操作真 DOM、命令式互操作最順，對位「節點身分穩定」。代價：生態與樣本較小（**樣本量不列為風險**，使用者拍板）；無內建 transitions（動效另用 Motion／GSAP）；RC 期 runtime／compiler 須鎖同一 rc 線。React 19 未入選（VDOM 更新模型與 R-A2 相性最差）。

**D-8 註記**：gstack 進**服務端**，不進遊戲客戶端。先前「gstack 不進遊戲」的結論修正為：客戶端保持獨立 SPA，後端用 gstack（或等效堆疊）。

## 4. 里程碑

| 編號 | 目標 | 驗收標準 | 狀態 |
|---|---|---|---|
| M0 | 骨架能跑：Vite＋Solid＋TS；細粒度渲染；一個房間可進可互動；dev server 三端可連；agent 可截圖＋點擊＋斷言 | 連續點擊 20 次無可見閃爍；agent 操作腳本可重現 | 進行中（技術棧 spike 已通過，見下註） |
| M1 | 內容包管線：manifest＋schema＋驗證＋打包簽章；換一張圖／一段文本不需改程式 | 替換測試：只重建被改動的包，其他包驗證結果不變 | 未開始 |
| M2 | 存檔與同步：新存檔模型＋舊碼匯入＋雲同步最小閉環（CAS） | 舊存檔碼可匯入且進度一致；兩裝置分歧保留兩份 | 未開始 |
| M3 | 熱更新迴路：遠端 manifest＋下載＋驗章＋原子切換＋回滾；TapTap `.taptap/meta.json` 協調 | 線上換內容不重裝；中斷後可啟動；可回滾 | 未開始 |
| M4 | 第一個垂直切片：採集／時間（含 UI、文本、存檔） | golden trace 與上游一致 | 未開始 |
| M5 | 後續切片＋分發：戰鬥、建造、劇情；Android 薄殼；首包瘦身 | 首包 ≤ 目標值（Q-6）；離線可玩首章 | 未開始 |

**M0 註（2026-10-18 實測）**：bun install（222 套件）→ `nx run-many -t typecheck test build` 五任務全綠、再跑快取 5/5 命中 → `vite build` 產物 index.html 439 B＋JS 32.2 KB＋CSS 8.0 KB → Vitest（core 單元＋client jsdom 元件測試）通過 → oxlint 0 warning、oxfmt 全數一致 → `vite` dev server 501 ms 就緒、模組轉換含 Solid 執行期與 HMR（Node 24.21.0／Vite 8.3.4／Solid 2.0.0-rc.15／bun 1.4.2）。連續點擊 20 次無閃爍與 agent 斷言屬 M0 本體，開工後驗收。

**M1／M3 註（出貨流程）**：發佈＝內容／程式改動 → 打包閘門（schema 驗證＋組包＋Ed25519 簽章）→ 上傳 manifest＋差異包 → 玩家端熱更（檢查→下載→驗簽→原子切換；回滾＝翻 manifest 指針）。要點：只重打包動過的（Nx affected＋內容雜湊）；版本與 release note 由發佈流程產生；簽章金鑰放本機／CI 密鑰、不進 repo（僅公鑰內嵌客戶端）。

## 5. 保真度策略（怎麼不死）

1. **上游是 oracle，不是程式碼來源**：只取資料與行為，不搬實作。
2. **第一步先搬 `data.js`**：它本來就是純資料，是零風險的啟動資產，直接成為 `content-data`。
3. **golden trace**：用上游 harness（`_verify_save_safe.js` 的假 DOM 範本）在 headless 跑固定劇本（固定種子、腳本化輸入），產出快照；重寫版跑同一劇本逐項比對。
4. **垂直切片順序**：存檔／讀檔 → 採集／時間 → 製作／建造 → 戰鬥 → 劇情／結局。
5. **上游持續演進**：定期 `git -C upstream fetch`（工作區腳本 `check-upstream`）；移植以釘住的基線 `8c1b1a3` 為準，之後的改動逐次評估是否納入。
6. **素材＝重新建庫、整體遷移**：「素材庫化」＝美術／音樂／文本從程式剝離、便於獨立更新；做法是「從零蓋一個新地基（新結構）再整體遷移」，不是漸進搬運舊結構。
7. **保真來源不設限**：原版檔案之外，也可以直接詢問作者求證。

## 6. 風險登記

| 編號 | 風險 | 對策 | 狀態 |
|---|---|---|---|
| K-1 | 雲端服務在大陸的可達性（Cloudflare vs 大陸雲） | Q-2 拍板；架構與 provider 解耦 | 待決 |
| K-2 | 內容包切太細 → 載入碎片化、首屏慢 | 定義包粒度與預載策略（M1） | 待決 |
| K-3 | 熱更新＝任意程式碼執行通道 | Ed25519 簽章＋雜湊＋公鑰內嵌＋回滾；內容與引擎分權 | 已定對策 |
| K-4 | 保真度漂移（玩法手感變化） | golden trace＋上游對照 | 已定對策 |
| K-5 | 上游持續改版 | 定期 fetch；逐次評估 | 已定對策 |
| K-6 | 平台合規未知（熱更新邊界、服務端控制內容紅線） | Q-7 查證；設計上避免「審核後由服務端切換內容」（審核規範 5.2）；熱更新為官方支援路線（見 `platform-taptap.md` §4／§6） | 部分查證 |
| K-7 | 範圍蔓延（人力有限） | 里程碑驗收制；每期只交付驗收標準內的東西 | 已定對策 |
| K-8 | 素材權利與平台披露（AI 生成內容、外部素材授權） | 沿用上游素材；發佈前盤點授權與披露要求 | 待查證 |
| K-9 | 249 MB 包體的下載體驗 | R-B4／D-16 首包瘦身；按需下載；初次下載走平台 CDN | 已定對策（數字 Q-6） |

## 7. 與上游的關係

- 上游持續營運中；重寫版是**新程式庫**，不 fork 上游程式碼、不修改上游檔案。
- 重寫期間不改上游、不代發公告、不動作者任何線上服務。
- 重寫版完成前，上游仍是唯一正式版本。
- **上游倉庫現況（2026-10-18 GitHub 直讀核實）**：公開庫 `xbxfk-twh/guyuyizhang`，2026-09-18 建立、32 commits；HEAD `8c1b1a3` 即我方釘住的基線（核實時無新 commit）；分支 `main` 與 `codex/progression-review-20261018`；無 tag、無 release。目錄：`孤屿遗章-游戏 - 发布`（遊戲本體）、`开发工具`、`文档`、`回归测试`、`安卓包装` 等。
- **授權狀態（重要）**：倉庫無 LICENSE；README 明示「许可证尚未确定；代码与美术资源版权归作者所有；未经作者许可，请勿商用或二次分发」→ 沿用素材前須取得作者同意（K-8）。
- **作者協作公約**：存檔兼容是底線；版本字串只在 `index.html`（`_bump_version.js` 同步五處）；不主動打包發布；私有目錄不入版本控制；作者以 Codex 協作（分支 `codex/progression-review-*`）。

## 8. 需求對照（每條需求怎麼處理）

需求原文、動機與驗收標準見 `requirements.md`；本表回答「每一條需求由哪個機制、哪個決策、哪個里程碑承接」。`待決` 表示要拍板才能定案。

| 需求 | 怎麼處理 | 決策 | 里程碑 | 現況 |
|---|---|---|---|---|
| R-A1 重寫 | 新程式庫（引擎／內容／外殼三層）；上游唯讀當 oracle，不 merge 程式碼 | D-1 | M0 起 | 待開工 |
| R-A2 閃爍 | 細粒度響應式渲染＋節點身分穩定；禁對容器 `innerHTML=`（lint 擋）；UI 與場景層分離 | D-2、D-6 | M0：連點 20 次無可見閃爍 | 待開工 |
| R-A3 內容解耦 | 內容包（ui／voice／art／audio／story／data）；引擎只認 id＋schema；「畫面」＝場景定義以資料描述（歸屬與粒度於 M1 定） | D-3、D-12 | M1 | 待開工 |
| R-A4 核心無 DOM | `packages/engine` 純 TS；Bun／Node 可跑完整局與存檔 | D-9 | M0／M4 | 待開工 |
| R-A5 離線 | 本地內容快取＋原子切換；離線可玩已下載內容；雲端不可用時雲功能靜默降級；**更新（熱更檢查／下載）需網路，遊玩不需** | D-4、D-5 | M2／M3 | 待開工 |
| R-B1 自發佈熱更 | manifest＋簽章＋雜湊＋原子切換＋回滾；分發自建，不經平台審核（首次上架與殼改動仍走審核；紅線＝送審所見即上線所見，見 `platform-taptap.md` §6） | D-4 | M3：推包即更新 | 待開工 |
| R-B2 桌面 TapTap 啟動 | `.taptap/meta.json` 協調；熱更開始時寫目標版本，平台不反覆彈更新 | D-4 註記 | M3 | 機制已核實；Q-1 待答 |
| R-B3 多渠道同源 | 外殼極薄、各通路同一建置產物；平台差異走啟動參數／外殼；桌面＝TapTap 用戶端承載、不自建桌面殼 | D-14 | M5 | 待決：首發通路 |
| R-B4 包體瘦身 | 首包＝殼＋基底快照（引擎＋首章）；美術／語音按需下載；初次下載走平台 CDN | D-16 | M5 | 策略已定；目標值（Q-6）待定 |
| R-B5 熱更安全 | 客戶端內嵌公鑰；竄改拒收、中斷可啟動、可回滾 | D-4、K-3 | M3 | 待開工 |
| R-C1 劇情文本包 | `content-story`：穩定行 id、場景／文本分離、行可掛語音 id | D-3 | M1／M4 | 待開工 |
| R-C2 語音按需 | `content-voice` 不進首包；缺檔以文字續行、不阻塞 | D-3 | M1／M5 | 待開工 |
| R-C3 美術／音樂替換 | `content-art`／`content-audio`；manifest 以 id 對應檔案 | D-12 | M1 | 待開工 |
| R-C4 schema 驗證 | `packages/schema` 單一來源；出包閘門 `tools/pack`＋`tools/verify`；破壞性變更升版附遷移 | D-3 | M1：替換測試 | 待開工 |
| R-D1 看畫面 | 單一 dev server（Vite HMR）；agent 開頁截圖 | D-6 | M0 | 待開工 |
| R-D2 互動 | 確定性驅動介面＋`window.__game` 觀測；腳本化輸入可斷言 | D-6 | M0 | 待開工 |
| R-D3 三端共用 | 同一 dev server 服務瀏覽器／Android（模擬器與真機）／桌面外殼 | D-6 | M0 | 待開工 |
| R-D4 可重現 | 固定種子＋腳本化輸入；golden 快照比對 | D-6、D-11 | M0／M4 | 待開工 |
| R-E1 雲地同步 | revision CAS、離線優先、不自動合併、衝突保留兩份 | D-5 | M2 | 待開工；後端 D-8／Q-2 |
| R-E2 舊存檔匯入 | JSON＋schemaVersion＋migrations＋checksum；上游存檔碼匯入器 | D-10 | M2：匯入後進度一致 | 待開工（存檔碼已可本地重現） |
| R-E3 合規 | 大陸發行／防沉迷／隱私待釐清；平台紅線（審核 5.2）已定位 | —（K-6、Q-7） | 發佈前 | 待釐清 |
| R-E4 帳號體系 | **TapTap 登入＋遊客模式**（自建不做） | D-15 | M2 前 | 已定（2026-10-18） |

## 9. 變更記錄

| 日期 | 變更 |
|---|---|
| 2026-10-18 | 建立：併入先前分析（規模、閃爍根因、存檔、打包、流程），確立三層架構與 D-1..D-12、M0..M5、K-1..K-9 |
| 2026-10-18 | TapTap 直讀核實（PC 更新機制、包體更新規則、審核 5.2）：D-4 補「熱更產物與存檔置於包體外」；K-6 部分查證；外殼快取位置註記 |
| 2026-10-18 | 新增 §8 需求對照（R-A1..R-E4 → 處理／決策／里程碑）；變更記錄順移為 §9 |
| 2026-10-18 | 畫面層拍板（D-2）：場景＝DOM/CSS、效果＝原生 Canvas 2D、互動畫布備位 Konva v10.9；Pixi／Fabric／Paper 出局；§2.2 骨架同步（去桌面殼、補工具鏈） |
| 2026-10-18 | 框架改判 Solid 2.0 RC（D-7）；工具鏈定案 D-13（bun＋Bun workspaces／Nx／Vite 8／Vitest 5／oxlint＋oxfmt／Tailwind v4）；D-8 補「全鏈統一 TS」；D-11 修訂；通路定案 D-14；M0 狀態與註記更新 |
| 2026-10-18 | 技術棧實測全綠（數字見 §4 M0 註）；上游倉庫直讀核實（§7）；§5 補素材策略與保真來源（第 6、7 條） |
| 2026-10-18 | 後端形狀定案（D-8 補述：三個小服務／無遊戲伺服器／一列存檔 revision CAS）；帳號 D-15（TapTap＋遊客）；首包 D-16（殼＋基底快照、按需、平台 CDN）；D-2／D-4 註（效能紅利、離線界線）；R-A5／R-B1／R-B4／R-E4／K-9 同步 |
| 2026-10-19 | 出貨流程註記（M1／M3 註）：打包閘門（驗證＋組包＋簽章）→ 上傳 manifest／差異包 → 熱更迴路；可回滾、金鑰不入 repo |
