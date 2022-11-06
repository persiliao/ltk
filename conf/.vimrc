set nocompatible "Use pure vim mode
:nnoremap Q <Nop> "Block Q to avoid entering Ex mode
syntax enable "Syntax highlighting
set history=50 "Number Of History
"set foldcolumn=1 "margin left
set noeb "Remove the input error prompt sound
set noerrorbells
set novisualbell
set t_vb=
set tm=500

filetype plugin on
filetype plugin indent on

set nobackup "Disable the generation of backup files
set noswapfile "Disable the generation of temporary files
set autowrite "Automatically saved
set autoread "Read automatically
set ruler "Open the status bar ruler
set magic "set magic
set guioptions-=T  "Hide Toolbar, set guioptions-T
set guioptions-=m  "Hide Menu bar, set guioptions-m
set clipboard+=unnamed "Shared clipboard, ctrl+ c/ v copy and paste
colorscheme evening "The color theme

set cmdheight=1
au FocusGained,BufEnter * checktime
let mapleader = ","
nmap <leader>w :w!<cr>
command! W execute 'w !sudo tee % > /dev/null' <bar> edit!
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

set enc=utf-8
set fencs=utf-8,ucs-bom,shift-jis,gb18030,gbk,gb2312,cp936
set langmenu=en_US
"set mouse=a
set selection=exclusive
set selectmode=mouse,key
"set helplang=cn

set ruler "Show current position
set number "Display line numbers
set background=dark "The background color
set showcmd "Display command
set laststatus=2 "The status bar is always displayed
set statusline=\ %<%F[%1*%M%*%n%R%H]%=\ %yCWD:\ %r%{getcwd()}%h\ \ %0(%{&fileformat}\ %{&encoding}\ %c:%l/%L/%p%\%%\) "Status Bar Information

set autoindent "Automatic indentation
set smartindent "
set wrap
set cindent "C the indentation
set tabstop=2 "hardware tab
set softtabstop=2
set shiftwidth=2 "Indent the number of Spaces
set expandtab "Spaces replaced tab
set smarttab "Smart tab

set showmatch "Show matching parentheses
set mat=2 "Match the bracket flicker frequency
set ignorecase "Ignoring case
set smartcase
set matchtime=5 "1/10 of a second delay
set ignorecase "Search for character by character highlighting
set hlsearch "Highlighting the search
set incsearch "Match in search

":inoremap ( ()<ESC>i
":inoremap ) <c-r>=ClosePair(')')<CR>
":inoremap { {<CR>}<ESC>O
":inoremap } <c-r>=ClosePair('}')<CR>
":inoremap [ []<ESC>i
":inoremap ] <c-r>=ClosePair(']')<CR>
":inoremap " ""<ESC>i
":inoremap ' ''<ESC>i
function! ClosePair(char)
    if getline('.')[col('.') - 1] == a:char
        return "\<Right>"
    else
        return a:char
    endif
endfunction

fun! CleanExtraSpaces()
    let save_cursor = getpos(".")
    let old_query = getreg('/')
    silent! %s/\s\+$//e
    call setpos('.', save_cursor)
    call setreg('/', old_query)
endfun

if has("autocmd")
    autocmd BufWritePre *.conf,*.ini,*.txt,*.js,*.py,*.wiki,*.sh,*.coffee :call CleanExtraSpaces()
endif

au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif