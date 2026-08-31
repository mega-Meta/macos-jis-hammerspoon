# ⌨️ macOS JIS 鍵盤極速流,正體中文使用者優化：
## Hammerspoon 輸入法智慧切換 & Shottr 頂級截圖與生產力配置

本專案專為 **macOS + JIS（日系硬體佈局）鍵盤** 的重度使用者量身打造。透過 Hammerspoon 的底層事件監聽、內建 `hs.chooser` 模糊搜尋引擎與 Shottr 截圖軟體的深度整合，打造出大拇指不離核心區的「單手極速操作流」。

## 🚀 核心特色

1. **徹底解決 Safari 字根散落 Bug**：採用「虛擬實體按鍵（Control + Space）」走標準 IME 廣播，在 Safari 或各類網頁表單中輸入中文字根絕對不打散。
2. **App 智慧白名單與自動切英文**：切換視窗時自動還原為「英文 ABC」，但進入備忘錄（Notes）、LINE、Moped 等特定 App 時自動保持原有輸入法。Ghostty、VimR、Terminal 等開發工具維持切換英文邏輯。採用 `Bundle ID` 雙重比對，跨語系判定 100% 精準。
3. **終結系統級防護鎖死**：針對 macOS 在 Safari 列印、儲存檔案（Save Dialog）以及螢幕截圖時會強制啟動 `Secure Input` 的限制，內建「自動延遲洗牌重置」與「3秒背景喚醒守護」，監聽器永遠不死機，**告別手動 Reload Config**。
4. **Shottr 大拇指流截圖**：將複雜的 `Cmd + Shift + 1/2/3/4/5/7/8` 繁瑣組合鍵，全部精簡至大拇指相鄰的 `Cmd`、`Option`、`かな`、`英數` 鍵，單手盲操極致流暢。
5. **Spotlight 等級剪貼簿與常用字面板**：利用 Hammerspoon 內建最穩定的 `hs.chooser` 搜尋引擎。雙擊「英數」鍵即可在螢幕中央喚出融合「固定常用字（Email、統編、地址）」與「最新10筆動態剪貼簿歷史」的搜尋面板，支援全鍵盤操作與快速模糊搜尋。

---

## 🎮 快捷鍵與操作手勢指南

### 1. ⌨️ 輸入法與常用字控制（雙擊流核心）

| 動作 | 觸發按鍵 | 實際效果說明 |
| :--- | :--- | :--- |
| **智慧切倉頡** | 單擊 **`かな`** 鍵 | 0.45 秒內未按第二下，**直接精準切到倉頡**（支援 Safari 安全防護）。可修改init.lua第20，21行預設成注音 |
| **切換其他輸入法** | 雙擊 **`かな`** 鍵 | 連點兩下，觸發系統標準循環，切換到下一個輸入法（如注音、日文）。 |
| **精準切英文** | 單擊 **`英數`** 鍵 | 0.40 秒內未按第二下，瞬間一鍵返回純英文（ABC）輸入來源。 |
| **喚出常用字與剪貼簿** | 雙擊 **`英數`** 鍵 | **全新高效功能**：瞬間在螢幕中央彈出 Spotlight 風格面板。上半部為固定常用字，下半部為剪貼簿歷史。支援滑鼠點擊或鍵盤上下鍵選取，按下 `Enter` 即可**自動模糊搜尋並極速貼上**。 |
| **經典習慣切換** | **`Cmd + Left Shift`** | 保留傳統習慣，按下會切換到下一個輸入法來源。 |

### 2. 📸 Shottr 大拇指流極速截圖

左手大拇指完全不需跨越鍵盤，單手盲操即可發動 Shottr 的所有進階功能。

| 截圖功能 | 觸發按鍵組合 | 實戰操作技巧 |
| :--- | :--- | :--- |
| **區域範圍截圖** | **`Cmd + かな`** | 按下後滑鼠變成十字游標，拖曳你想截取的範圍。 |
| **全螢幕截圖** | **`Cmd + 英數`** | 瞬間卡嚓，直接擷取整個螢幕畫面並自動存入剪貼簿。 |
| **當前視窗截圖** | **`Option + 英數`** | 游標移到哪個視窗，就完美單獨截取該視窗（自帶精美陰影）。 |
| **自動滾動長截圖** | **`Option + かな`** | **精妙操作**：按鍵後**按住左鍵框選要捲動的視窗區域並放開**，雙手離開滑鼠，Shottr 會自動往下滾動拼接長圖。 |
| **重複上次範圍** | **`Cmd + ¥`** | 右手小指一鍵自動重複上一次的截圖範圍。 |
| **錄影與工具列** | 雙擊 **`Cmd`** 鍵 | 連續快速按兩下 `Cmd` 鍵，底部立刻彈出 macOS 原生錄影控制列。 |
| **秒級歷史視窗** | 雙擊 **`Option`** 鍵 | 連按兩下 `Option` 鍵，立刻彈出 Shottr 歷史主視窗，秒級預覽與編輯剪貼簿中的最新截圖。 |

---

## 🛠️ 一鍵安裝自動化腳本 install.sh
### 下載及執行 install.sh (開啟Terminal,複製貼上以下命令)
   ```bash
   /bin/bash -c "$(curl -fsSL https://github.com/mega-Meta/macos-jis-hammerspoon/raw/refs/heads/main/install.sh)"
   ```
### 腳本會自動完成所有繁瑣的步驟：檢查並安裝 Homebrew 軟體管理工具、自動安裝 Hammerspoon 與 Shottr、自動建立設定目錄、從您的 GitHub 倉庫下載最新代碼、並引導使用者開啟 macOS 系統權限。

---

## 🛠️ 部署與安裝指南

### 第一步：安裝必備軟體

1. **Hammerspoon**：
   ```bash
   brew install --cask hammerspoon
   ```
2. **Shottr**：
   前往官網 [https://shottr.cc](https://shottr.cc) 下載安裝，或使用 Homebrew：
   ```bash
   brew install --cask shottr
   ```

### 第二步：配置 `init.lua`

1. 打開或建立主機上的配置路徑：`~/.hammerspoon/`
2. 將本 Repository 中的 `init.lua` 檔案複製到該目錄下。
3. 修改單擊kana鍵預設輸入法，點擊 Mac 選單列的 Hammerspoon 圖示，點擊[open config]
   倉頡輸入法使用者，修改單擊kana鍵預設如下:
   local 1CLICK_IME_ID = "com.apple.inputmethod.TCIM.Cangjie" --#倉頡
   --local 1CLICK_IME_ID = "com.apple.inputmethod.TCIM.Zhuyin" --#繁體倚天注音
   注音輸入法使用者，修改單擊kana鍵預設如下:
   --local 1CLICK_IME_ID = "com.apple.inputmethod.TCIM.Cangjie" --#倉頡
   local 1CLICK_IME_ID = "com.apple.inputmethod.TCIM.Zhuyin" --#繁體倚天注音
4. 點擊 Mac 選單列的 Hammerspoon 圖示 $\rightarrow$ **Reload Config**。

### 第三步：必須調整的 macOS 系統設定（關鍵）

為了防止權限與底層 Bug 卡死，請務必微調以下三項設定：

1. **確認輸入法快捷鍵**：進入「系統設定」 $\rightarrow$ 「鍵盤」 $\rightarrow$ 「鍵盤快捷鍵...」 $\rightarrow$ 「輸入來源」，確認 **「選取下一個輸入來源」** 有勾選且為 **`Control + Space` (^空間)**。
2. **根治存檔框卡死 Bug**：進入「系統設定」 $\rightarrow$ 「鍵盤」 $\rightarrow$ 「輸入來源 (編輯...)」，**關閉（不要勾選）「自動切換到文件的輸入來源」**。*(這能徹底解決 Safari 列印 PDF 存檔時輸入法卡死的系統 Bug)*
3. **核准系統權限**：在「系統設定」 $\rightarrow$ 「隱私權與安全性」 $\rightarrow$ 「輔助功能」與「螢幕錄製」中，核准 **Hammerspoon** 與 **Shottr** 的權限。

### 第四步：調整 Shottr 快捷鍵

打開 Shottr 的 Preferences $\rightarrow$ Shortcuts，將功能對應修改為：
* `⌘⇧3` $\rightarrow$ Fullscreen screenshot
* `⌘⇧4` $\rightarrow$ Area screenshot
* `⌘⇧1` $\rightarrow$ Active window screenshot
* `⌘⇧2` $\rightarrow$ Scrolling screenshot
* `⌘⇧7` $\rightarrow$ Repeat area screenshot
* `⌘⇧8` $\rightarrow$ Open App

---

## 🔍 自行擴充自訂文字與白名單

### 1. 修改固定常用字串
打開 `init.lua`，直接編輯最上方的 `FIXED_SNIPPETS` 陣列，即可無限自由延伸你的固定罐頭訊息或常用資料：
```lua
local FIXED_SNIPPETS = {
    { title = "📧 我的電子郵件",  text = "your_email@gmail.com" },
    { title = "🏢 公司統一編號",  text = "12345678" },
}
```

### 2. 擴充 App 白名單
如果你有其他軟體（如微信 WeChat、Discord 等）在切換視窗時**不想被強制換成英文**，可以自行查詢其 `Bundle ID` 並寫入 `init.lua` 中的 `WHITE_LIST_IDS` 清單中（設定為 `true` 代表不強制切英文）。
#### 軟體名稱查詢方法：
1. 開啟 Hammerspoon 主控台（Open Console）。
2. 解開 `init.lua` 第 3 行的註解或直接在 Console 執行偵測：
   ```lua
   testWatcher = hs.application.watcher.new(function(name, event, app) if event == hs.application.watcher.activated and app then print("ID: " .. tostring(app:bundleID())) end end):start()
   ```
3. 用滑鼠點擊目標 App，主控台就會印出其專屬 ID（例如：`com.tencent.xinWeChat`）。

---

## 🎉 安裝完成！請配合進行最後的 macOS 手動權限設定：
### 1. 允許系統輔助功能：
   請前往 「系統設定」 → 「隱私權與安全性」 → 「輔助功能」，
   將 Hammerspoon 與 Shottr 的開關【開啟】（若已開啟，請重啟一次）。

### 2. 允許螢幕錄製：
   請前往 「系統設定」 → 「隱私權與安全性」 → 「螢幕錄製」，將 Shottr 【開啟】。

### 3. 根治系統存檔框卡死 Bug：
   請前往 「系統設定」 → 「鍵盤」 → 「輸入來源（點編輯）」，
   【關閉（不要勾選）】「自動切換到文件的輸入來源」。

### 4. 核對輸入法快捷鍵：
   請前往 「系統設定」 → 「鍵盤」 → 「鍵盤快捷鍵...」 → 「輸入來源」，
   確保 「選取下一個輸入來源」 為 Control + Space (^空間)。

---

## 📄 授權條款
本專案基於 [MIT License](LICENSE) 開源分享。歡迎 Fork、Star 或提出 PR 一起優化 Mac JIS 鍵盤的操作體驗！
