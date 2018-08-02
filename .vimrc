" Download vim-plug Plugin Manager if it is not in the system
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif


" ========== vim-plug Plugin Manager ==========

" vim-plug automatically executes
"   - filetype plugin indent on
"   - syntax enable

call plug#begin('~/.vim/plugged')
"Plug 'steffanc/cscopemaps.vim'
Plug 'scrooloose/nerdtree'
Plug 'airblade/vim-gitgutter'
Plug 'terryma/vim-smooth-scroll'
Plug 'vim-airline/vim-airline'
Plug 'suan/vim-instant-markdown'
Plug 'pearofducks/ansible-vim'
Plug 'arcticicestudio/nord-vim'
call plug#end()


"========== General ==========

" Syntax color
syntax on

" Colorscheme for the syntax
"   - ron works well with GNOME Terminal color profile Nord/Nord Solarized.
"   - nord needs to be activated inside plugin section.
colorscheme ron

" Column limit highlight
set colorcolumn=80
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

" Ignore case when seraching, unless a capital character is used
set ignorecase
set smartcase

" Show line numbers
set number

" Show file name as window title
set title

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


"========== vim-airline ==========

" Use colorscheme nord
let g:airline_theme='nord'

" Enable tabline to show the tabs at the top of the window
let g:airline#extensions#tabline#enabled = 1


"========== NERDTree ==========

" Open/Close NERDTree
map <C-e> :NERDTreeToggle<CR>

" Change arrows to show expandable/collapsible elements
let g:NERDTreeDirArrowExpandable = "+"
let g:NERDTreeDirArrowCollapsible = "-"

" (Not)Show hidden files
let NERDTreeShowHidden = 0

"========== vim-gitgutter ==========

" Faster updates (strange behavior)
"set updatetime=250


"========== vim-smooth-scroll ===========

noremap <silent> <C-k> :call smooth_scroll#up(&scroll, 15, 2)<CR>
noremap <silent> <C-j> :call smooth_scroll#down(&scroll, 15, 2)<CR>


"========== markdown-syntax ==========

" Disable folding
"let g:vim_markdown_folding_disabled = 1


"========== vim-instant-markdown ==========

" Disable autostart (:InstantMarkdownPreview to show the file)
let g:instant_markdown_autostart = 0


"========== Key Remaps ==========

" tabs shortcuts
nnoremap th  :tabfirst<CR>
nnoremap tk  :tabnext<CR>
nnoremap tj  :tabprev<CR>
nnoremap tl  :tablast<CR>
nnoremap tt  :tabedit<Space>
nnoremap te  :tabedit<Space>
nnoremap tx :tabclose<CR>

" Insert curly brackets automatically
inoremap {<cr> {<cr>}<c-o><s-o>

" Disable arrow keys
"nnoremap <Left> :echoe "Use h"<CR>
"nnoremap <Right> :echoe "Use l"<CR>
"nnoremap <Up> :echoe "Use k"<CR>
"nnoremap <Down> :echoe "Use j"<CR>
