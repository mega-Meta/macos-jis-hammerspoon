-- init.lua
-- For JIS keyboard IME Switcher & Shottr Premium Full Integration

-- =========================================================================
-- 🛡️ 1. 全方位安全載入防護機制 (必須放在檔案最頂端，第 1 行！)
-- =========================================================================

-- 【A. Spoons 安全載入】
function safeLoadSpoon(spoonName)
    local spoonPath = hs.configdir .. "/Spoons/" .. spoonName .. ".spoon"
    local fileInfo = hs.fs.attributes(spoonPath)
    
    if fileInfo and fileInfo.mode == "directory" then
        return hs.loadSpoon(spoonName)
    else
        local warnMsg = string.format("⚠️ 找不到 Spoons [%s] 外掛，請下載安裝！", spoonName)
        print(warnMsg)
        hs.alert.show(warnMsg, {strokeColor={hex="#FFAA00", alpha=1}}, 3)
        return nil
    end
end

-- 【B. 子模組 Require 安全載入】
function safeRequire(moduleName)
    -- 使用 pcall 保護調用，即使檔案不存在或內部語法有錯，也絕不崩潰卡死
    local success, err = pcall(require, moduleName)
    
    if success then
        return true
    else
        -- 補捉到錯誤，優雅提示
        local warnMsg = string.format("⚠️ 模組 [%s.lua] 載入失敗！", moduleName)
        print(warnMsg .. "\n詳細錯誤原因:\n" .. tostring(err)) -- 在 Console 印出具體是少檔案還是語法錯
        hs.alert.show(warnMsg, {strokeColor={hex="#FF5555", alpha=1}}, 4)
        return false
    end
end

-- =========================================================================
-- 🚀 2. 安全載入區 (從此免疫所有遺失檔案的崩潰)
-- =========================================================================

-- 安全載入官方 Spoons
safeLoadSpoon("WindowSigils")
safeLoadSpoon("ClipboardTool")


-- ⭐️ 安全載入你的所有子模組（將 require 全部改用 safeRequire）
safeRequire("snippets")
safeRequire("auto_reload")
--safeRequire("hs_debug")
safeRequire("spoon_clipboardtool")
-- safeRequire("spoon_windowsigils")


--local DEBUG_FLAG = false  --off is false
local EISUU_KEY = 102
local KANA_KEY = 104
local LSHIFT_KEY = 56
local LCMD_KEY = 55
local RCMD_KEY = 54
local LALT_KEY = 58
local RALT_KEY = 61
local YEN_KEY = 93
local RFN_KEY = 179
local DOUBLE_CLICK_TIMER = 0.3
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

local COOLDOWN_TIME = 0.15
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
local masks = hs.eventtap.event.rawFlagMasks
kanaTap = hs.eventtap
	.new({ hs.eventtap.event.types.keyDown }, function(event)
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()
		local rawFlags = event:rawFlags()

		if keyCode == KANA_KEY then
			if flags.alt then
				hs.eventtap.keyStroke({ "cmd", "shift" }, "2", 0) -- Opt + かな = 滾動長截圖
				return true
			end

			if flags.cmd then
				if (rawFlags & masks.deviceRightCommand) ~= 0  then
					hs.eventtap.keyStroke({ "cmd", "shift" }, "7", 0) -- right Cmd + かな = repeat area screen
				else
					hs.eventtap.keyStroke({ "cmd", "shift" }, "4", 0) -- left Cmd + かな = 區域截圖
				end
				return true
			end
			
			if clickTimer then
				clickTimer:stop()
			end
			clickCount = clickCount + 1

			if clickCount == 1 then
				clickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
					setSpecificIME(CLICK_IME_ID) -- 單擊：智慧切倉頡
				    --hs.alert.show("中文輸入法切換成功")
					clickCount = 0
				end)
			elseif clickCount == 2 then
				simulateSystemImeSwitch() -- 雙擊：系統切換下一個輸入法
				clickCount = 0
			end
			return true
		end
		return false
	end)
	:start()

-- =========================================================================
-- 2. 英數 (Eisuu) 鍵監聽：支援單擊、雙擊、按住當組合鍵
-- =========================================================================
local eisuuClickCount = 0
local eisuuClickTimer = nil
local isEisuuPressed = false  -- 💡 精確追蹤英數鍵是否正被按住不放

eisuuTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.keyUp
}, function(event)
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()
    local eventType = event:getType() -- 💡 正確獲取目前是按下還是放開

    -- 【情況 A】：當操作的按鍵是「英數鍵」本身
    if keyCode == EISUU_KEY then
        if eventType == hs.eventtap.event.types.keyDown then
            isEisuuPressed = true -- 標記：目前英數鍵被按住了
            
            -- 保留你原本的 Shottr 快捷鍵整合 (Opt/Cmd + 英數)
            if flags.alt then
                hs.eventtap.keyStroke({ "cmd", "shift" }, "1", 0) -- alt + eisuu = shottr active window
                return true
            end
            if flags.cmd then
                hs.eventtap.keyStroke({ "cmd", "shift" }, "3", 0) -- cmd + eisuu - shottr area screen
                return true
            end
            
            if eisuuClickTimer then eisuuClickTimer:stop() end
            eisuuClickCount = eisuuClickCount + 1
            
        elseif eventType == hs.eventtap.event.types.keyUp then
            isEisuuPressed = false -- 標記：英數鍵已放開
            
            -- 如果按住期間沒有觸發組合鍵，放開時才執行原本的單擊/雙擊
            if eisuuClickCount > 0 then
                eisuuClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
                    if eisuuClickCount == 1 then
                        hs.keycodes.currentSourceID(ABC_IME_ID) -- 單擊：切英文
                    elseif eisuuClickCount == 2 then
                        if spoon.ClipboardTool then
                            spoon.ClipboardTool:toggleClipboard() -- 雙擊：官方剪貼簿
                        end
                    end
                    eisuuClickCount = 0
                end)
            end
        end
        return true -- 100% 攔截英數鍵，不讓它干擾系統
    end

        -- 【情況 B】：當「英數鍵正被按住不放」，且按下了其他按鍵時 -> 觸發組合鍵！
    if isEisuuPressed and eventType == hs.eventtap.event.types.keyDown then
        local char = hs.keycodes.map[keyCode]
        
        -- 🌟 核心功能：英數 + C (C 的 Keycode 確定是 8)
        if keyCode == 8 then
            eisuuClickCount = 0
            
            -- 💡 關鍵防護：先暫停監聽，防止自己發送的 Cmd+A/Cmd+C 觸發死迴圈
            eisuuTap:stop()
            
            hs.eventtap.keyStroke({ "cmd" }, "a", 0) -- 1. 全選
            hs.timer.doAfter(0.01, function()
                hs.eventtap.keyStroke({ "cmd" }, "c", 0) -- 2. 複製
            end)
            -- 執行完畢，重新啟動監聽器
            eisuuTap:start()
          
            return true
        end

        -- 🌟 核心功能：英數 + V (V 的 Keycode 確定是 9)
        if keyCode == 9 then
            eisuuClickCount = 0
            
            -- 💡 關鍵防護：先暫停監聽，防止自己發送的 Cmd+A 觸發下方的「英數+A」
            eisuuTap:stop()
            
            hs.eventtap.keyStroke({ "cmd" }, "a", 0) -- 1. 全選
            hs.timer.doAfter(0.01, function()
                hs.eventtap.keyStroke({ "cmd" }, "v", 0) -- 2. 貼上
            end)
            -- 執行完畢，重新啟動監聽器
            eisuuTap:start()
            return true
        end
        
       
        -- 🌟 核心功能：英數 + A (A 的 Keycode 是 0)
        if keyCode == 0 then
            eisuuClickCount = 0
            hs.alert.show("測試觸發了：英數 + A 組合鍵！")
            return true
        end
    end


    return false -- 其他一般打字 100% 正常放行，絕不卡死
end):start()


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

		-- 情境 B1：單獨雙擊 left Cmd 鍵 喚出工具列 (Cmd+Shift+0) shottr cupture any windows
		if keyCode == LCMD_KEY then --or keyCode == RCMD_KEY then
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
					hs.eventtap.keyStroke({ "cmd", "shift" }, "0", 0)
					return true
				end
			end
		end

		-- 情境 B2：單獨雙擊 right Cmd 鍵 喚出工具列 (Cmd+Shift+5) macos screen cupture main screen
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
					hs.eventtap.keyStroke({ "cmd", "shift" }, "5", 0)
					return true
				end
			end
		end


		-- 🌟 情境 C【全新新增】：單獨雙擊 Option 鍵 觸發 Shottr 功能 (Cmd+Shift+8) show shottr view and editor
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

		--if keyCode == YEN_KEY and flags.cmd then
		--	hs.eventtap.keyStroke({ "cmd", "shift" }, "7", 0) -- Cmd + ¥ = 重複上一次截圖
		--	return true
		--end

		if keyCode == RFN_KEY then
		  hs.eventtap.keyStroke({ "cmd", "shift" }, "H", 0) -- youtube go to homepage
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

-- 每次載入設定時，自動清空 Console 視窗
hs.console.clearConsole()

hs.autoLaunch(true)
