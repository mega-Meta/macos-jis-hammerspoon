---
apple-notes-id: FE235125-AE4B-4782-9957-E40D18C6E7FA
tags:
  - hammerspoon
  - bclm
  - battery
  - charge
  - lua
---
## Original model

Here is a complete, optimized **Hammerspoon spoons** that listens to your battery status and fires a pop-up alert the exact moment your battery drops below 30%.
Add new script ***~/.hammerspoon/hs_battery.lua*** file:

```lua
-- Track whether the warning has already been triggered to avoid duplicate popups
local lowBatteryAlertTriggered = false

-- Create a battery watcher to monitor power percentage changes
local batteryWatcher = hs.battery.watcher.new(function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()

    -- Check if battery is below 30% and NOT charging
    if percentage and percentage < 30 and not isCharging then
        if not lowBatteryAlertTriggered then
            -- Display a native system alert pop-up (requires a click to dismiss)
            hs.dialog.alert(100, 100, function() end, "Battery Low!", "Your battery level has dropped to " .. string.format("%.0f", percentage) .. "%. Please connect a charger.", "OK", nil, "warning")
            
            -- Prevent the popup from reappearing until it goes back above 30% or plugs in
            lowBatteryAlertTriggered = true
        end
    else
        -- Reset the trigger if the battery is charged or plugged in
        lowBatteryAlertTriggered = false
    end
end)

-- Start monitoring the battery
batteryWatcher:start()
```

在主設定檔 ***~/.hammerspoon/init.lua*** 中是用以下方式引入此模組：

``` lua
-- 引入 hs_battery.lua 模組
require("hs_battery")
```

## 為模組增加充電上限保護功能
這裡需要特別注意一個技術限制：**Hammerspoon 本身（核心的 hs.battery 模組）只提供「讀取」電池資訊的功能，無法直接修改系統硬體狀態來「停止」充電**。
不過，可以透過外部的開源工具（例如強大的命令列工具 <a href="https://github.com/zackelia/bclm" rel="noopener" class="external-link" target="_blank"><b><u>bclm (Battery Charge Limit Max)</u></b></a> 或 <a href="https://github.com/actuallymentor/battery" rel="noopener" class="external-link" target="_blank"><b><u>battery CLI</u></b></a>），再結合 ***Hammerspoon 的 hs.task 模組****來調用它們，就能完美達到「低於 30% 彈窗、高於 85% 自動停止充電」的效果。

### 🛠️ 第一步：安裝控制充電的外部工具
最推薦且穩定的工具是 bclm（它透過修改 macOS 系統寫入暫存器來限制充電）。請開啟終端機（Terminal）並輸入以下指令安裝：
```bash
brew install bclm
```

*(注意：首次執行 bclm 需要 sudo 權限。你可以先在終端機手動測試一次：sudo bclm write 85)*

#### **因為bclm 並沒有被收錄在 Homebrew 的官方核心倉庫（Homebrew Core）中，它屬於第三方維護的套件。 \[<a href="https://github.com/zackelia/bclm" rel="noopener" class="external-link" target="_blank"><u>1</u></a>\]
必須先執行 brew tap 新增作者的第三方倉庫，才能順利下載安裝。請在終端機（Terminal）複製並執行以下這兩行指令： \[<a href="https://github.com/zackelia/bclm/blob/main/README.md" rel="noopener" class="external-link" target="_blank"><u>1</u></a>\]

```bash
brew tap zackelia/formulae
 brew trust --formula zackelia/formulae/bclm
```

checking command >
```bash
sudo bclm write 85
```

如果bclm 確實已經成功安裝，但它在執行時會卡在 **Error: Must run as root.**（必須以管理員權限執行）。
因為 Hammerspoon 在背景執行時**無法手動輸入密碼**，所以它呼叫 bclm 時會被系統拒絕。
我們可以用 macOS 內建的 sudoers 設定，幫 bclm 加上**免密碼執行的特權**。請按照以下步驟操作：

#### 🛠️ 設定免密碼執行 bclm
1. 在終端機中輸入以下指令（這會用系統內建的編輯器打開權限設定檔）：
```bash
sudo visudo
```
1. 輸入你的 Mac 開機密碼。
2. 視窗打開後，請將游標移到檔案的最底部。
3. 按一下鍵盤的 **i** 鍵進入編輯模式，然後在最下方貼上這行程式碼（注意：Intel 晶片的路徑是 /usr/local/bin/bclm）：text
```text
ALL ALL=(ALL) NOPASSWD: /usr/local/bin/bclm
```
4. 貼上後，依序按下鍵盤的 **Esc** 鍵，然後輸入 **:wq** 再按 **Enter** 儲存並離開。

#### **測試是否成功：**
現在請在終端機輸入這行指令（前面加上 sudo，但這次應該**不會**要求你輸入密碼）：
如果直接執行成功且沒有跳出 Password: 提示，就代表免密碼設定完成了！
```bash
sudo bclm write 85
```


### 📝 第二步：更新你的 Hammerspoon 程式碼
#### 💡 核心邏輯說明
1. **雙重狀態防護 (lowBatteryAlertTriggered / highBatteryActionTriggered)**：防止電量在 85% 或 29% 徘徊時，背後不斷重複執行限制腳本或瘋狂跳出彈窗。
2. **hs.battery.powerSource()**：精準判斷你目前是否有插著電源線（"AC Power"），比單純看 isCharging 更安全，能避免你在不插電使用時誤觸發腳本。
3. **hs.task**：非同步執行終端機指令，完全不會讓你的 Mac 或是 Hammerspoon 界面產生任何卡頓。
~~如果你的 bclm 安裝路徑不同（例如 Intel 晶片的 Mac 通常在 /usr/local/bin/bclm），請記得修改程式碼中的檔案路徑。

因為現在執行必須帶有 sudo 關鍵字，我們需要將 hs_battery.lua 中的 hs.task 修改為透過 sudo 來啟動。請將你的 ~/.hammerspoon/hs_battery.lua 更新為以下版本：

``` lua
-- 將變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil 

local lowBatteryAlertTriggered = false
local highBatteryActionTriggered = false

-- 建立電池監聽器
batteryWatcher = hs.battery.watcher.new(function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    ---------------------------------------------------------
    -- 狀況 A：低於 30% 且沒在充電 -> 彈窗警告
    ---------------------------------------------------------
    if percentage < 30 and not isCharging then
        if not lowBatteryAlertTriggered then
            hs.dialog.alert(100, 100, function() end, 
                "🔋 電量過低！", 
                "目前電量已降至 " .. string.format("%.0f", percentage) .. "%。請盡快接上電源。", 
                "確定", nil, "warning")
            lowBatteryAlertTriggered = true
        end
    else
        if percentage >= 30 or isCharging then
            lowBatteryAlertTriggered = false
        end
    end

    ---------------------------------------------------------
    -- 狀況 B：高於 85% 且正接上電源 -> 停止系統充電
    ---------------------------------------------------------
    if percentage >= 85 and powerSource == "AC Power" then
        if not highBatteryActionTriggered then
            -- 💡 這裡改由 /usr/bin/sudo 啟動，帶入引數 {"/usr/local/bin/bclm", "write", "85"}
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    hs.notify.new({
                        title="🔋 電池守護者", 
                        informativeText="電量已達 " .. string.format("%.0f", percentage) .. "%，已自動鎖定充電上限至 85%。"
                    }):send()
                else
                    print("BCLM 錯誤: " .. (stdErr or "未知原因"))
                end
            end, {"/usr/local/bin/bclm", "write", "85"}):start()

            highBatteryActionTriggered = true
        end
    else
        if percentage < 85 then
            highBatteryActionTriggered = false
        end
    end
end)

-- 啟動監聽器
batteryWatcher:start()

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="電池監聽器已成功啟動！"}):send()
```

儲存檔案後，記得點擊 Hammerspoon 的 **Reload Config** 重新載入設定。


![[Pasted Graphic 3.png]]


從螢幕截圖來看，右上角的時間是 16:47，電量已經來到 **87%**，並且圖標上依然顯示著「閃電」充電符號，這代表系統確實沒有成功阻止充電。
這通常是因為 **bclm 雖然被執行了，但 macOS 系統並沒有立刻切換硬體充電狀態**。在 Intel 晶片的 Mac 上，有幾個常見的原因和對應的解決辦法：

## 1. 拔掉電源線再重新插上（最常見的物理同步問題）
Intel Mac 的電源管理晶片（SMC）有時候在收到 bclm 的限制指令時，**不會主動去斷開已經在進行中的充電**。
- **解決方法：** 請將你的 Mac **電源線拔掉，等待 3 秒鐘，再重新插上**。
- 插回後，系統會重新讀取暫存器的設定，此時選單列的閃電圖標應該就會消失，並顯示「已接通電源，但未在充電」。

## 2. 測試常駐設定（Persist） ***AI建議但尚未使用驗証***
有些 Intel Mac 機型在只寫入 write 85 的情況下無法完全生效，必須強制寫入系統引導中（Persist）。
- **解決方法：** 請打開終端機（Terminal），手動執行以下這行指令，讓限制設定在系統內常駐：
```bash
sudo bclm persist
```
- 執行完後，一樣**拔掉電源線再重插**測試看看。

## 3. 檢查系統版本是否過新（如 macOS 14/15）
如先前提到，bclm 是一個比較老舊的工具。如果你的 Intel Mac 已經升級到 **macOS 14 (Sonoma) 或 macOS 15 (Sequoia)**，Apple 更改了系統底層的寫入權限，導致 bclm 即使顯示成功，實際上也無法修改硬體充電狀態。
- **檢查方法：** 點選螢幕左上角的  標誌 ->「關於這台 Mac」，確認你的 macOS 版本。
- **替代方案（如果 bclm 真的失效）：***AI建議但尚未使用驗証**
	如果確認是系統版本導致 bclm 壞掉，強烈建議改用開源且完全免費的 <a href="https://github.com/actuallymentor/battery" rel="noopener" class="external-link" target="_blank"><b><u>Battery CLI</u></b></a>。它在較新的 macOS 系統上對 Intel 晶片支援度更好。
	1. 安裝指令：brew install actuallymentor/battery/battery
	1. 它的限制充電指令更簡單：battery charging limit 85
	2. 如果你想換成這個工具，我可以立刻幫你修改 Hammerspoon 的 Lua 程式碼。
你可以先嘗試 **「拔掉電源線重插」** 與 **手動執行 sudo bclm persist**。
如果右上角的閃電圖標依然沒有消失，可更換成更新的控制工具！


## 為了完美實現 ***「拔掉電源自動解除限制（回復可充至 100%）」** 與 ***「低於 30% 時播放系統警示音」**，我們需要：
1. 使用 hs.sound.getByName("Sosumi") 來播放 macOS 經典的警示音。
2. 在核心邏輯偵測到 powerSource == "Battery Power"（拔掉電源）時，自動呼叫 bclm unpersist 或解除上限。

### 📝 請將 ~/.hammerspoon/hs_battery.lua 更新為以下內容：

```lua
-- 將監聽器變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil 

local lowBatteryAlertTriggered = false
local highBatteryActionTriggered = false
-- 新增追蹤狀態：確保拔掉電源時，解除限制的指令只執行一次
local unpersistActionTriggered = false 

---------------------------------------------------------
-- 🔍 自動偵測 bclm 的實際檔案路徑
---------------------------------------------------------
local function getBcalmPath()
    local possiblePaths = {
        "/usr/local/bin/bclm",  -- Intel Mac 預設
        "/opt/homebrew/bin/bclm" -- Apple Silicon Mac 預設
    }
    
    for _, path in ipairs(possiblePaths) do
        if hs.fs.attributes(path) then
            return path
        end
    end
    return nil
end

local bclmPath = getBcalmPath()

-- 檢查是否成功找到工具
if not bclmPath then
    hs.dialog.alert(100, 100, function() end, 
        "⚠️ 找不到 bclm 工具", 
        "Hammerspoon 無法在預設路徑中找到 bclm，自動停止充電功能將無法運作。請確保已透過 brew 安裝。", 
        "我知道了", nil, "critical")
else
    print("🔋 電池守護者：成功偵測到 bclm 路徑為 -> " .. bclmPath)
end

---------------------------------------------------------
-- 建立電池監聽器
---------------------------------------------------------
batteryWatcher = hs.battery.watcher.new(function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    ---------------------------------------------------------
    -- 狀況 A：低於 30% 且沒在充電 -> 播放警示音 + 彈窗警告
    ---------------------------------------------------------
    if percentage < 30 and not isCharging then
        if not lowBatteryAlertTriggered then
            -- 🎵 播放 macOS 內建的警示音（可改為 "Glass", "Hero", "Ping" 等）
            local sound = hs.sound.getByName("Sosumi")
            if sound then sound:play() end

            hs.dialog.alert(100, 100, function() end, 
                "🔋 電量過低！", 
                "目前電量已降至 " .. string.format("%.0f", percentage) .. "%。請盡快接上電源。", 
                "確定", nil, "warning")
            lowBatteryAlertTriggered = true
        end
    else
        if percentage >= 30 or isCharging then
            lowBatteryAlertTriggered = false
        end
    end

    ---------------------------------------------------------
    -- 狀況 B：高於 85% 且正接上電源 -> 停止系統充電
    ---------------------------------------------------------
    if percentage >= 85 and powerSource == "AC Power" and bclmPath then
        if not highBatteryActionTriggered then
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    hs.notify.new({
                        title="🔋 電池守護者", 
                        informativeText="電量已達 " .. string.format("%.0f", percentage) .. "%，已自動鎖定充電上限至 85%。"
                    }):send()
                    -- 充電鎖定成功，重設解鎖開關狀態
                    unpersistActionTriggered = false 
                else
                    print("BCLM 錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "write", "85"}):start()

            highBatteryActionTriggered = true
        end
    else
        if percentage < 85 then
            highBatteryActionTriggered = false
        end
    end

    ---------------------------------------------------------
    -- 🔌 狀況 C：拔掉電源（使用電池） -> 自動解除充電限制
    ---------------------------------------------------------
    if powerSource == "Battery Power" and bclmPath then
        if not unpersistActionTriggered then
            -- 呼叫 bclm unpersist 以恢復預設可充到 100% 的設定
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    print("🔋 電池守護者：已拔除電源，自動解除 85% 充電限制。")
                    unpersistActionTriggered = true
                    highBatteryActionTriggered = false -- 允許下次插電時重新觸發鎖定
                else
                    print("BCLM 解除限制錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "unpersist"}):start()
        end
    end
end)

-- 啟動監聽器
batteryWatcher:start()

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="電池擴充模組已成功啟動！"}):send()

```

### 🛠️ 主程式 init.lua 引入方式
請在主設定檔 ~/.hammerspoon/init.lua 中是用以下方式引入此模組：
``` lua
-- 引入 hs_battery.lua 模組
require("hs_battery")
```

#### 💡 額外微調提示
- **警示音效**：如果你想更換低電量時的聲音，可以把程式碼中的 "Sosumi" 替換成其他 macOS 系統內建音效，例如 "Blow"、"Bottle"、"Frog"、"Glass" 或 "Hero"。
- **Sudoers 權限確認**：因為新增了 unpersist 指令，請確保你在前一個步驟的 sudo visudo 裡設定的是 ALL ALL=(ALL) NOPASSWD: /usr/local/bin/bclm。這條規則允許了該路徑下的**所有**子指令（包含 write 與 unpersist）免密碼執行，因此不需重新修改系統權限檔案。
儲存後點擊 Hammerspoon 的 **Reload Config** 即可生效。你可以試著拔掉電源線，並在控制台（Console）中觀察是否有印出解除限制的日誌。
```bash
sudo visudo
```

檢查 sudo visudo ，查看設定檔語法和位置完全正確！
```text
ALL ALL=(ALL) NOPASSWD: /usr/local/bin/bclm 
```

如已經成功加在最底部，這意味著 bclm 的所有子指令（包括 write 和 unpersist）現在都可以免密碼由 Hammerspoon 調用了。
#### 這裡有一個關於 bclm 工具本身的**隱藏硬體機制**需要特別注意，它會影響到我們剛剛寫的「拔掉電源自動解除限制」功能：
#### ⚠️ 關於 bclm unpersist 的重要硬體限制
在 Intel Mac 上，bclm 的運作原理是直接去改寫主機板上 **SMC（系統管理控制器）** 的暫存器數值。
- 當執行 bclm write 85 時，數值被寫入 SMC，充電立刻停止。
- 當你拔掉電源線時，Mac 會切換到電池供電。此時即使腳本成功觸發並執行了 bclm unpersist，**SMC 裡面的暫存器數值並不會因為你拔掉電源就立刻刷新**。
- **這會導致一個現象：** 當你下次再度插上電源線時，SMC 可能還記憶著剛才的 85% 限制，導致它不會自動充到 100%。通常需要手動執行 sudo bclm write 100，或者重新開機，SMC 的硬體限制才會真正刷新回復。

### 🛠️ 最佳解決方案：將「解除限制」改為寫入 100%
為了解決這個硬體同步問題，最完美的作法是在**拔掉電源**或**電量低於 85% 且想恢復充電**時，直接對 SMC 強制寫入 write 100。
請打開你的 ***~/.hammerspoon/hs_battery.lua**，將「狀況 C」的區塊修改為以下程式碼（這樣最符合 Intel Mac 的硬體反應）：
```lua
-- 將監聽器變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil 

local lowBatteryAlertTriggered = false
local highBatteryActionTriggered = false
-- 新增追蹤狀態：確保拔掉電源時，解除限制的指令只執行一次
local unpersistActionTriggered = false 

---------------------------------------------------------
-- 🔍 自動偵測 bclm 的實際檔案路徑
---------------------------------------------------------
local function getBcalmPath()
    local possiblePaths = {
        "/usr/local/bin/bclm",  -- Intel Mac 預設
        "/opt/homebrew/bin/bclm" -- Apple Silicon Mac 預設
    }
    
    for _, path in ipairs(possiblePaths) do
        if hs.fs.attributes(path) then
            return path
        end
    end
    return nil
end

local bclmPath = getBcalmPath()

-- 檢查是否成功找到工具
if not bclmPath then
    hs.dialog.alert(100, 100, function() end, 
        "⚠️ 找不到 bclm 工具", 
        "Hammerspoon 無法在預設路徑中找到 bclm，自動停止充電功能將無法運作。請確保已透過 brew 安裝。", 
        "我知道了", nil, "critical")
else
    print("🔋 電池守護者：成功偵測到 bclm 路徑為 -> " .. bclmPath)
end

---------------------------------------------------------
-- 建立電池監聽器
---------------------------------------------------------
batteryWatcher = hs.battery.watcher.new(function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    ---------------------------------------------------------
    -- 狀況 A：低於 30% 且沒在充電 -> 播放警示音 + 彈窗警告
    ---------------------------------------------------------
    if percentage < 30 and not isCharging then
        if not lowBatteryAlertTriggered then
            -- 🎵 播放 macOS 內建的警示音
            local sound = hs.sound.getByName("Sosumi")
            if sound then sound:play() end

            hs.dialog.alert(100, 100, function() end, 
                "🔋 電量過低！", 
                "目前電量已降至 " .. string.format("%.0f", percentage) .. "%。請盡快接上電源。", 
                "確定", nil, "warning")
            lowBatteryAlertTriggered = true
        end
    else
        if percentage >= 30 or isCharging then
            lowBatteryAlertTriggered = false
        end
    end

    ---------------------------------------------------------
    -- 狀況 B：高於 85% 且正接上電源 -> 停止系統充電
    ---------------------------------------------------------
    if percentage >= 85 and powerSource == "AC Power" and bclmPath then
        if not highBatteryActionTriggered then
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    hs.notify.new({
                        title="🔋 電池守護者", 
                        informativeText="電量已達 " .. string.format("%.0f", percentage) .. "%，已自動鎖定充電上限至 85%。"
                    }):send()
                    -- 充電鎖定成功，重設解鎖開關狀態
                    unpersistActionTriggered = false 
                else
                    print("BCLM 錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "write", "85"}):start()

            highBatteryActionTriggered = true
        end
    else
        if percentage < 85 then
            highBatteryActionTriggered = false
        end
    end

    ---------------------------------------------------------
    -- 🔌 狀況 C：拔掉電源（使用電池） -> 強制回復預設 100% 充電設定
    ---------------------------------------------------------
    if powerSource == "Battery Power" and bclmPath then
        if not unpersistActionTriggered then
            -- 💡 直接寫入 100，強制重設 SMC 暫存器，確保下次插電能順利充電
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    print("🔋 電池守護者：已拔除電源，SMC 充電限制已重設回 100%。")
                    unpersistActionTriggered = true
                    highBatteryActionTriggered = false -- 允許下次插電且 >85% 時重新鎖定
                else
                    print("BCLM 重設錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "write", "100"}):start()
        end
    end
end) -- 👈 修正點：關閉第 41 行 batteryWatcher 的 function 和括號

-- 啟動監聽器
batteryWatcher:start()

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="電池擴充模組已成功啟動！"}):send()

```
1. 完整複製上面的程式碼並複寫到 hs_battery.lua 中。
2. 點擊 Hammerspoon 選單列的 **Reload Config**。
3. 這次 Console（控制台）應該就不會再噴出紅色錯誤，而是會順利彈出「電池擴充模組已成功啟動！」的橫幅通知了。

#### 🔁 修改後的整體運作流程：
1. **插著電充到 85%** ➔ 腳本執行 write 85 ➔ 停止充電，同時播放 **Sosumi** 警示音並跳出通知。
2. **拔掉電源線** ➔ 腳本立刻執行 write 100 ➔ 雖然現在沒插電，但 SMC 內部的限制已經被解除。
3. **下次帶出門用電到低於 30%** ➔ 腳本觸發低電量彈窗，提醒你插電。
4. **再度插上電源** ➔ 因為之前拔電時已經重設回 100，所以它會一路順暢地充上去，直到再次碰到 85% 才會觸發鎖定。

拔掉電源線後，可以到 Hammerspoon 的 **Console** 檢查看看是否有成功印出 🔋 電池守護者：已拔除電源，SMC 充電限制已重設回 100%。 的日誌？


![[Pasted Graphic 1 2.png]]



![[Pasted Graphic 2 2.png]]

**Mac 在「休眠（Sleep Mode）」時自動充到 100%**，確實是所有第三方充電限制工具（不論是 AlDente、bclm 還是其它工具）在 Intel Mac 上最常見的痛點。
這是因為 **Intel Mac 的硬體架構特性**所導致的：
當 Mac 進入深度休眠時，系統的作業系統（macOS）會完全暫停運作，這時 **Hammerspoon 也會跟著一起「睡著」而無法執行任何 Lua 程式碼**。此時，主機板上的 SMC（系統管理控制器）會接管電源，如果 SMC 在休眠過程中因為電力波動、微小喚醒（例如 Power Nap 檢查郵件）而重設了暫存器，Mac 就會用最原始的硬體邏輯「一路充到飽」。
這次我們使用的 bclm 搭配 hs.task 雖然是直接寫入暫存器，理論上比純軟體控制持久，但休眠時仍有被系統重設的風險。
### 🔬 為了更好觀察與應對這個狀況，建議觀察期注意以下觀察與測試重點
1. **休眠醒來後的檢查**：如果隔天醒來發現真的又被充到 100%，不要慌張。請**先拔掉電源線讓它消耗一下電量**（降到 85% 以下）。
2. **插回電源測試**：當電量低於 85% 再次插上電源時，觀察 Hammerspoon 是否會在你再度達到 85% 時發出通知並「再度攔截」充電。
3. **終端機手動檢查**：如果你懷疑 bclm 的數值被系統洗掉了，可以隨時在終端機輸入：
```bash
bclm read
```
	
它會顯示目前硬體真正限制的數字。如果顯示 100，代表休眠時被 macOS 恢復了；如果顯示 85 卻還在充電，那就是 Intel SMC 硬體卡死，需要拔插電源線。

#### 💡 最終的大絕招（如果休眠依然會充飽）
如果長時間觀察後，發現休眠偷充電的狀況依舊頻繁，最有效的根本解決辦法是**在 Mac 準備休眠的前一刻，強制寫入限制**。
Hammerspoon 有一個 hs.caffeinate.watcher 模組，專門用來監聽 Mac 的「準備休眠」與「醒來」事件。如果之後有需要，我們可以再加幾行程式碼，讓 Mac **在蓋上螢幕（systemWillSleep）的瞬間，強制再對硬體塞一次 bclm write 85 指令**，這能大大降低休眠被衝破的機率。


## 架構優化！
將控制電量的變數統一集中到 init.lua 主設定檔，而把邏輯封裝在 hs_battery.lua 模組中，能讓整體設定變得極具可維護性。
同時，加入了 **hs.caffeinate.watcher 防禦機制**：
- **當 Mac 即將進入休眠（systemWillSleep）時**：Hammerspoon 會趕在系統睡著前的一瞬間，再次強制向系統補寫一次限制（例如 85%）。
- **當 Mac 被喚醒（screensDidWake 或 systemDidWake）時**：會立即重新觸發一次檢查，防止硬體暫存器在休眠期間被系統洗掉。

加上這個****防呆機制（Fallback）** 後，即使未來你不小心刪除了 init.lua 中的設定，或者其他 Mac 想要單獨引入這個模組，腳本也不會因為找不到變數而崩潰（Crash），而是會安全地採用預設值。
在 Lua 中，我們可以使用簡潔的 *** 變數 = 全域變數 or 預設值 ** 語法來完美實現這個功能。
請直接將你的 **~/.hammerspoon/hs_battery.lua** 完整替換為以下包含防呆機制的最新版本：

#### 📝 更新後的 ~/.hammerspoon/hs_battery.lua
```lua
**-- 將監聽器變數設為全域（Global），防止被系統自動回收**
**batteryWatcher = nil** 
**sleepWatcher = nil**
**batteryTimer = nil**  

**local lowBatteryAlertTriggered = false**
**local highBatteryActionTriggered = false**
**local unpersistActionTriggered = false** 

**---------------------------------------------------------**
**-- 🛡️ 防呆機制：檢查 init.lua 是否有設定全域變數，若無則套用預設值**
**---------------------------------------------------------**
**local lowBatteryPercentage = lowBatteryPercentage or 30**
**local topBatteryPercentage = topBatteryPercentage or 85**

**print(string.format("🔋 電池守護者參數設定 -> 低電量警告: %d%%, 充電上限: %d%%", lowBatteryPercentage, topBatteryPercentage))**

**---------------------------------------------------------**
**-- 🔍 自動偵測 bclm 的實際檔案路徑**
**---------------------------------------------------------**
**local function getBcalmPath()**
    **local possiblePaths = {**
        **"/usr/local/bin/bclm",**  
        **"/opt/homebrew/bin/bclm"** 
    **}**
    **for _, path in ipairs(possiblePaths) do**
        **if hs.fs.attributes(path) then return path end**
    **end**
    **return nil**
**end**

**local bclmPath = getBcalmPath()**

**if not bclmPath then**
    **hs.dialog.alert(100, 100, function() end,** 
        **"⚠️ 找不到 bclm 工具",** 
        **"Hammerspoon 無法在預設路徑中找到 bclm，自動停止充電功能將無法運作。",** 
        **"我知道了", nil, "critical")**
**else**
    **print("🔋 電池守護者：成功偵測到 bclm 路徑為 -> " .. bclmPath)**
**end**

**---------------------------------------------------------**
**-- ⚡ 核心充電控制函式**
**---------------------------------------------------------**
**local function enforceBatteryLimits()**
    **local percentage = hs.battery.percentage()**
    **local isCharging = hs.battery.isCharging()**
    **local powerSource = hs.battery.powerSource()**

    **if not percentage then return end**

    **-- 狀況 A：低於設定值 且沒在充電 -> 播放警示音 + 彈窗警告**
    **if percentage < lowBatteryPercentage and not isCharging then**
        **if not lowBatteryAlertTriggered then**
            **local sound = hs.sound.getByName("Sosumi")**
            **if sound then sound:play() end**

            **hs.dialog.alert(100, 100, function() end,** 
                **"🔋 電量過低！",** 
                **"目前電量已降至 " .. string.format("%.0f", percentage) .. "%。請盡快接上電源。",** 
                **"確定", nil, "warning")**
            **lowBatteryAlertTriggered = true**
        **end**
    **else**
        **if percentage >= lowBatteryPercentage or isCharging then**
            **lowBatteryAlertTriggered = false**
        **end**
    **end**

    **-- 狀況 B：高於設定值 且正接上電源 -> 停止系統充電**
    **if percentage >= topBatteryPercentage and powerSource == "AC Power" and bclmPath then**
        **if not highBatteryActionTriggered then**
            **hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)**
                **if exitCode == 0 then**
                    **hs.notify.new({**
                        **title="🔋 電池守護者",** 
                        **informativeText="電量已達 " .. string.format("%.0f", percentage) .. "%，已發送鎖定充電上限指令。"**
                    **}):send()**
                    **unpersistActionTriggered = false** 
                **else**
                    **print("BCLM 錯誤: " .. (stdErr or "未知原因"))**
                **end**
            **end, {bclmPath, "write", tostring(topBatteryPercentage)}):start()**

            **highBatteryActionTriggered = true**
        **end**
    **else**
        **if percentage < topBatteryPercentage then**
            **highBatteryActionTriggered = false**
        **end**
    **end**

    **-- 狀況 C：拔掉電源（使用電池） -> 強制回復預設 100% 充電設定**
    **if powerSource == "Battery Power" and bclmPath then**
        **if not unpersistActionTriggered then**
            **hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)**
                **if exitCode == 0 then**
                    **print("🔋 電池守護者：已拔除電源，SMC 充電限制已重設回 100%。")**
                    **unpersistActionTriggered = true**
                    **highBatteryActionTriggered = false** 
                **else**
                    **print("BCLM 重設錯誤: " .. (stdErr or "未知原因"))**
                **end**
            **end, {bclmPath, "write", "100"}):start()**
        **end**
    **end**
**end**

**---------------------------------------------------------**
**-- 🕒 監聽器 1：常態電池狀態監聽**
**---------------------------------------------------------**
**batteryWatcher = hs.battery.watcher.new(enforceBatteryLimits)**
**batteryWatcher:start()**

**---------------------------------------------------------**
**-- 💤 監聽器 2：防止休眠偷充電的防禦機制**
**---------------------------------------------------------**
**sleepWatcher = hs.caffeinate.watcher.new(function(eventType)**
    **local powerSource = hs.battery.powerSource()**
    
    **if eventType == hs.caffeinate.watcher.systemWillSleep then**
        **if powerSource == "AC Power" and bclmPath then**
            **print("💤 系統即將休眠，強制鎖定 BCLM 為 " .. topBatteryPercentage .. "%...")**
            **hs.task.new("/usr/bin/sudo", nil, {bclmPath, "write", tostring(topBatteryPercentage)}):start()**
        **end**
        
    **elseif eventType == hs.caffeinate.watcher.systemDidWake or** 
           **eventType == hs.caffeinate.watcher.screensDidWake then**
        **print("☀️ 系統已喚醒，重新檢查電池狀態並修正限制...")**
        **highBatteryActionTriggered = false**
        **unpersistActionTriggered = false**
        **enforceBatteryLimits()**
    **end**
**end)**
**sleepWatcher:start()**

**---------------------------------------------------------**
**-- 🔄 防線 3：每 60 秒定時巡邏 + 硬體裝死主動人工作業提示**
**---------------------------------------------------------**
**batteryTimer = hs.timer.doEvery(60, function()**
    **local percentage = hs.battery.percentage()**
    **local isCharging = hs.battery.isCharging()**
    **local powerSource = hs.battery.powerSource()**

    **if not percentage then return end**

    **if percentage >= topBatteryPercentage and powerSource == "AC Power" then**
        **-- 1. 如果數值到了但高電量旗標沒反應，重新發送一次指令**
        **if not highBatteryActionTriggered then**
            **enforceBatteryLimits()**
        **end**
        
        **-- 2. 🚨【硬體裝死捕獲防護】🚨**
        **-- 如果目前電量已經超過上限值 2% 以上（說明 SMC 沒理會 bclm）且系統顯示還在充電**
        **if percentage >= (topBatteryPercentage + 2) and isCharging then**
            **-- 🎵 播放警示音**
            **local sound = hs.sound.getByName("Blow")**
            **if sound then sound:play() end**
            
            **-- 🗣️ 使用 macOS 系統語音對你大喊（中文）**
            **hs.speech.new():speak("電池已超出限制，請重新插拔電源線")**
            
            **-- 🚨 跳出阻斷式強烈警告彈窗**
            **hs.dialog.alert(100, 100, function() end,** 
                **"🚨 SMC 硬體充電卡死！",** 
                **"雖然限制已寫入，但系統正在強行充電（目前已達 " .. string.format("%.0f", percentage) .. "%）。\n\n請立刻【拔掉 Mac 電源線，等待3秒再插回】以強制重設硬體狀態！",** 
                **"我知道了", nil, "critical")**
                
            **-- 重置旗標，允許系統在插拔後重新套用**
            **highBatteryActionTriggered = false**
        **end**
    **end**
**end)**

**-- 啟動提示**
**hs.notify.new({title="Hammerspoon", informativeText="電池終極防禦與硬體異常巡邏模組已成功啟動！"}):send()**
```


### 💡 程式碼優化說明
- **local lowBatteryPercentage = lowBatteryPercentage or 30**：這行程式碼非常優雅。如果 init.lua 中已經先宣告了全域的 lowBatteryPercentage，Lua 就會直接沿用它；如果沒有宣告，它的值就是 nil，這時程式會自動走 or 右邊的條件，把數值設為 30。
- **啟動日誌列印**：我在模組頂端加了一行 print，當你點擊 **Reload Config** 重新載入時，你可以打開 Hammerspoon 控制台（Console），它會清楚顯示目前生效的參數到底是 init.lua 設定的值還是防呆預設值，方便你進行排錯。
- **加入「充電衝破時的語音/彈窗主動警告」**
- 既然硬體有時會裝死（寫入 90 卻繼續充），為了不讓電池在不知情的情況下被充到 100%，我們必須在腳本中加入最後一道**「主動追緝警告」**。
- 如果電量已經**超過上限值 2% 以上**（例如設定 90%，卻充到 92%），且硬體依然在充电，Hammerspoon 就會：
- **每分鐘彈出一個警告視窗**，並播放系統**語音通知**（用中文語音對你說："電池已超出限制，請重新插拔電源線"）。 強制手動把電源線拔掉再插上，逼硬體 SMC 重新同步暫存器。



### 版本全面調整邏輯：
1. **開機/重載立刻執法**：一啟動就檢查，只要有插電且電量過半，立刻先對系統塞入限制。
2. **提早 5% 預警防禦**：當電量爬升到離目標還差 5% 時，就會提前對 SMC 寫入鎖定值。

```lua
-- 將監聽器變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil 
sleepWatcher = nil
batteryTimer = nil  

local lowBatteryAlertTriggered = false
local highBatteryActionTriggered = false
local unpersistActionTriggered = false 

---------------------------------------------------------
-- 🛡️ 防呆機制：檢查 init.lua 是否有設定全域變數，若無則套用預設值
---------------------------------------------------------
local lowBatteryPercentage = lowBatteryPercentage or 30
local topBatteryPercentage = topBatteryPercentage or 85

print(string.format("🔋 電池守護者參數設定 -> 低電量警告: %d%%, 充電上限: %d%%", lowBatteryPercentage, topBatteryPercentage))

---------------------------------------------------------
-- 🔍 自動偵測 bclm 的實際檔案路徑
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

---------------------------------------------------------
-- ⚡ 核心充電控制函式
---------------------------------------------------------
local function enforceBatteryLimits()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    -- 狀況 A：低於設定值 且沒在充電 -> 播放警示音 + 彈窗警告
    if percentage < lowBatteryPercentage and not isCharging then
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

    -- 狀況 B：🚀【提早 5% 預警防禦】正接上電源且電量已達到（上限 - 5%）
    local earlyTriggerPercentage = topBatteryPercentage - 5
    if percentage >= earlyTriggerPercentage and powerSource == "AC Power" and bclmPath then
        if not highBatteryActionTriggered then
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    print(string.format("🔋 電池守護者：電量達 %d%%（已進入提早 5%% 預警區），成功寫入限制值 %d%%。", percentage, topBatteryPercentage))
                    unpersistActionTriggered = false 
                else
                    print("BCLM 錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "write", tostring(topBatteryPercentage)}):start()

            highBatteryActionTriggered = true
        end
    else
        -- 只有在電量低於預警值時，才重設觸發開關
        if percentage < earlyTriggerPercentage then
            highBatteryActionTriggered = false
        end
    end

    -- 狀況 C：拔掉電源（使用電池） -> 強制回復預設 100% 充電設定
    if powerSource == "Battery Power" and bclmPath then
        if not unpersistActionTriggered then
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    print("🔋 電池守護者：已拔除電源，SMC 充電限制已重設回 100%。")
                    unpersistActionTriggered = true
                    highBatteryActionTriggered = false 
                else
                    print("BCLM 重設錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "write", "100"}):start()
        end
    end
end

---------------------------------------------------------
-- 🕒 監聽器與定時器啟動
---------------------------------------------------------
batteryWatcher = hs.battery.watcher.new(enforceBatteryLimits)
batteryWatcher:start()

sleepWatcher = hs.caffeinate.watcher.new(function(eventType)
    local powerSource = hs.battery.powerSource()
    if eventType == hs.caffeinate.watcher.systemWillSleep then
        if powerSource == "AC Power" and bclmPath then
            hs.task.new("/usr/bin/sudo", nil, {bclmPath, "write", tostring(topBatteryPercentage)}):start()
        end
    elseif eventType == hs.caffeinate.watcher.systemDidWake or eventType == hs.caffeinate.watcher.screensDidWake then
        highBatteryActionTriggered = false
        unpersistActionTriggered = false
        enforceBatteryLimits()
    end
end)
sleepWatcher:start()

-- 每 60 秒定時巡邏 + 硬體衝破實時強烈警告
batteryTimer = hs.timer.doEvery(60, function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    if percentage >= (topBatteryPercentage - 5) and powerSource == "AC Power" then
        if not highBatteryActionTriggered then enforceBatteryLimits() end
        
        -- 🚨【硬體強制衝破極限攔截】高於目標值 2% 且還在充電
        if percentage >= (topBatteryPercentage + 2) and isCharging then
            local sound = hs.sound.getByName("Blow")
            if sound then sound:play() end
            hs.speech.new():speak("電池已超出限制，請重新插拔電源線")
            hs.dialog.alert(100, 100, function() end, 
                "🚨 SMC 硬體充電卡死！", 
                "目前已達 " .. string.format("%.0f", percentage) .. "%（上限為 " .. topBatteryPercentage .. "%）。\n\n請【拔掉 Mac 電源線，等待3秒再插回】強制重設硬體狀態！", 
                "我知道了", nil, "critical")
            highBatteryActionTriggered = false
        end
    end
end)

---------------------------------------------------------
-- 🚀【一開機/重載配置立刻強制執法】
---------------------------------------------------------
-- 只要開機時有插電，且電量已經高於「預警值」，就無條件立刻塞一次 write 指令進 SMC
local initialPowerSource = hs.battery.powerSource()
local initialPercentage = hs.battery.percentage()
if bclmPath and initialPowerSource == "AC Power" and initialPercentage and initialPercentage >= (topBatteryPercentage - 5) then
    print("🚀 偵測到開機/配置重載且已達電量範圍，立刻強制執行首次硬體鎖定...")
    hs.task.new("/usr/bin/sudo", nil, {bclmPath, "write", tostring(topBatteryPercentage)}):start()
end

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="家用終極型電池守護模組已成功啟動！"}):send()
```

1. **重載即刻鎖定**：你只要點擊 **Reload Config**，如果此時你插著電且電量大於 80%（假設上限 85%），底下會默默立刻先執行一次 bclm write 85。
2. **提前截擊**：當你平常從低電量開始充電，充到 **80%** 的瞬間，Hammerspoon 就會把 bclm 85 的指令送進主機板，給 SMC 電源晶片整整 5% 的電量時間去反應和接管，這能完美杜絕因為硬體裝死而直接衝破 85% 的悲劇。


這個優化方向非常優秀，這就是典型的**「狀態比對（Idempotency）」**設計！
如果我們每分鐘不管三七二十一都去執行 bclm write，除了會頻繁呼叫 hs.task（背後會產生 sudo 的系統進程）之外，確實也有點太過粗暴。
最完美的精緻做法，就是在每 60 秒的定時巡邏中，**先透過 bclm read 讀取目前硬體的實際限制值。只有在發現數值「不等於」你設定的目標值（例如被系統洗回 100）時，才發動 bclm write 把它壓回去**。如果數值沒變，就繼續保持安靜監控。

## 以下為精準改寫的 **「先讀後寫、防重複點火」** 的完全體 hs_battery.lua：

### 📝 請將 ~/.hammerspoon/hs_battery.lua 完整替換為以下內容：

```lua
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

print(string.format("🔋 電池守護者參數設定 -> 低電量警告: %d%%, 充電上限: %d%%", lowBatteryPercentage, topBatteryPercentage))

---------------------------------------------------------
-- 🔍 自動偵測 bclm 的實際檔案路徑
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

---------------------------------------------------------
-- ⚙️ 封裝：安全的 bclm 寫入函式
---------------------------------------------------------
local function writeBclmValue(targetValue, reason)
    if not bclmPath then return end
    hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
            print(string.format("🔋 電池守護者 \[%s\]：成功將硬體充電限制修改為 %s%%。", reason, targetValue))
        else
            print("BCLM 寫入錯誤: " .. (stdErr or "未知原因"))
        end
    end, {bclmPath, "write", tostring(targetValue)}):start()
end

---------------------------------------------------------
-- ⚡ 核心充電控制邏輯（供狀態改變與開機時呼叫）
---------------------------------------------------------
local function enforceBatteryLimits()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    -- 狀況 A：低於設定值 且沒在充電 -> 播放警示音 + 彈窗警告
    if percentage < lowBatteryPercentage and not isCharging then
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

    -- 狀況 B：【提早 10% 預警防禦】與狀況 C（拔電恢復 100%）
    -- 這裡主要處理即時的狀態切換，定時巡邏會做智慧比對
    local earlyTriggerPercentage = topBatteryPercentage - 10
    if percentage >= earlyTriggerPercentage and powerSource == "AC Power" then
        -- 先行呼叫一次，後續由定時巡邏智慧守護
        writeBclmValue(topBatteryPercentage, "電量達預警區")
    elseif powerSource == "Battery Power" then
        writeBclmValue(100, "拔除電源線")
    end
end

---------------------------------------------------------
-- 🕒 監聽器啟動
---------------------------------------------------------
batteryWatcher = hs.battery.watcher.new(enforceBatteryLimits)
batteryWatcher:start()

sleepWatcher = hs.caffeinate.watcher.new(function(eventType)
    local powerSource = hs.battery.powerSource()
    if eventType == hs.caffeinate.watcher.systemWillSleep then
        if powerSource == "AC Power" then
            writeBclmValue(topBatteryPercentage, "系統即將休眠")
        end
    elseif eventType == hs.caffeinate.watcher.systemDidWake or eventType == hs.caffeinate.watcher.screensDidWake then
        enforceBatteryLimits()
    end
end)
sleepWatcher:start()

---------------------------------------------------------
-- 🔄 🚀【智慧型 60 秒定時巡邏：先讀再寫，防重複點火】
---------------------------------------------------------
batteryTimer = hs.timer.doEvery(60, function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage or not bclmPath then return end

    -- 只有在「插著電」且「電量已達提早 10% 預警區」才需要巡邏
    if percentage >= (topBatteryPercentage - 10) and powerSource == "AC Power" then
        
        -- 🔍 第一步：先執行 bclm read 讀取目前的硬體值
        hs.task.new(bclmPath, function(exitCode, stdOut, stdErr)
            if exitCode == 0 and stdOut then
                -- 清除多餘的換行與空白，取得乾淨的數字字串 (例如 "100" 或 "85")
                local currentHardwareValue = string.gsub(stdOut, "%s+", "")
                
                -- 🔍 第二步：智慧比對！
                -- 如果硬體值被系統洗掉了（不等於我們設定的上限值），才重新寫入！
                if currentHardwareValue ~= tostring(topBatteryPercentage) then
                    print(string.format("⚠️ 偵測到硬體值異動！目前為 %s%%，與設定值 %d%% 不符，發動修正...", currentHardwareValue, topBatteryPercentage))
                    writeBclmValue(topBatteryPercentage, "定時巡邏修正")
                end
            end
        end, {"read"}):start() -- 這裡呼叫 read 不需要 sudo 權限，速度極快且不傷系統
        
        -- 🚨【硬體晶片卡死完全捕獲】高於目標值 2% 且持續顯示正在充電
        if percentage >= (topBatteryPercentage + 2) and isCharging then
            local sound = hs.sound.getByName("Blow")
            if sound then sound:play() end
            hs.speech.new():speak("電池已超出限制，請重新插拔電源線")
            hs.dialog.alert(100, 100, function() end, 
                "🚨 SMC 硬體充電卡死！", 
                "目前已達 " .. string.format("%.0f", percentage) .. "%（上限為 " .. topBatteryPercentage .. "%）。\n\n硬體暫存器值雖正確，但晶片卡死，請【拔掉 Mac 電源線，等待3秒再插回】強制重設硬體狀態！", 
                "我知道了", nil, "critical")
        end
    end
end)

---------------------------------------------------------
-- 🚀【一開機/重載配置立刻首次初始化檢查】
---------------------------------------------------------
local initialPowerSource = hs.battery.powerSource()
local initialPercentage = hs.battery.percentage()
if initialPowerSource == "AC Power" and initialPercentage and initialPercentage >= (topBatteryPercentage - 10) then
    writeBclmValue(topBatteryPercentage, "開機初始化鎖定")
end

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="電池智慧守護模組（先讀後寫版）已成功啟動！"}):send()
```

## 💎 這個智慧優化版的精妙之處：
1. **不重複點火（Idempotent）**：每 60 秒的背景任務改為呼叫 bclm read。因為讀取不需要高權限（不用 sudo），且只是讀取暫存器，對系統來說是**完全零負擔、零磨損**。
2. **異動才觸發 sudo write**：只有當 bclm read 回傳的數字被 macOS 系統悄悄洗成 100 的時候，控制台才會跳出 ⚠️ 偵測到硬體值異動！... 並且在該秒鐘執行一次 sudo bclm write 給它壓回去。如果數值一直好好的維持在你的設定值（如 85），後台將**不進行任何寫入**。
這樣一來，既維持了「霸道防線」不漏接任何系統篡改，又達到了你要求的「精準優雅，沒異動不重寫」的高級工程邏輯！
儲存後重載配置，你可以打開 **Hammerspoon Console**，應該會看到一開機或重載時，它在背景智慧巡邏的優雅日誌囉！
```lua
-- hs_battery.lua
-- 電池充電狀態監控，健康度守護模組
-- lowBatteryPercentage/topBatteryPercentage 可另外設定於引用主程式，設定不同閥值

-- 將監聽器變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil 
sleepWatcher = nil
batteryTimer = nil  

local lowBatteryAlertTriggered = false
-- 💡 新增：追蹤上一次真正成功寫入硬體的值
local lastWrittenValue = nil 

---------------------------------------------------------
-- 🛡️ 防呆機制：檢查 init.lua 是否有設定全域變數，若無則套用預設值
---------------------------------------------------------
local lowBatteryPercentage = lowBatteryPercentage or 30
local topBatteryPercentage = topBatteryPercentage or 85

print(string.format("🔋 電池守護者參數設定 -> 低電量警告: %d%%, 充電上限: %d%%", lowBatteryPercentage, topBatteryPercentage))

---------------------------------------------------------
-- 🔍 自動偵測 bclm 的實際檔案路徑
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

---------------------------------------------------------
-- ⚙️ 封裝：智慧型 bclm 寫入函式（即時讀取硬體值比對，防重複寫入）
---------------------------------------------------------
local function writeBclmValue(targetValue, reason)
    if not bclmPath then return end
    
    -- 🔍 第一步：先非同步讀取目前 SMC 硬體內真正的限制值（免 sudo，速度極快）
    hs.task.new(bclmPath, function(readExitCode, readStdOut, readStdErr)
        if readExitCode == 0 and readStdOut then
            -- 清除多餘的換行與空白，取得乾淨的硬體現值
            local currentHardwareValue = string.gsub(readStdOut, "%s+", "")
            
            -- 💡 第二步：即時智慧比對！
            -- 如果目前硬體值已經等於目標值，直接攔截不重寫，避免重複點火
            if currentHardwareValue == tostring(targetValue) then
                -- print(string.format("ℹ️ 電池守護者 \[%s\]：硬體值已是 %s%%，無需重複寫入。", reason, targetValue))
                return 
            end
            
            -- 💡 第三步：數值有異動，才真正發動寫入
            hs.task.new("/usr/bin/sudo", function(writeExitCode, writeStdOut, writeStdErr)
                if writeExitCode == 0 then
                    print(string.format("🔋 電池守護者 \[%s\]：偵測到異動（原為 %s%%），已成功將硬體充電限制修改為 %s%%。", reason, currentHardwareValue, targetValue))
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
-- ⚡ 核心充電控制邏輯
---------------------------------------------------------
local function enforceBatteryLimits()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    -- 狀況 A：低於設定值 且沒在充電 -> 播放警示音 + 彈窗警告
    if percentage < lowBatteryPercentage and not isCharging then
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

    -- 狀況 B：【提早 10% 預警防禦】與狀況 C（拔電恢復 100%）
    local earlyTriggerPercentage = topBatteryPercentage - 10
    if percentage >= earlyTriggerPercentage and powerSource == "AC Power" then
        writeBclmValue(topBatteryPercentage, "電量達預警區")
    --elseif powerSource == "Battery Power" then
    --    writeBclmValue(100, "拔除電源線")
    end
end

---------------------------------------------------------
-- 🕒 監聽器啟動
---------------------------------------------------------
batteryWatcher = hs.battery.watcher.new(enforceBatteryLimits)
batteryWatcher:start()

sleepWatcher = hs.caffeinate.watcher.new(function(eventType)
    local powerSource = hs.battery.powerSource()
    if eventType == hs.caffeinate.watcher.systemWillSleep then
        if powerSource == "AC Power" then
            lastWrittenValue = nil -- 休眠前清除緩存，強制允許寫入一次
            writeBclmValue(topBatteryPercentage, "系統即將休眠")
        end
    elseif eventType == hs.caffeinate.watcher.systemDidWake or eventType == hs.caffeinate.watcher.screensDidWake then
        lastWrittenValue = nil -- 喚醒時清除緩存，強制重新檢查
        enforceBatteryLimits()
    end
end)
sleepWatcher:start()

---------------------------------------------------------
-- 🔄 🚀【智慧型 60 秒定時巡邏：先讀再寫，雙重保險】
---------------------------------------------------------
batteryTimer = hs.timer.doEvery(60, function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage or not bclmPath then return end

    if percentage >= (topBatteryPercentage - 10) and powerSource == "AC Power" then
        
        -- 🔍 第一步：先執行 bclm read 讀取目前的實際硬體值
        hs.task.new(bclmPath, function(exitCode, stdOut, stdErr)
            if exitCode == 0 and stdOut then
                local currentHardwareValue = string.gsub(stdOut, "%s+", "")
                
                -- 🔍 第二步：智慧比對！如果發現硬體值跟設定的上限不同
                if currentHardwareValue ~= tostring(topBatteryPercentage) then
                    print(string.format("⚠️ 偵測到硬體值異動！目前為 %s%%，與設定值 %d%% 不符，發動修正...", currentHardwareValue, topBatteryPercentage))
                    lastWrittenValue = nil -- 清除鎖，允許定時器修正
                    writeBclmValue(topBatteryPercentage, "定時巡邏修正")
                end
            end
        end, {"read"}):start()
        
        -- 🚨【硬體晶片卡死完全捕獲】高於目標值 3% 且持續顯示正在充電
        if percentage >= (topBatteryPercentage + 3) and isCharging then
            local sound = hs.sound.getByName("Blow")
            if sound then sound:play() end
            hs.speech.new():speak("電池已超出限制，請重新插拔電源線")
            hs.dialog.alert(100, 100, function() end, 
                "🚨 SMC 硬體充電卡死！", 
                "目前已達 " .. string.format("%.0f", percentage) .. "%（上限為 " .. topBatteryPercentage .. "%）。\n\n硬體暫存器值雖正確，但晶片卡死，請【拔掉 Mac 電源線，等待3秒再插回】強制重設硬體狀態！", 
                "我知道了", nil, "critical")
        end
    end
end)

---------------------------------------------------------
-- 🚀【一開機/重載配置立刻首次初始化檢查】
---------------------------------------------------------
local initialPowerSource = hs.battery.powerSource()
local initialPercentage = hs.battery.percentage()
if initialPowerSource == "AC Power" and initialPercentage and initialPercentage >= (topBatteryPercentage - 10) then
    writeBclmValue(topBatteryPercentage, "開機初始化鎖定")
end

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="電池智慧守護模組已成功啟動！"}):send()
```