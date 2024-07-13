
" 加载通用配置文件
if filereadable(expand("~/.common_vimrc"))
    source ~/.common_vimrc
endif

" 使用 vim-plug 管理插件
" run :PlugInstall
call plug#begin('~/.vim/plugged')
" 安装 surround 插件
Plug 'tpope/vim-surround'
" 安装 easymotion 插件
Plug 'easymotion/vim-easymotion'
call plug#end()


" EasyMotion 配置
map  / <Plug>(easymotion-sn)
omap / <Plug>(easymotion-tn)

" Map n (next instance) and N (prev instance) for easymotion usage ONLY
"map  n <Plug>(easymotion-next)
"map  N <Plug>(easymotion-prev)
