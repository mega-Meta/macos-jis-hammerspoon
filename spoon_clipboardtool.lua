-- =========================================================================
-- 載入 ClipboardTool
-- =========================================================================
hs.loadSpoon("ClipboardTool")

-- 配置 ClipboardTool 的參數（可選）
spoon.ClipboardTool.histSize = 100          -- 最多儲存 100 筆歷史紀錄
spoon.ClipboardTool.maxDisplayLength = 40   -- 選單中每條歷史紀錄最多顯示 40 個字
spoon.ClipboardTool.paste_on_select = true  -- 💡 點選選單後，自動直接貼上到當前視窗

-- 綁定快捷鍵（例如：⌥ + ⌘ + V 開啟剪貼簿歷史選單）
spoon.ClipboardTool:bindHotkeys({
    toggle_clipboard = {{"cmd", "alt"}, "V"}
})

-- 啟動 ClipboardTool 開始監聽剪貼簿
spoon.ClipboardTool:start()
spoon.ClipboardTool.show_in_menubar = true  -- 在頂部狀態列顯示剪貼簿圖示

hs.alert.show("ClipboardTool已就緒")