-- init.lua
-- For JIS keyboard IME Switcher & Shottr Premium Full Integration

--[[
-- 載入名為 WindowHalfsies 的 Spoon
hs.loadSpoon("WindowHalfsies")
]]--
hs.loadSpoon("WindowSigils")
hs.loadSpoon("ClipboardTool")
hs.loadSpoon("BrewInfo")

require("snippets")
require("auto_reload")
--require("hs_debug") -- show keyid & appsid on console
require("spoon_clipboardtool")
--require("spoon_windowsigils")
require("spoon_brewinfo")

local DEBUG_FLAG = false  --off is false
local EISUU_KEY = 102
local KANA_KEY = 104
local LSHIFT_KEY = 56
local LCMD_KEY = 55
local RCMD_KEY = 54
local LALT_KEY = 58
local RALT_KEY = 61
local YEN_KEY = 93
local RFN_KEY = 179
local DOUBLE_CLICK_TIMER = 0.35
local ABC_IME_ID = "com.apple.keylayout.ABC"
local CLICK_IME_ID = "com.apple.inputmethod.TCIM.Cangjie" --#倉頡
--local CLICK_IME_ID = "com.apple.inputmethod.TCIM.Zhuyin" --#繁體倚天注音

local FIXED_SNIPPETS = {
	{ title = "📧 我的電子郵件", text = "myemailk@gmail.com" },
	{ title = "🏢 公司統一編號", text = "12345678" },
	{ title = "📍 常用寄件地址", text = "台北市信義區信義路五段7號" },
	{ title = "✍️ 常用客套回覆", text = "收到，感謝您的協助！我會盡快確認後回覆您。" },
}

-- 白名單設定，切換app時，中文輸入法延用(true)，切換成ABC(false)。
local WHITE_LIST_IDS = {
	["com.apple.Notes"] = true,
	["com.apple.Terminal"] = false, --terminal應該以英文為主，所以要切換
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

-- 模擬按下系統「選取下一個輸入來源」快捷鍵 (Control + Space)
local function simulateSystemImeSwitch()
	local currentTime = hs.timer.secondsSinceEpoch()
	if currentTime - lastTriggerTime < COOLDOWN_TIME then
		return
	end
	lastTriggerTime = currentTime
	hs.eventtap.keyStroke({ "ctrl" }, "space", 10000)
end

-- 混合式精準切換
local function setSpecificIME(imeID)
	local frontApp = hs.application.frontmostApplication()
	local appBundleID = frontApp and frontApp:bundleID() or ""

	if appBundleID == "com.apple.Safari" then
		local current = hs.keycodes.currentSourceID()
		if current ~= imeID then
			simulateSystemImeSwitch()
		end
	else
		hs.keycodes.currentSourceID(imeID)
	end
end

-- 1. かな 鍵監聽 (包含輸入法切換、Cmd+かな區域截圖、Opt+かな滾動長截圖)
local clickCount = 0
local clickTimer = nil
--local DOUBLE_CLICK_TIMEOUT = 0.50

kanaTap = hs.eventtap
	.new({ hs.eventtap.event.types.keyDown }, function(event)
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

			if clickTimer then
				clickTimer:stop()
			end
			clickCount = clickCount + 1

			if clickCount == 1 then
				clickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
					setSpecificIME(CLICK_IME_ID) -- 單擊：智慧切倉頡
					clickCount = 0
				end)
			elseif clickCount == 2 then
				simulateSystemImeSwitch() -- 雙擊：系統切換下一個
				clickCount = 0
			end
			return true
		end
		return false
	end)
	:start()

-- 2. 英數 (Eisuu) 鍵監聽：移入集中式狀態機，支援「單擊英文、雙擊選單」
local eisuuClickCount = 0
local eisuuClickTimer = nil
--local EISUU_DOUBLE_TIMEOUT = 0.40
eisuuTap = hs.eventtap
	.new({ hs.eventtap.event.types.keyDown }, function(event)
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
			if eisuuClickTimer then
				eisuuClickTimer:stop()
			end
			eisuuClickCount = eisuuClickCount + 1
			eisuuClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
				if eisuuClickCount == 1 then
					hs.keycodes.currentSourceID(ABC_IME_ID)
				-- 更改 init.lua 第 167 行附近的 eisuuClickTimer 內部邏輯：
                elseif eisuuClickCount == 2 then
                 -- 改成直接呼叫官方 Spoon 的選單，讓雙擊英數鍵與 ⌥+⌘+V 共享同一個剪貼簿資料庫！
                    if spoon.ClipboardTool then spoon.ClipboardTool:toggleClipboard() end
                end

				eisuuClickCount = 0
			end)
			return true
		end
		return false
	end)
	:start()

-- 3. 修飾鍵監聽 (Cmd+LShift切換、雙擊Cmd工具列、🌟新增：雙擊Option自訂截圖)
local cmdClickCount = 0
local cmdClickTimer = nil
local altClickCount = 0
local altClickTimer = nil

modifierTap = hs.eventtap
	.new({ hs.eventtap.event.types.flagsChanged }, function(event)
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()

		-- 情境 A：Cmd + Left Shift 切換輸入法
		if keyCode == LSHIFT_KEY and flags.shift and flags.cmd then
			simulateSystemImeSwitch()
			return true
		end

		-- 情境 B：單獨雙擊 left Cmd 鍵 $\rightarrow$ 喚出工具列 (Cmd+Shift+5)
		if keyCode == LCMD_KEY or keyCode == RCMD_KEY then
			if flags.cmd and not flags.shift and not flags.ctrl and not flags.alt then
				if cmdClickTimer then
					cmdClickTimer:stop()
				end
				cmdClickCount = cmdClickCount + 1
				if cmdClickCount == 1 then
					cmdClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
						cmdClickCount = 0
					end)
				elseif cmdClickCount == 2 then
					cmdClickCount = 0
					hs.eventtap.keyStroke({ "cmd", "shift" }, "5", 0)
					return true
				end
			end
		end

		-- 情境 B2：單獨雙擊 right Cmd 鍵 $\rightarrow$ 喚出工具列 (Cmd+Shift+H) for youtube show Home
		--[[
		if keyCode == RCMD_KEY then
			if flags.cmd and not flags.shift and not flags.ctrl and not flags.alt then
				if cmdClickTimer then
					cmdClickTimer:stop()
				end
				cmdClickCount = cmdClickCount + 1
				if cmdClickCount == 1 then
					cmdClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
						cmdClickCount = 0
					end)
				elseif cmdClickCount == 2 then
					cmdClickCount = 0
					hs.eventtap.keyStroke({ "cmd", "shift" }, "H", 0)
					return true
				end
			end
		end
		]]--

		-- 🌟 情境 C【全新新增】：單獨雙擊 Option 鍵 $\rightarrow$ 觸發 Shottr 功能 (Cmd+Shift+8)
		if keyCode == LALT_KEY or keyCode == RALT_KEY then
			-- 當按下 Option，且此時沒有混雜其他的修飾鍵 (如 Cmd、Shift、Ctrl)
			if flags.alt and not flags.cmd and not flags.shift and not flags.ctrl then
				if altClickTimer then
					altClickTimer:stop()
				end
				altClickCount = altClickCount + 1
				if altClickCount == 1 then
					altClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
						altClickCount = 0
					end)
				elseif altClickCount == 2 then
					altClickCount = 0
					hs.eventtap.keyStroke({ "cmd", "shift" }, "8", 0) -- 模擬發送 Cmd+Shift+8
					return true
				end
			end
		end

		return false
	end)
	:start()

-- 4. JIS 特有實體鍵監聽 (包含：Cmd + ¥ 重複區域截圖)
screenshotKeyTap = hs.eventtap
	.new({ hs.eventtap.event.types.keyDown }, function(event)
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()

		if keyCode == YEN_KEY and flags.cmd then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "7", 0) -- Cmd + ¥ = 重複上一次截圖
			return true
		end

		if keyCode == RFN_KEY then
		  hs.eventtap.keyStroke({ "cmd", "shift" }, "H", 0) -- Cmd + ¥ = 重複上一次截圖
			return true
		end

		return false
	end)
	:start()

-- 5. App 監聽器
appWatcher = hs.application.watcher
	.new(function(appName, eventType, appObject)
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
					if kanaTap then
						kanaTap:stop()
						kanaTap:start()
					end
					if eisuuTap then
						eisuuTap:stop()
						eisuuTap:start()
					end
					if modifierTap then
						modifierTap:stop()
						modifierTap:start()
					end
					if screenshotKeyTap then
						screenshotKeyTap:stop()
						screenshotKeyTap:start()
					end
				end
			end)
		end
	end)
	:start()

-- 6. 每 3 秒背景防護（防卡死）
secureInputTimer = hs.timer.doEvery(3, function()
	if not hs.eventtap.isSecureInputEnabled() then
		if kanaTap and not kanaTap:isEnabled() then
			kanaTap:start()
		end
		if eisuuTap and not eisuuTap:isEnabled() then
			eisuuTap:start()
		end
		if modifierTap and not modifierTap:isEnabled() then
			modifierTap:start()
		end
		if screenshotKeyTap and not screenshotKeyTap:isEnabled() then
			screenshotKeyTap :start()
		end
	end
end)
:start()

-- 	⭐️ 穩定的寫法：加入唯一的識別名稱，讓 macOS 記住它的位置
--myMenu = hs.menubar.new(true, "myUniqueHammerspoonMenuName")

-- 💡 改良版：延遲 0.2 秒再重載，防止選單列圖示變成空白
--[[
hs.hotkey.bind({"cmd", "alt"}, "C", function()
    --hs.alert.show("正在重載設定...")
    hs.timer.doAfter(0.2, function()
        hs.reload()
    end)
    
end)
:start()
]]--
-- 每次載入設定時，自動清空 Console 視窗
hs.console.clearConsole()

hs.autoLaunch(true)
