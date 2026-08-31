#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}========================================================"
echo -e "      macOS JIS 鍵盤極速流 - 環境自動化安裝程式"
echo -e "========================================================${NC}\n"
echo -e "${BLUE}[1/5] 正在檢查本機作業系統...${NC}"
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ 錯誤：此腳本僅支援 macOS 系統！${NC}"
    exit 1
else
    echo -e "${GREEN}  ✓ 偵測為 macOS 系統，通過。${NC}"
fi
echo -e "\n${BLUE}[2/5] 正在檢查套件管理工具 Homebrew...${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}  ℹ 偵測到本機未安裝 Homebrew，正在引導安裝...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}  ✓ Homebrew 已存在，跳過安裝。${NC}"
fi
echo -e "\n${BLUE}[3/5] 正在檢查並透過 Homebrew 安裝必要程式...${NC}"
if [ ! -d "/Applications/Hammerspoon.app" ]; then
    echo -e "${YELLOW}  → 正在安裝 Hammerspoon...${NC}"
    brew install --cask hammerspoon
else
    echo -e "${GREEN}  ✓ Hammerspoon 已經安裝。${NC}"
fi
if [ ! -d "/Applications/Shottr.app" ]; then
    echo -e "${YELLOW}  → 正在安裝 Shottr...${NC}"
    brew install --cask shottr
else
    echo -e "${GREEN}  ✓ Shottr 已經安裝。${NC}"
fi
echo -e "\n${BLUE}[4/5] 正在建立目錄並部署您的設定檔...${NC}"
HS_DIR="$HOME/.hammerspoon"
if [ ! -d "$HS_DIR" ]; then
    mkdir -p "$HS_DIR"
fi
echo -e "  → 正在從您的 GitHub 下載最新的 init.lua 設定檔..."

# 🌟【請直接在此處修改】將下方網址，完整替換成您 GitHub 倉庫中 init.lua 的真實 Raw 網址。
# 注意：請確認大小寫是否 100% 與 GitHub 網頁上一致！
RAW_URL="https://github.com/mega-Meta/macos-jis-hammerspoon"

curl -fsSL "$RAW_URL" -o "$HS_DIR/init.lua"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ init.lua 部署成功！${NC}"
else
    echo -e "${RED}❌ 錯誤：無法從 GitHub 下載設定檔，請確認上方網址與大小寫是否完全正確！${NC}"
    exit 1
fi

echo -e "\n${BLUE}[5/5] 正在透過系統底層指令自動注入 Shottr 精準參數設定...${NC}"

# 強制讓系統重新載入 Shottr 的最新偏好設定
killall Shottr 2>/dev/null

# 1. 作用中視窗截圖 -> ⌘⇧1 (Cmd+Shift+1)
defaults write cc.shottr hotkey_window -dict key 18 modifiers 768

# 2. 滾動長截圖 -> ⌘⇧2 (Cmd+Shift+2)
defaults write cc.shottr hotkey_scrolling -dict key 19 modifiers 768

# 3. 全螢幕截圖 -> ⌘⇧3 (Cmd+Shift+3)
defaults write cc.shottr hotkey_fullscreen -dict key 20 modifiers 768

# 4. 區域範圍截圖 -> ⌘⇧4 (Cmd+Shift+4)
defaults write cc.shottr hotkey_area -dict key 21 modifiers 768

# 5. 重複上一次區域截圖 -> ⌘⇧7 (Cmd+Shift+7)
defaults write cc.shottr hotkey_repeat -dict key 26 modifiers 768

# 6. 開啟 App 歷史預覽視窗 -> ⌘⇧8 (Cmd+Shift+8)
defaults write cc.shottr hotkey_show -dict key 28 modifiers 768

# 修改預設截圖儲存路徑為「下載」
defaults write cc.shottr save_location "$HOME/Desktop"

# 修改預設儲存格式為 JPEG (省空間) 或 PNG (高清)
defaults write cc.shottr save_format "PNG"

# 開啟防抖：如果跟 MOS 等滑鼠平滑滾動軟體衝突，直接 Shell 開啟「反轉滾動長截圖方向」
defaults write cc.shottr reverse_scrolling -bool true

echo -e "${GREEN}  ✓ Shottr 6組生產力快捷鍵、儲存路徑與格式已由腳本全自動配置完成！${NC}"
open -a Hammerspoon
open -a Shottr
echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 一鍵自動安裝完成！請配合進行最後的 macOS 手動權限設定：${NC}"
echo -e "========================================================${NC}"
echo -e "${BOLD}1. 允許系統輔助功能：${NC}"
echo -e "   請前往 「系統設定」 → 「隱私權與安全性」 → 「輔助功能」，"
echo -e "   將 Hammerspoon 與 Shottr 的開關【開啟】（若已開啟，請重啟一次）。"
echo -e "\n${BOLD}2. 允許螢幕錄製：${NC}"
echo -e "   請前往 「系統設定」 → 「隱私權與安全性」 → 「螢幕錄製」，將 Shottr 【開啟】。"
echo -e "\n${BOLD}3. 根治系統存檔框卡死 Bug：${NC}"
echo -e "   請前往 「系統設定」 → 「鍵盤」 → 「輸入來源（點編輯）」，"
echo -e "   【關閉（不要勾選）】「自動切換到文件的輸入來源」。"
echo -e "\n${BOLD}4. 核對輸入法快捷鍵：${NC}"
echo -e "   請前往 「系統設定」 → 「鍵盤」 → 「鍵盤快捷鍵...」 → 「輸入來源」，"
echo -e "   確保 「選取下一個輸入來源」 為 Control + Space (^空間)。\n"
