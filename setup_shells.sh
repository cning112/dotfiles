#!/bin/bash

# 确保 Homebrew 环境变量已设置
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed or not configured properly. Please run the Homebrew installation script first."
  exit 1
fi

# 获取 Homebrew 安装的前缀路径
brew_prefix=$(brew --prefix)

# 函数：设置默认系统 Shell
set_default_shell() {
  local shell_path=$1

  # 检查 Shell 路径是否已经在 /etc/shells 中
  if ! grep -Fxq "$shell_path" /etc/shells; then
    echo "Adding $shell_path to /etc/shells..."
    echo "$shell_path" | sudo tee -a /etc/shells
  else
    echo "$shell_path is already in /etc/shells"
  fi

  # 将 Shell 设置为默认 Shell
  if [ "$SHELL" != "$shell_path" ]; then
    echo "Changing default shell to $shell_path..."
    chsh -s "$shell_path"
    echo "Default shell changed to $shell_path. Please restart your terminal session."
  fi
}

# 通用函数：检查并安装指定的 Shell
check_and_install_shell() {
  local shell_name=$1
  local brew_package=$2
  local set_as_default=""

  # 解析参数以检查是否包含 --set_default
  shift 2
  while (( "$#" )); do
    case "$1" in
      --set_default)
        set_as_default="true"
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  local brew_path="$brew_prefix/bin/$shell_name"
  local current_shell_path

  # 检查系统是否已安装指定的 Shell
  if command -v $shell_name >/dev/null 2>&1; then
    current_shell_path=$(command -v $shell_name)
    current_version=$($shell_name --version | head -n 1)
    latest_version=$(brew info $brew_package | grep -Eo 'stable [0-9.]+' | awk '{print $2}')

    echo "Current $shell_name version: $current_version"
    echo "Path: $current_shell_path"
    echo "Latest $shell_name version available via Homebrew: $latest_version"

    # 提示用户是否希望更新到最新版本
    echo -n "Do you want to update to the latest $shell_name version? (y/n, default is n): "
    read -t 10 choice
    choice=${choice:-n}

    if [[ $choice == "y" || $choice == "Y" ]]; then
      echo "Updating $shell_name to the latest version..."
      brew upgrade $brew_package
      echo "$shell_name updated to the latest version."
      if [ -n "$set_as_default" ]; then
        set_default_shell "$brew_path"
      fi
    else
      echo "$shell_name update ignored."
      if [ -n "$set_as_default" ]; then
        set_default_shell "$current_shell_path"
      fi
    fi
  else
    echo "$shell_name is not installed. Installing $shell_name using Homebrew..."
    brew install $brew_package
    echo "$shell_name installed successfully via Homebrew."
    if [ -n "$set_as_default" ]; then
      set_default_shell "$brew_path"
    fi
  fi
}


# 主脚本逻辑
main() {
  # 检查并安装 Bash，不设置为默认 Shell
  check_and_install_shell "bash" "bash"

  # 检查并安装 Zsh，并设置为默认 Shell
  check_and_install_shell "zsh" "zsh" --set_default
}

# 执行主脚本逻辑
main

