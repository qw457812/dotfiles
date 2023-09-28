set number
" set relativenumber

" :h 'clipboard'
" On Mac OS X and Windows, the * and + registers both point to the system clipboard so unnamed and unnamedplus have the same effect: the unnamed register is synchronized with the system clipboard. | https://stackoverflow.com/questions/30691466/what-is-difference-between-vims-clipboard-unnamed-and-unnamedplus-settings
" 寄存器 ["*] 和寄存器 [""] 保持同步（即共享剪切板）
set clipboard=unnamed

" https://github.com/wsdjeg/Learn-Vim_zh_cn/blob/master/ch05_moving_in_file.md
" nnoremap <esc><esc> :noh<return><esc>
" nnoremap <esc> :noh<return><esc>

nnoremap Y y$
map H ^
map L $

inoremap jj <esc>
inoremap jk <esc>
inoremap kj <esc>

nmap <leader>q :q<cr>
nmap <leader>Q :q!<cr>
