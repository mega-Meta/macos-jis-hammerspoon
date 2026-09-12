-- below function show info. when debug_flag is ON
-- Create a key logger to show keycodes and modifiers
keyLogger = hs.eventtap
   .new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	-- Format and print the key details to the Hammerspoon Console
	--if DEBUG_FLAG then
	   print(string.format("Key Code: %s | Modifiers: %s", keyCode, hs.inspect(flags)))
    --end
	return false -- Return false so the key press still reaches the OS/apps
end)
:start()

--[[
 --Show application system ID on console when Debug_flag is ON
 1.點擊畫面右上角選單列的 Hammerspoon 圖示，選擇 「Open Console」（打開主控台）。
 2.在主控台最下方的輸入框中，複製並貼上以下這行程式碼，然後按下 Enter 鍵執行：
 testWatcher = hs.application.watcher.new(function(name, event, app) if event == hs.application.watcher.activated and app then print("App名稱: " .. name .. " | BundleID: " .. tostring(app:bundleID())) end end):start()
 3.執行後，你可以直接用滑鼠去點擊你想查詢的 App（例如微信、Discord 或備忘錄）。這時 Hammerspoon 主控台就會立刻即時印出該 App 的準確 ID，例如：App名稱: 備忘錄 | BundleID: com.apple.NotesApp名稱: WeChat | BundleID: com.tencent.xinWeChat
 4.關閉偵測：查詢完畢後，在主控台輸入 testWatcher:stop() 即可關閉這個臨時偵測器。
]]
--
testWatcher = hs.application.watcher.new(function(name, event, app)
   if event == hs.application.watcher.activated and app then --and DEBUG_FLAG then
      print("App名稱: " .. name .. " | BundleID: " .. tostring(app:bundleID()))
   end
end)
:start()
hs.alert.show("Hammerspoon debug mode已啟動")