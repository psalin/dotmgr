if ! empty(glob('~/.vim/autoload/plug.vim'))
    source ~/.dotfiles/.vimrc.plugins
endif

"========== General ==========
"
" Syntax color
syntax on

" Colorscheme for the syntax
"   - ron works well with GNOME Terminal color profile Nord/Nord Solarized.
"   - nord needs to be pluged inside plugin section.
colorscheme ron

" Column limit highlight
set colorcolumn=81
highlight ColorColumn ctermbg=darkgray

" Put color on trailing whitespaces and tabs
highlight ExtraWhitespace ctermbg=red guibg=red
au ColorScheme * highlight ExtraWhitespace guibg=red
au BufEnter * match ExtraWhitespace /\s\+$\|\t/
au InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$\|\t/
au InsertLeave * match ExtraWhiteSpace /\s\+$\|\t/

" Highlight search results
set hlsearch
highlight Search ctermbg=Red ctermfg=Yellow

" Find dinamically as we type search term
set incsearch

" Ignore case when searching, unless a capital character is used
set ignorecase
set smartcase

" Show line numbers
set number

" Show file name as window title
set title

" Set old window title to emtpy, so the text 'Thanks for flying vim' will
" not be shown as the title of the terminal
set titleold=

" Uses 4 spaces (instead of tab) as indentation
set expandtab
set tabstop=4
set softtabstop=0
set shiftwidth=4

" Open vertical split on the right
set splitright

" Open horizontal splot on the bottom
set splitbelow

" Use two spaces for YAML indentation
au FileType yaml setlocal tabstop=2 expandtab shiftwidth=2 softtabstop=2

" Detect .md extension as markdown filetype
autocmd BufRead,BufNewFile *.md set filetype=markdown

" Jump to the last position when reopening a file
if has("autocmd")
    au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif


"========== Key Remaps ==========
"
" Remap caps lock key to ctrl key
"- maps caps lock key to ctrl key when entering vim
"- remove mapping when exiting vim
au VimEnter * silent !setxkbmap -option ctrl:nocaps
au VimLeave * silent !setxkbmap -option

" Esc remap
" Ctrl-C does not trigger InsertLeave autocmd. We need to remap Ctrl-C to Esc
" to have the same behavior
inoremap <C-c> <Esc>

" Move cursor in Insert mode
" (This will not work if YCM window is open)
inoremap <C-j> <down>
inoremap <C-k> <up>
inoremap <C-h> <left>
inoremap <C-l> <right>

" tabs shortcuts
nnoremap th  :tabfirst<CR>
nnoremap tk  :tabnext<CR>
nnoremap tj  :tabprev<CR>
nnoremap tl  :tablast<CR>
nnoremap tt  :tabedit<Space>
nnoremap te  :tabedit<Space>
nnoremap tx  :tabclose<CR>

" Insert curly brackets automatically
inoremap {<cr> {<cr>}<c-o><s-o>
