-- hs_battery.lua
-- 電池充電狀態監控，健康度守護模組
-- lowBatteryPercentage/topBatteryPercentage 可另外設定於引用主程式，設定不同閥值
--
-- 將監聽器變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil
sleepWatcher = nil
batteryTimer = nil

local lowBatteryAlertTriggered = false

---------------------------------------------------------
-- 🛡️ 防呆機制：檢查 init.lua 是否有設定全域變數，若無則套用預設值
---------------------------------------------------------
local lowBatteryPercentage = lowBatteryPercentage or 30
local topBatteryPercentage = topBatteryPercentage or 85

---------------------------------------------------------
-- 🔍 偵測 bclm 的實際檔案路徑
---------------------------------------------------------
local function getBcalmPath()
    local possiblePaths = {
        "/usr/local/bin/bclm",
        "/opt/homebrew/bin/bclm"
    }
    for _, path in ipairs(possiblePaths) do
        if hs.fs.attributes(path) then return path end
    end
    return nil
end

local bclmPath = getBcalmPath()

if not bclmPath then
    hs.dialog.alert(100, 100, function() end,
        "⚠️ 找不到 bclm 工具",
        "Hammerspoon 無法在預設路徑中找到 bclm，自動停止充電功能將無法運作。",
        "我知道了", nil, "critical")
end

--[[  for BCLM
#install
$ brew tap zackelia/formulae
$ brew install bclm

$ sudo bclm write 77
$ bclm read
77
#for app bypass sudo password
$which bclm
$ sudo visudo
#add last line and save
%admin ALL = (ALL) NOPASSWD: /usr/local/bin/bclm
$ sudo bclm persist
]]--

---------------------------------------------------------
-- ⚙️ bclm 寫入函式（Loading時讀取硬體值比對，一次性寫入）
---------------------------------------------------------
local function writeBclmValue(targetValue, reason)
    if not bclmPath then return end
    
    -- 🔍 先非同步讀取目前 SMC 硬體內真正的限制值（免 sudo，速度極快）
    hs.task.new(bclmPath, function(readExitCode, readStdOut, readStdErr)
        if readExitCode == 0 and readStdOut then
            -- 清除多餘的換行與空白，取得乾淨的硬體現值
            local currentHardwareValue = string.gsub(readStdOut, "%s+", "")
            
            -- 如果目前硬體值已經等於目標值，直接不重寫
            if currentHardwareValue == tostring(targetValue) then
                print(string.format("ℹ️ [%s] 電池充電上限設定%s%% ＝ 硬體bclm值，無需覆寫。", reason, targetValue))
                return
            end
            
            -- 💡 如果數值有異動，才真正發動寫入
            hs.task.new("/usr/bin/sudo", function(writeExitCode, writeStdOut, writeStdErr)
                if writeExitCode == 0 then
                    print(string.format("🔋 [%s] 偵測bclm為 %s%%，已成功將硬體充電限制修改為 %s%%。", reason, currentHardwareValue, targetValue))
                else
                    print("BCLM 寫入錯誤: " .. (writeStdErr or "未知原因"))
                end
            end, {bclmPath, "write", tostring(targetValue)}):start()
        else
            print("BCLM 讀取錯誤: " .. (readStdErr or "未知原因"))
        end
    end, {"read"}):start()
end

---------------------------------------------------------
-- ⚡ 電量控制邏輯
---------------------------------------------------------
local function monitorBatteryStatus()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end
    
    --print(string.format("🔋 目前電量: %s%%, 充電狀況: %s", percentage, powerSource))

    -- 狀況 A：低於設定值 且沒在充電 -> 播放警示音 + 彈窗警告
    if percentage <= lowBatteryPercentage and not isCharging then
        if not lowBatteryAlertTriggered then
            local sound = hs.sound.getByName("Sosumi")
            if sound then sound:play() end

            hs.dialog.alert(100, 100, function() end,
                "🔋 電量過低！",
                "目前電量已降至 " .. string.format("%.0f", percentage) .. "%。請盡快接上電源。",
                "確定", nil, "warning")
            lowBatteryAlertTriggered = true
        end
    else
        if percentage >= lowBatteryPercentage or isCharging then
            lowBatteryAlertTriggered = false
        end
    end
    
    -- 狀況 B：過充5%提示預警防禦
    if percentage > (topBatteryPercentage) + 5 and isCharging then
        local sound = hs.sound.getByName("Blow")
        if sound then sound:play() end
        hs.speech.new():speak("電池已超出限制，請重新插拔電源線")
        hs.dialog.alert(100, 100, function() end,
            "🚨 SMC 硬體充電卡死！",
            "目前已達 " .. string.format("%.0f", percentage) .. "%（上限為 " .. topBatteryPercentage .. "%）。\n\n硬體暫存器值雖正確，但晶片卡死，請【拔掉 Mac 電源線，等待3秒再插回】強制重設硬體狀態！",
            "我知道了", nil, "critical")
    end

    -- 狀況 C：預防過充，可提早 5% 預警防禦
   -- local earlyTriggerPercentage = topBatteryPercentage - 5
   -- if percentage >= earlyTriggerPercentage and powerSource == "AC Power" then
   --     writeBclmValue(topBatteryPercentage, "電量達預警區")
    --elseif powerSource == "Battery Power" then
    --    writeBclmValue(100, "拔除電源線")
    --end
end

print(string.format("🔋 電池守護者參數設定 -> 低電量警告: %d%%, 充電上限: %d%%", lowBatteryPercentage, topBatteryPercentage))

-- 🕒 監聽器啟動
-- 🕒 1. 原有的事件監聽器（保持啟用）
batteryWatcher = hs.battery.watcher.new(monitorBatteryStatus)
batteryWatcher:start()

-- 🕒 2. 💡 定時檢查器（每 5 分鐘主動檢查一次，防止錯過狀態改變）
if batteryTimer then batteryTimer:stop() end
batteryTimer = hs.timer.doEvery(300, function()
    print("🕒 [定時檢查] 執行電池狀態例行檢查...")
    monitorBatteryStatus()
end)

-- 🚀 3. 💡 一開機或重載配置
hs.timer.doAfter(2, function()
    writeBclmValue(topBatteryPercentage, "模組啟動初始化")
end)

-- 4.主動執行一次電量檢查
hs.timer.doAfter(5,function()
    print("🚀 [初始化] 執行首次電池電量檢查...")
    monitorBatteryStatus()
end)

-- 模組啟動提示
hs.notify.new({title="Hammerspoon", informativeText="電池智慧守護模組已成功啟動！"}):send()
