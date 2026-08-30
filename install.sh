#!/bin/bash

# ========================================================================
# macOS JIS 鍵盤極速流 - 小白一鍵自動安裝與環境部署腳本
# ========================================================================

# 設定字體顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0;3m' # 無顏色
BOLD='\033[1m'

# 填寫您的 GitHub 使用者名稱與倉庫名稱（請務必修改此處）
GITHUB_USER="您的GitHub帳號"
GITHUB_REPO="您的倉庫名稱"

echo -e "${BLUE}${BOLD}========================================================"
echo -e "      macOS JIS 鍵盤極速流 - 環境自動化安裝程式"
echo -e "========================================================${NC}\n"

# 1. 檢查作業系統環境
echo -e "${BLUE}[1/5] 正在檢查本機作業系統...${NC}"
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ 錯誤：此腳本僅支援 macOS 系統！${NC}"
    exit 1
else
    echo -e "${GREEN}  ✓ 偵測為 macOS 系統，通過。${NC}"
fi

# 2. 檢查並安裝 Homebrew
echo -e "\n${BLUE}[2/5] 正在檢查套件管理工具 Homebrew...${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}  ℹ 偵測到本機未安裝 Homebrew，正在引導安裝...${NC}"
    echo -e "${YELLOW}  (期間可能會要求您輸入 Mac 的開機密碼，輸入時畫面不會顯示密碼，請盲打後按 Enter)${NC}"
    /bin/bash -c "$(curl -fsSL https://githubusercontent.com)"
    
    # 針對 Apple Silicon (M1/M2/M3) 晶片 Mac 的環境變數設定
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}  ✓ Homebrew 已存在，跳過安裝。${NC}"
fi

# 3. 安裝 必要應用程式 (Hammerspoon & Shottr)
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

# 4. 部署設定檔
echo -e "\n${BLUE}[4/5] 正在建立目錄並部署您的設定檔...${NC}"
HS_DIR="$HOME/.hammerspoon"

if [ ! -d "$HS_DIR" ]; then
    mkdir -p "$HS_DIR"
    echo -e "  已建立目錄：$HS_DIR"
fi

echo -e "  → 正在從您的 GitHub 下載最新的 init.lua 設定檔..."
RAW_URL="https://githubusercontent.com{GITHUB_USER}/${GITHUB_REPO}/main/init.lua"

# 下載最新的設定檔
curl -fsSL "$RAW_URL" -o "$HS_DIR/init.lua"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ init.lua 部署成功！${NC}"
else
    echo -e "${RED}❌ 錯誤：無法從 GitHub 下載設定檔，請檢查帳號與倉庫名稱是否正確！${NC}"
    exit 1
fi

# 5. 引導系統設定與權限啟用
echo -e "\n${BLUE}[5/5] 正在配置開機自動啟動並引導權限設定...${NC}"

# 強制讓 Hammerspoon 啟動以利註冊系統權限
open -a Hammerspoon
open -a Shottr

echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 一鍵自動安裝完成！請配合進行最後的 macOS 手動權限設定：${NC}"
echo -e "${GREEN}========================================================${NC}"
echo -e "${BOLD}1. 允許系統輔助功能：${NC}"
echo -e "   請前往 ${YELLOW}「系統設定」 → 「隱私權與安全性」 → 「輔助功能」${NC}，"
echo -e "   將 ${BLUE}Hammerspoon${NC} 與 ${BLUE}Shottr${NC} 的開關【開啟】（若已開啟，請關閉再重新開啟一次以重置權限）。"
echo -e "\n${BOLD}2. 允許螢幕錄製：${NC}"
echo -e "   請前往 ${YELLOW}「系統設定」 → 「隱私權與安全性」 → 「螢幕錄製」${NC}，將 ${BLUE}Shottr${NC} 【開啟】。"
echo -e "\n${BOLD}3. 根治系統存檔框卡死 Bug：${NC}"
echo -e "   請前往 ${YELLOW}「系統設定」 → 「鍵盤」 → 「輸入來源（點編輯）」${NC}，"
echo -e "   ${RED}【關閉（不要勾選）】「自動切換到文件的輸入來源」${NC}。"
echo -e "\n${BOLD}4. 核對輸入法快捷鍵：${NC}"
echo -e "   請前往 ${YELLOW}「系統設定」 → 「鍵盤」 → 「鍵盤快捷鍵...」 → 「輸入來源」${NC}，"
echo -e "   確保 ${BLUE}「選取下一個輸入來源」${NC} 為 ${YELLOW}Control + Space (^空間)${NC}。\n"
echo -e "${GREEN}設定完成後，雙擊「英數」鍵即可瞬間喚出剪貼簿與常用字模糊搜尋選單！${NC}"

