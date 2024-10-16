" To link the Obsidian vault to this Vimrc file location:
"   ln -s -f ~/.obsidian.vimrc ~/Documents/Obsidian\ Vault

" Have j and k navigate visual lines rather than logical ones
nmap j gj
nmap k gk
" I like using H and L for beginning/end of line
nmap H ^
nmap L $
" Quickly remove search highlights
" nmap <F9> :nohl

" Yank to system clipboard
set clipboard=unnamed

" Go back and forward with Ctrl+O and Ctrl+I
" (make sure to remove default Obsidian shortcuts for these to work)
" exmap back obcommand app:go-back
" nmap <C-o> :back
" exmap forward obcommand app:go-forward
" nmap <C-i> :forward

" ---

" Emulate Tab Switching https://vimhelp.org/tabpage.txt.html#gt
" requires Cycle Through Panes Plugins https://obsidian.md/plugins?id=cycle-through-panes
" exmap tabnext obcommand cycle-through-panes:cycle-through-panes
" nmap gt :tabnext
" exmap tabprev obcommand cycle-through-panes:cycle-through-panes-reverse
" nmap gT :tabprev

" ---

" https://github.com/esm7/obsidian-vimrc-support/issues/18
imap jj <Esc>
nmap Y y$
vmap H ^
vmap L $

" TODO https://github.com/chrisgrieser/.config/blob/main/obsidian/vimrc/obsidian-vimrc.vim
