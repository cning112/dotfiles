# 加载系统范围的配置文件
if [ -f /etc/profile ]; then
    . /etc/profile
fi

# 加载用户的 .bashrc
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

