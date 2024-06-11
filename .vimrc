
" 加载通用配置文件
source ~/.common_vimrc

" 使用 vim-plug 管理插件
call plug#begin('~/.vim/plugged')

" 安装 surround 插件
Plug 'tpope/vim-surround'

" 安装 easymotion 插件
Plug 'easymotion/vim-easymotion'

call plug#end()
