#!/bin/bash

# 确保 Homebrew 环境变量已设置
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed or not configured properly. Please run the Homebrew installation script first."
  exit 1
fi

# 函数：检查并安装应用程序
install_app() {
  local app_name=$1

  # 检查应用程序是否已安装
  if brew list --formula | grep -Fxq "$app_name" || brew list --cask | grep -Fxq "$app_name"; then
    echo "$app_name is already installed."
  else
    # 尝试通过 Homebrew 安装应用程序
    if brew info --formula "$app_name" >/dev/null 2>&1; then
      echo "Installing $app_name using brew..."
      brew install "$app_name"
    elif brew info --cask "$app_name" >/dev/null 2>&1; then
      echo "Installing $app_name using brew cask..."
      brew install --cask "$app_name"
    else
      echo "$app_name is not available via brew or brew cask."
    fi
  fi
}

# 主脚本逻辑
main() {
  local file_path=$1

  if [ -z "$file_path" ]; then
    echo "Usage: $0 <path_to_apps.txt>"
    exit 1
  fi

  if [ ! -f "$file_path" ]; then
    echo "File $file_path not found."
    exit 1
  fi

  while IFS= read -r app_name; do
    # 跳过空行和以 # 开头的行
    [[ -z "$app_name" || "$app_name" =~ ^# ]] && continue
    install_app "$app_name"
  done < "$file_path"
}

# 执行主脚本逻辑
main "$@"

