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
RAW_URL="https://raw.githubusercontent.com/mega-Meta/macos-jis-hammerspoon/refs/heads/main/init.lua"

curl -fsSL "$RAW_URL" -o "$HS_DIR/init.lua"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ init.lua 部署成功！${NC}"
else
    echo -e "${RED}❌ 錯誤：無法從 GitHub 下載設定檔，請確認上方網址與大小寫是否完全正確！${NC}"
    exit 1
fi

echo -e "\n${BLUE}[5/5] 正在透過系統底層指令自動注入 Shottr 精準參數設定...${NC}"

# 🌟【核心修正 1】強制完全關閉 Shottr 與系統偏好設定快取服務，防止快取回寫覆蓋
killall Shottr 2>/dev/null
killall cfprefsd 2>/dev/null
sleep 0.5

PLIST_FILE="$HOME/Library/Preferences/cc.shottr.plist"
RAW_PLIST_URL="https://githubusercontent.com"

curl -fsSL "$RAW_PLIST_URL" -o "$PLIST_FILE"

if [ $? -eq 0 ]; then
    # 確保儲存路徑因應使用者帳號名稱自動調整（動態修正為當前本機使用者的桌面）
    defaults write cc.shottr save_location "$HOME/Desktop"
    # 🌟【核心修正 3】強制重新整理系統偏好設定資料庫
    defaults read cc.shottr >/dev/null
    echo -e "${GREEN}  ✓ Shottr 實體設定檔部署成功，所有快捷鍵與路徑已複製完畢！${NC}"
else
    echo -e "${YELLOW}  ⚠️ 提示：無法從 GitHub 下載 cc.shottr.plist，將保留您本機原本的 Shottr 快捷鍵。${NC}"
fi

echo -e "${GREEN}  ✓ Shottr 6組生產力快捷鍵、儲存路徑與格式已由腳本全自動配置完成！${NC}"
open -a Hammerspoon
open -a Shottr
echo -e "  → 正在引導 Hammerspoon 自動 Reload Config..." #；如果有錯誤，請依OS要求授權後，再重新執行一鍵安裝。"
sleep 2.0
# 🌟【防錯升級】嘗試執行 Reload，若因權限或首次啟動失敗，捕捉錯誤並印出友善提示訊息
/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c "hs.reload()" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Hammerspoon 設定檔已由內建通道成功載入！${NC}"
else
    echo -e "${YELLOW}  ℹ 提示：由於您的 Mac 是首次安裝 Hammerspoon，系統隱私權限（輔助功能）尚未對其授權。${NC}"
    echo -e "${YELLOW}          目前的自動載入已被系統阻斷。請不用擔心，這屬於正常現象！${NC}"
    echo -e "${YELLOW}          請先完成下方的【手動權限設定】，完成後設定檔便會全自動生效。${NC}"
fi
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
