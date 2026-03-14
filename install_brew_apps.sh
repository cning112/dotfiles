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

# Install apps from a file
install_from_file() {
  local file_path=$1

  if [ ! -f "$file_path" ]; then
    echo "File $file_path not found."
    return 1
  fi

  while IFS= read -r app_name; do
    # Skip blank lines and comments
    [[ -z "$app_name" || "$app_name" =~ ^# ]] && continue
    install_app "$app_name"
  done < "$file_path"
}

# Main
main() {
  local file_path=${1:-"$(dirname "$0")/brew-apps.txt"}

  if [ -z "$1" ]; then
    echo "No file specified, using default: $file_path"
  fi

  install_from_file "$file_path"

  # On macOS, also install macOS-specific apps
  if [ "$(uname)" = "Darwin" ] && [ -z "$1" ]; then
    local macos_file="$(dirname "$0")/brew-apps-macos.txt"
    if [ -f "$macos_file" ]; then
      echo ""
      echo "Installing macOS-specific apps..."
      install_from_file "$macos_file"
    fi
  fi
}

main "$@"

