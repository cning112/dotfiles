#!/bin/bash

# 函数：检查并安装 Homebrew
check_and_install_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Installing Homebrew..."
    
    # 安装 Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # 检查安装是否成功
    if ! command -v brew >/dev/null 2>&1; then
      echo "Failed to install Homebrew. Please install it manually."
      exit 1
    fi
    
    echo "Homebrew installed successfully."
  else
    echo "Homebrew is already installed."
    echo -n "Do you want to update Homebrew to the latest version? (y/n, default is n): "
    read -t 10 choice
    choice=${choice:-n}
    
    if [[ $choice == "y" || $choice == "Y" ]]; then
      echo "Updating Homebrew to the latest version..."
      brew update
      echo "Homebrew updated successfully."
    else
      echo "Homebrew update ignored."
    fi
  fi
}


# 函数：设置 Homebrew 环境变量
setup_homebrew_env() {
    if [ "$(uname)" = "Linux" ]; then
        if [ -d "/home/linuxbrew/.linuxbrew" ]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        elif [ -d "$HOME/.linuxbrew" ]; then
            eval "$($HOME/.linuxbrew/bin/brew shellenv)"
        else
            echo "Homebrew is not installed in the expected directories."
            exit 1
        fi
    elif [ "$(uname)" = "Darwin" ]; then
        if [ -d "/usr/local/bin" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        if [ -d "/opt/homebrew/bin" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
}

# 主脚本逻辑
main() {
  # 检查并安装 Homebrew
  check_and_install_homebrew

  # 设置 Homebrew 环境变量
  setup_homebrew_env
}

# 执行主脚本逻辑
main

