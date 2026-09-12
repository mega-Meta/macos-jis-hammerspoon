-- ~/.hammerspoon/snippets.lua

-- 1. 載入資料庫
local snippet_subs = require("hs_snippets")




-- =========================================================================
-- 2. 核心發送模組（使用最安全的 KeyStrokes 原生打字流）
-- =========================================================================
local function sendRawText(finalOutput)
    if type(finalOutput) == "function" then finalOutput = finalOutput() end

    -- 移除多行長字串可能夾帶的換行符號
    if type(finalOutput) == "string" then
        finalOutput = string.gsub(finalOutput, "^\n", "")
        finalOutput = string.gsub(finalOutput, "\n$", "")
    end

    -- 調整 snippets.lua 內的標籤替換，確保絕對不會因為特殊符號崩潰：
    local current_datetime = string.gsub(os.date("%Y-%m-%d %H:%M:%S"), "%%", "%%%%")
    finalOutput = string.gsub(finalOutput, "{datetime}", current_datetime)

    local current_date = string.gsub(os.date("%Y-%m-%d"), "%%", "%%%%")
    finalOutput = string.gsub(finalOutput, "{date format=\"yyyy%-MM%-dd\"}", current_date)
    finalOutput = string.gsub(finalOutput, "{time format=\"HH%%:mm\"}", os.date("%H:%M"))

    -- 【步驟 A：解析 $CLIPBOARD$】
    if string.find(finalOutput, "$CLIPBOARD$", 1, true) then
        local clipboardText = hs.pasteboard.readString() or ""
        clipboardText = string.gsub(clipboardText, "%%", "%%%%")
        finalOutput = string.gsub(finalOutput, "%$CLIPBOARD%$", clipboardText)
    end
    
    -- 【步驟 B：解析 $CURSOR$】
    local cursorMarker = "$CURSOR$"
    local matchStart, matchEnd = string.find(finalOutput, cursorMarker, 1, true)
    
    if matchStart then
        local prefixText = string.sub(finalOutput, 1, matchStart - 1)
        local suffixText = string.sub(finalOutput, matchEnd + #cursorMarker)
        local cleanText = prefixText .. suffixText
        
        local textLengthWithoutMarker = #cleanText
        local prefixLength = matchStart - 1
        -- 嘗試用更安全的字元計數
        pcall(function()
            textLengthWithoutMarker = utf8.len(cleanText) or textLengthWithoutMarker
            prefixLength = utf8.len(prefixText) or prefixLength
        end)
        local leftArrowCount = textLengthWithoutMarker - prefixLength
        
        -- 直接噴出文字
        hs.eventtap.keyStrokes(cleanText)
        
        -- 延遲後退回游標
        if leftArrowCount > 0 then
            hs.timer.doAfter(0.02, function()
                for i = 1, leftArrowCount do hs.eventtap.keyStroke({}, "left", 0) end
            end)
        end
    else
        hs.eventtap.keyStrokes(finalOutput)
    end
end

-- =========================================================================
-- 3. 完美修復版：全域直接打字監聽器（安全放行、絕不卡死）
-- =========================================================================
local inputBuffer = ""

if snippetWatcher then
    pcall(function() snippetWatcher:stop() end)
end

snippetWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    local keyCode = event:getKeyCode()
    local keyName = hs.keycodes.map[keyCode]
    
    -- 安全閥：按下 Cmd, Ctrl, Alt 組合鍵時，立刻放行並清空緩衝區
    local flags = event:getFlags()
    if flags.cmd or flags.ctrl or flags.alt then
        inputBuffer = ""
        return false
    end

    -- 處理刪除鍵：使用者打錯字按 Backspace，同步減少緩衝區
    if keyName == "delete" then
        if #inputBuffer > 0 then inputBuffer = string.sub(inputBuffer, 1, -2) end
        return false
    -- 遇到 Return, Escape, Tab 代表輸入中斷，清空緩衝區
    elseif keyName == "return" or keyName == "escape" or keyName == "tab" then
        inputBuffer = ""
        return false
    end
    
    -- 捕捉鍵盤一般輸入
    local char = event:getCharacters()
    if char and #char == 1 then
        inputBuffer = inputBuffer .. char
        
        -- 限制緩衝區最大長度
        if #inputBuffer > 20 then inputBuffer = string.sub(inputBuffer, -20) end

        -- 即時進行關鍵字比對
        for trigger, replaceText in pairs(snippet_subs) do
            if #inputBuffer >= #trigger and string.sub(inputBuffer, -#trigger) == trigger then
                
                -- 計算要按幾次 Delete 鍵
                local deleteCount = #trigger
                pcall(function() deleteCount = utf8.len(trigger) or deleteCount end)
                
                -- 核心修復：立即清空緩衝區，並使用安全隊列順序執行
                inputBuffer = ""
                
                -- 攔截當前最後一個字元，並開啟微秒級有序異步序列
                hs.timer.doAfter(0.01, function()
                    -- 1. 先把原本打的 trigger 刪乾淨
                    for i = 1, deleteCount do
                        hs.eventtap.keyStroke({}, "delete", 0)
                    end
                    -- 2. 🌟 關鍵關鍵：多等待 40 毫秒，等 Mac 系統確定把字擦乾淨了，才把新字原創打上去！
                    hs.timer.doAfter(0.04, function()
                        sendRawText(replaceText)
                    end)
                end)
                
                return true -- 命中時，只攔截最後一個字元，前方的字元交給上面的 Delete 序列處理
            end
        end
    end
    
    return false -- 沒命中時，100% 放行日常打字，鍵盤絕不卡死
end):start()

hs.alert.show("直接打字即時觸發版已就緒 🚀")
