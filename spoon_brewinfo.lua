-- 載入 BrewInfo Spoon
hs.loadSpoon("BrewInfo")

-- 自訂彈出視窗的樣式（可選）
spoon.BrewInfo.brew_info_style = {
    textFont = "Inconsolata",  -- 使用的字體
    textSize = 14,             -- 字體大小
    radius = 10                -- 彈出視窗的圓角弧度
}

-- 綁定快捷鍵
spoon.BrewInfo:bindHotkeys({
    -- 功能 1：顯示所選套件的 brew info（這裡設定 ⌥ + ⌘ + B）
    show_brew_info = {{"cmd", "alt"}, "B"},
    
    -- 功能 2：直接打開所選套件的官網（這裡設定 ⇧ + ⌥ + ⌘ + B）
    open_brew_url  = {{"cmd", "alt", "shift"}, "B"}
})
