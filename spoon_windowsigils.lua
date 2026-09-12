

-- 載入 WindowSigils Spoon
hs.loadSpoon("WindowSigils")

-- 配置與啟動 WindowSigils
-- 我們將全域快捷鍵綁定為 ⌥ + ⌘ + W

    -- 1. 先做基礎配置
spoon.WindowSigils:configure({
    mode_keys = {
        -- 注意：這裡的 key 是字串，所以可以直接寫在裡面
        ["control-g"] = function() spoon.WindowSigils:exit() end,
    }
})

-- 2. 獨立出來寫，這樣 Lua 就能正確識別 Table 作為 Key 的語法了
spoon.WindowSigils.sigil_actions[{'control'}] = function(window)
    if window then window:close() end
end

spoon.WindowSigils.sigil_actions[{'shift'}] = function(window)
    if window then window:maximize() end
end

-- 綁定進入「印記模式」的快捷鍵
-- 這裡設定 ⌥ + ⌘ + W，你可以改成你習慣的組合
spoon.WindowSigils:bindHotkeys({
    enter_sigil_mode = {{"cmd", "alt"}, "W"}
})

-- 啟動外掛
spoon.WindowSigils:start()
