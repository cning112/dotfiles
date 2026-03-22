
" 加载通用配置文件
if filereadable(expand("~/.common_vimrc"))
    source ~/.common_vimrc
endif

" Vim-specific UI and clipboard behavior
set background=dark
syntax on
colorscheme desert
set clipboard=unnamedplus

" 使用 vim-plug 管理插件
" run :PlugInstall
call plug#begin('~/.vim/plugged')
" 安装 surround 插件
Plug 'tpope/vim-surround'
" 安装 easymotion 插件
Plug 'easymotion/vim-easymotion'
call plug#end()


" EasyMotion: override / with two-char search (requires vim-easymotion installed)
" Run :PlugInstall first — without it, / will be a no-op
if exists('g:loaded_easymotion')
    map  / <Plug>(easymotion-sn)
    omap / <Plug>(easymotion-tn)
    "map  n <Plug>(easymotion-next)
    "map  N <Plug>(easymotion-prev)
endif
