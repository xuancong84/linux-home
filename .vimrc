" my latest version of .vimrc
" F2 toggle autoindent during paste
" F3/F4 show/hide line number
" F5/F6 set/unset scrollbind
" F7/F8 toggles horizontal vertical layout of 2 file windows
" F9/F10 set/unset wrap
" F12 vimdiff ignore whitespace/tab
" insert mode mouse can scroll screen, set cursor position
" non-insert mode mouse can scroll cursor, terminal mouse highlight automatically save into copy/paste buffer
" d#d : delete # lines, contents no longer go into copy/paste buffer
" c#c : cut # lines, contents go into copy/paste buffer
" mouse can work past the 220th column
" vimdiff : all text visible (evening scheme)

set nocompatible

filetype plugin indent on
set mouse=a
set tabstop=4
set shiftwidth=4
set scrolloff=0
set autoindent
set smartindent
set nowrap
set backspace=2
set backspace=indent,eol,start
syntax on
autocmd FileType python set tabstop=4|set shiftwidth=4|set noexpandtab

set noexpandtab
set pastetoggle=<F2>
nnoremap <silent> <F8> :TlistToggle<CR>
inoremap <C-J> <C-\><C-O>b
inoremap <C-K> <C-\><C-O>w
inoremap <C-BS> <C-W>
inoremap <C-H> <C-W>

set hlsearch
set ttymouse=xterm2
hi comment ctermfg=green
set fileencodings=utf8,gb2312
map <F3> <Esc>:set number<CR>
map <F4> <Esc>:set nonumber<CR>
map <F5> <Esc>:set scrollbind<CR>
map <F6> <Esc>:set noscrollbind<CR>
map <F7> <C-W>t<C-W>K
map <F8> <C-W>t<C-W>H
map <F9> <Esc>:set wrap<CR>
map <F10> <Esc>:set nowrap<CR>
map <F11> <Esc>:set ignorecase<CR>
map <F12> <Esc>:set diffopt+=iwhite<CR>
"set viminfo='10,\"100,:20,%,n~/.viminfo
"set indentexpr=''
"set noautoindent
"autocmd BufRead,BufNewFile *.cu set noic cin autoindent
if &diff
    colorscheme evening
endif

if has("mouse_sgr")
    set ttymouse=sgr
else
    set ttymouse=xterm2
end

function! ResCur()
  if line("'\"") <= line("$")
    normal! g`"
    return 1
  endif
endfunction

augroup resCur
  autocmd!
  autocmd BufWinEnter * call ResCur()
augroup END

nnoremap d "_d
vnoremap d "_d
vnoremap p "_p


let g:LargeFile = 1024 * 1024 * 10
augroup LargeFile
 autocmd BufReadPre * let f=getfsize(expand("<afile>")) | if f > g:LargeFile || f == -2 | call LargeFile() | endif
augroup END

function LargeFile()
 " no syntax highlighting etc
 set eventignore+=FileType
 " save memory when other file is viewed
 setlocal bufhidden=unload
 " is read-only (write with :w new_filename)
 " setlocal buftype=nowrite
 " no undo possible
 setlocal noswapfile
 " display message
 autocmd VimEnter *  echo "The file is larger than " . (g:LargeFile / 1024 / 1024) . " MB, so some options are changed (see .vimrc for details)."
endfunction
