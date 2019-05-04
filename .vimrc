" Load plugin configuration only if vim-plug is installed
if ! empty(glob('~/.vim/autoload/plug.vim'))
    source ~/.dotfiles/.vimrc.plugins
endif


"========== General ==========

" Don't be compatible with vi, so everything will work fine
set nocompatible

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

" Search dinamically as we type search term
set incsearch

" Ignore case when searching, unless a capital character is used
set ignorecase
set smartcase

" Show line numbers
set number

" Visual autocomplete for command menu
set wildmenu

" Show file name as window title
set title

" Set old window title to emtpy, so the text 'Thanks for flying vim' will
" not be shown as the title of the terminal
set titleold=

" Backspace deletes in Insert mode (like always)
set bs=2

" Uses 4 spaces (instead of TAB) as indentation
set expandtab " TABs are spaces
set tabstop=4 " number of visual spaces per TAB
set softtabstop=4 " number of spaces per TAB when editing
set shiftwidth=4 " number of spaces in automatic indentation

" Use 2 spaces for YAML indentation
au FileType yaml setlocal expandtab tabstop=2 softtabstop=2 shiftwidth=2

" Open vertical window split on the right
set splitright

" Open horizontal window split on the bottom
set splitbelow

" Detect .md extension as markdown filetype
autocmd BufRead,BufNewFile *.md set filetype=markdown

" Jump to the last position when reopening a file
if has("autocmd")
    au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" Close any loclist window if it's the last one
augroup CloseLoclistWindowGroup
    autocmd!
    autocmd QuitPre * if empty(&buftype) | lclose | endif
augroup END

" Location list window toggle
" (loclist appears only if it's populated with errors)
" (https://github.com/Valloric/ListToggle/blob/master/plugin/listtoggle.vim)
function! s:LoclistToggle() abort
    let buffer_count_before = s:BufferCount()
    silent! lclose

    if s:BufferCount() == buffer_count_before
        silent! lopen
    endif
endfunction

function! s:BufferCount() abort
    return len(filter(range(1, bufnr('$')), 'bufwinnr(v:val) != -1'))
endfunction

command LL :call s:LoclistToggle()


"========== Key Remaps ==========

" TODO: Remap ctrl key to caps lock key

" Esc remap
" (Esc is too far away to be confortable)
inoremap jk <Esc>

" Move vertically by visual line
" (so we don't skip long lines that are wrapped into two or more lines)
nnoremap j gj
nnoremap k gk

" Turn off search highlighting
" (disabled: in conflict with Ale, <CR> is not placing the cursor
" in the error from loclist anymore)
"nnoremap <CR> :nohlsearch<CR>

" Insert closing brace automatically when pressing enter after open brace
" (for example when creating a function's body)
inoremap {<cr> {<cr>}<c-o><s-o>

" Copy text, from cursor position to the end-of-line
" (to be consistent with C and D operators)
nnoremap Y y$
