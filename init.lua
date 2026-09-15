-- init.lua
-- For JIS keyboard IME Switcher & Shottr Premium Full Integration

-- ==============================================================================
-- 匯入外部延展區塊,若有相同設定,則會由後載入取代
-- ==============================================================================
--require("fn_youtube")
--require("hs_clip2texteditor")

-- ==============================================================================
-- 終極調教相容版 init.lua (第一部分：核心基礎、變數與輸入法智慧切換)
-- ==============================================================================

local DEBUG_FLAG = false  -- 偵錯開關，關閉為 false
local EISUU_KEY = 102
local KANA_KEY = 104
local LSHIFT_KEY = 56
local LCMD_KEY = 55
local RCMD_KEY = 54
local LALT_KEY = 58
local RALT_KEY = 61
local YEN_KEY = 93
local RFN_KEY = 179
local DOUBLE_CLICK_TIMER = 0.3 -- 微調至 0.22 秒，讓雙擊判定更緊湊流暢
local ABC_IME_ID = "com.apple.keylayout.ABC"
local CLICK_IME_ID = "com.apple.inputmethod.TCIM.Cangjie" -- 預設切換倉頡

local FIXED_SNIPPETS = {
	{ title = "📧 我的電子郵件", text = "myemailk@gmail.com" },
	{ title = "🏢 公司統一編號", text = "12345678" },
	{ title = "📍 常用寄件地址", text = "台北市信義區信義路五段7號" },
	{ title = "✍️ 常用客套回覆", text = "收到，感謝您的協助！我會盡快確認後回覆您。" },
}

-- 白名單設定，切換 app 時，中文輸入法延用(true)，切換成 ABC(false)
local WHITE_LIST_IDS = {
	["com.apple.Notes"] = true,
	["com.apple.Terminal"] = false,
	["com.qvacua.VimR"] = false,
	["com.mitchellh.ghostty"] = false,
	["com.coteditor.CotEditor"] = false,
	["jp.naver.line.mac"] = true,
	["net.machorro.roberto.Moped"] = true,
	["com.apple.appkit.xpc.openAndSavePanelService"] = true,
	["com.apple.print.PrinterProxy"] = true,
	["com.sublimetext.4"] = false,
}

local COOLDOWN_TIME = 0.2
local lastTriggerTime = 0

local clipboardHistory = {}
local MAX_CLIPBOARD_ITEMS = 10
local lastCount = hs.pasteboard.changeCount()

-- 剪貼簿歷史監聽器
clipboardTimer = hs.timer.doEvery(0.5, function()
	local currentCount = hs.pasteboard.changeCount()
	if currentCount ~= lastCount then
		local nowContent = hs.pasteboard.getContents()
		if nowContent and nowContent ~= "" then
			local isFixed = false
			for _, fixed in ipairs(FIXED_SNIPPETS) do
				if nowContent == fixed.text then
					isFixed = true
					break
				end
			end
			if not isFixed and nowContent ~= clipboardHistory then
				table.insert(clipboardHistory, 1, nowContent)
				if #clipboardHistory > MAX_CLIPBOARD_ITEMS then
					table.remove(clipboardHistory)
				end
			end
		end
		lastCount = currentCount
	end
end):start()

-- 剪貼簿模糊搜尋選單
local function showClipboardChooser()
	local choices = {}
	for _, fixed in ipairs(FIXED_SNIPPETS) do
		table.insert(choices, {
			text = fixed.title,
			subText = fixed.text,
			actualText = fixed.text,
		})
	end
	for i, item in ipairs(clipboardHistory) do
		local summary = string.gsub(item, "[\r\n]", " ")
		if string.len(summary) > 40 then
			summary = string.sub(summary, 1, 40) .. "..."
		end
		table.insert(choices, {
			text = string.format("[%d] 📋 %s", i, summary),
			subText = item,
			actualText = item,
		})
	end
	if #choices == 0 then
		hs.alert.show("📭 選單目前沒有內容")
		return
	end
	if myChooser then myChooser:delete() end
	myChooser = hs.chooser.new(function(choice)
		if choice then
			hs.pasteboard.setContents(choice.actualText)
			hs.timer.doAfter(0.02, function()
				hs.eventtap.keyStroke({ "cmd" }, "v", 0)
			end)
		end
	end)
	myChooser:choices(choices)
	myChooser:placeholderText("輸入關鍵字可模糊搜尋常用字或剪貼簿...")
	myChooser:show()
end

-- 模擬系統輸入法切換
local function simulateSystemImeSwitch()
	local currentTime = hs.timer.secondsSinceEpoch()
	if currentTime - lastTriggerTime < COOLDOWN_TIME then return end
	lastTriggerTime = currentTime
	hs.eventtap.keyStroke({ "ctrl" }, "space", 10000)
end

-- 混合式精準輸入法切換
local function setSpecificIME(imeID)
	local frontApp = hs.application.frontmostApplication()
	local appBundleID = frontApp and frontApp:bundleID() or ""
	if appBundleID == "com.apple.Safari" then
		local current = hs.keycodes.currentSourceID()
		if current ~= imeID then simulateSystemImeSwitch() end
	else
		hs.keycodes.currentSourceID(imeID)
	end
end

-- -----------------------------------------------------------------------------
-- 1. かな (Kana) 鍵監聽 (已調教優化：單擊 0 延遲極速切換)
-- -----------------------------------------------------------------------------
local kanaLastClickTime = 0
kanaTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	if keyCode == KANA_KEY then
		if flags.alt then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "2", 0) -- Opt + かな = 滾動長截圖
			return true
		end
		if flags.cmd then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "4", 0) -- Cmd + かな = 區域截圖
			return true
		end

		local currentTime = hs.timer.secondsSinceEpoch()
		if (currentTime - kanaLastClickTime) < DOUBLE_CLICK_TIMER then
			-- 雙擊情境：補救切換到系統下一個輸入法
			simulateSystemImeSwitch()
			kanaLastClickTime = 0
		else
			-- 單擊情境：【零延遲核心】一按下立刻強制切換為倉頡，完全不等待計時器！
			setSpecificIME(CLICK_IME_ID)
			kanaLastClickTime = currentTime
		end
		return true
	end
	return false
end):start()

-- -----------------------------------------------------------------------------
-- 2. 英數 (Eisuu) 鍵監聽 (已調教優化：單擊 0 延遲切英文，並修復雙擊按鍵外噴 BUG)
-- -----------------------------------------------------------------------------
local eisuuLastClickTime = 0
eisuuTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	if keyCode == EISUU_KEY then
		if flags.alt then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "1", 0)
			return true
		end
		if flags.cmd then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "3", 0)
			return true
		end

		local currentTime = hs.timer.secondsSinceEpoch()
		if (currentTime - eisuuLastClickTime) < DOUBLE_CLICK_TIMER then
			-- 雙擊情境：喚出剪貼簿選單
			showClipboardChooser()
			eisuuLastClickTime = 0
		else
			-- 單擊情境：【零延遲核心】一按下立刻強制切英文，完全不等待計時器！
			hs.keycodes.currentSourceID(ABC_IME_ID)
			eisuuLastClickTime = currentTime
		end
		return true -- 100% 阻斷按鍵事件，確保雙擊時「英數」鍵訊號絕不外噴進輸入框
	end
	return false
end):start()
-- -----------------------------------------------------------------------------
-- 3. 修飾鍵監聽 (雙擊 left Cmd 喚出錄影、雙擊 Option 喚出 Shottr 截圖)
-- -----------------------------------------------------------------------------
local cmdClickCount = 0
local cmdClickTimer = nil
local altClickCount = 0
local altClickTimer = nil

modifierTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	if keyCode == LSHIFT_KEY and flags.shift and flags.cmd then
		simulateSystemImeSwitch()
		return true
	end

	if keyCode == LCMD_KEY or keyCode == RCMD_KEY then
		if flags.cmd and not flags.shift and not flags.ctrl and not flags.alt then
			if cmdClickTimer then cmdClickTimer:stop() end
			cmdClickCount = cmdClickCount + 1
			if cmdClickCount == 1 then
				cmdClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function() cmdClickCount = 0 end)
			elseif cmdClickCount == 2 then
				cmdClickCount = 0
				hs.eventtap.keyStroke({ "cmd", "shift" }, "5", 0)
				return true
			end
		end
	end

	if keyCode == LALT_KEY or keyCode == RALT_KEY then
		if flags.alt and not flags.cmd and not flags.shift and not flags.ctrl then
			if altClickTimer then altClickTimer:stop() end
			altClickCount = altClickCount + 1
			if altClickCount == 1 then
				altClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function() altClickCount = 0 end)
			elseif altClickCount == 2 then
				altClickCount = 0
				hs.eventtap.keyStroke({ "cmd", "shift" }, "8", 0)
				return true
			end
		end
	end
	return false
end):start()

-- 4. JIS 特有實體鍵監聽 (Cmd + ¥ 重複上一次截圖)
screenshotKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()
	if keyCode == YEN_KEY and flags.cmd then
		hs.eventtap.keyStroke({ "cmd", "shift" }, "7", 0)
		return true
	end
	return false
end):start()

-- 5. App 狀態啟用監聽器 (防卡死與全域環境自適應切換)
appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
	if eventType == hs.application.watcher.activated then
		if appObject then
			local appBundleID = appObject:bundleID()
			local isWhitelisted = WHITE_LIST_IDS[appBundleID] or false
			if not isWhitelisted then
				hs.timer.doAfter(0.05, function()
					hs.keycodes.currentSourceID(ABC_IME_ID)
				end)
			end
		end
		hs.timer.doAfter(0.1, function()
			if not hs.eventtap.isSecureInputEnabled() then
				if kanaTap then kanaTap:stop(); kanaTap:start() end
				if eisuuTap then eisuuTap:stop(); eisuuTap:start() end
				if modifierTap then modifierTap:stop(); modifierTap:start() end
				if screenshotKeyTap then screenshotKeyTap:stop(); screenshotKeyTap:start() end
			end
		end)
	end
end):start()

-- 6. 每 3 秒背景防護定時器
secureInputTimer = hs.timer.doEvery(3, function()
	if not hs.eventtap.isSecureInputEnabled() then
		if kanaTap and not kanaTap:isEnabled() then kanaTap:start() end
		if eisuuTap and not eisuuTap:isEnabled() then eisuuTap:start() end
		if modifierTap and not modifierTap:isEnabled() then modifierTap:start() end
		if screenshotKeyTap and not screenshotKeyTap:isEnabled() then screenshotKeyTap:start() end
	end
end):start()

-- Debug 偵錯區
keyLogger = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	if DEBUG_FLAG then
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()
		print(string.format("Key Code: %s | Modifiers: %s", keyCode, hs.inspect(flags)))
	end
	return false
end):start()

testWatcher = hs.application.watcher.new(function(name, event, app)
   if event == hs.application.watcher.activated and app and DEBUG_FLAG then
      print("App名稱: " .. name .. " | BundleID: " .. tostring(app:bundleID()))
   end
end):start()

-- ==============================================================================
-- 7. CotEditor 一鍵安全開新檔 (強制前台操作版 - 100% 獨立白紙隔離，不污染舊檔)
-- ==============================================================================
hs.hotkey.bind({ "alt", "cmd"}, "M", function()
    hs.application.launchOrFocus("CotEditor")
    hs.timer.doAfter(0.25, function()
        local app = hs.application.frontmostApplication()
        if app and app:name() == "CotEditor" then
            hs.eventtap.keyStroke({"cmd"}, "n", 0)
            hs.timer.doAfter(0.1, function()
                hs.eventtap.keyStroke({"cmd"}, "v", 0)
                hs.alert.show("📝 由剪貼簿成功轉貼未命名新檔，請自行存檔！", 1)
            end)
        else
            hs.alert.show("⚠️ 視窗聚焦失敗，請再試一次", 2)
        end
    end)
end)

-- -----------------------------------------------------------------------------
-- 8. YouTube 網頁專用智能熱鍵區
-- -----------------------------------------------------------------------------
local browserApps = {
	["YouTube"] = true,
    ["Google Chrome"] = true,
    ["Safari"] = true,
    ["Microsoft Edge"] = true,
    ["Brave Browser"] = true
}

local function isYouTube()
    local app = hs.application.frontmostApplication()
    if not app or not browserApps[app:title()] then return false end
    local win = app:focusedWindow()
    if win and string.find(win:title(), "YouTube") then return true end
    return false
end

-- 功能 1：雙擊 fn 鍵回到 YouTube 首頁 (已校正為官方原生純淨 g+h 快捷鍵)
local lastFnTime = 0
fnTap = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.flagsChanged}, function(event)
    local keyCode = event:getKeyCode()
    if keyCode == RFN_KEY then
        local currentTime = hs.timer.secondsSinceEpoch()
        if (currentTime - lastFnTime) > 0.05 then
            if (currentTime - lastFnTime) < 0.38 then
                if isYouTube() then
                    hs.eventtap.keyStroke({}, "g", 0)
                    hs.timer.doAfter(0.05, function()
                        hs.eventtap.keyStroke({}, "h", 0)
                    end)
                    hs.alert.show("📺 返回 YouTube 首頁")
                end
                lastFnTime = 0
                return true
            else
                lastFnTime = currentTime
            end
        end
    end
    return false
end):start()

-- 功能 2：fn + 方向鍵 映射 (相容 Mac 晶片硬體轉譯碼)
arrowTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    
    if flags.fn and isYouTube() then    
        if keyCode == 121 or keyCode == 125 then
            hs.eventtap.keyStroke({}, "f", 0)
            return true
        elseif keyCode == 116 or keyCode == 126 then
            hs.eventtap.keyStroke({}, "escape", 0)
            return true
        elseif keyCode == 124 then
            hs.eventtap.keyStroke({}, "tab", 0)
            return true
        elseif keyCode == 123 then
            hs.eventtap.keyStroke({"shift"}, "tab", 0)
            return true
        end
    end
    return false
end):start()

hs.autoLaunch(true)
hs.alert.show("Hammerspoon 終極優化配置已啟用 📺")
