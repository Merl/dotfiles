" ~/.vimrc - Vim 9.1+ (Debian 13, Git Bash/MSYS2), plugins via vim-plug
"
" vim-plug itself is vendored in the repo: ~/.vim/autoload/plug.vim
" (junegunn/vim-plug master 7e5aae5, 2026-10-15; latest release tag 0.14.0).
" Plugins are installed into ~/.vim/plugged. Missing plugins are installed
" automatically on the first interactive start (needs git and network).
"
" Pinned plugin commits: ~/.vim/plug-snapshot.vim
"   restore:  vim -S ~/.vim/plug-snapshot.vim
"   refresh:  :PlugUpdate, test, then :PlugSnapshot! ~/.vim/plug-snapshot.vim

" leader first, so that all <leader> mappings below use it
" ("," instead of "\": fewer keystrokes on a German keyboard)
let mapleader = ","

" ---------------------------------------------------------------------------
" Plugins
" ---------------------------------------------------------------------------
call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-sensible'

" file tree
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'

" status line / buffer tabline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" git
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'             " :GBrowse for GitHub
Plug 'shumphrey/fugitive-gitlab.vim' " :GBrowse for GitLab

" only used to generate ~/.tmuxline.conf (:Tmuxline, :TmuxlineSnapshot!)
Plug 'edkolev/tmuxline.vim'

" fuzzy finder; the do-hook downloads a matching fzf binary into the plugin
" (Linux and Windows), so no system package is needed
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" rainbow parentheses
Plug 'luochen1990/rainbow'

" must be loaded last
Plug 'ryanoasis/vim-devicons'

call plug#end()   " also runs 'filetype plugin indent on' and 'syntax enable'

" Install missing plugins on startup, then reload this file.
" Skipped without git or without a usable terminal, so that a start without
" TERM (cron, scripts, dumb terminals) cannot block on the installer.
" path of this file; $MYVIMRC is empty when started with -u
let s:vimrc = expand('<sfile>:p')
if executable('git') && !empty($TERM) && $TERM !=# 'dumb'
  augroup plug_autoinstall
    autocmd!
    autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
          \ | PlugInstall --sync | execute 'source' fnameescape(s:vimrc)
          \ | endif
  augroup END
endif

" ---------------------------------------------------------------------------
" Settings (vim-sensible covers the basics)
" ---------------------------------------------------------------------------
set background=dark
set showcmd             " show (partial) command in status line
set showmatch           " show matching brackets
set ignorecase          " case insensitive search ...
set smartcase           " ... unless the pattern contains upper case
set autowrite           " save before commands like :next and :make
set hidden              " keep abandoned buffers loaded
set mouse=              " no mouse
set number              " line numbers

" indent with 4 spaces, real tabs display as 8
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab

" jump to the last known cursor position when reopening a file
augroup vimrc_lastpos
  autocmd!
  autocmd BufReadPost *
        \ if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
        \ |   exe "normal! g`\""
        \ | endif
augroup END

" endless undo
" src: https://vi.stackexchange.com/questions/6/how-can-i-use-the-undofile
if !isdirectory($HOME . "/.vim/undo-dir")
  call mkdir($HOME . "/.vim/undo-dir", "p", 0700)
endif
set undodir=~/.vim/undo-dir
set undofile

" Inside tmux (TERM=tmux-256color) use xterm key handling, so that
" modified keys like Ctrl+arrow work (tmux sends them xterm-style).
if &term =~# '^tmux'
  set term=xterm-256color
endif

" ---------------------------------------------------------------------------
" Mappings
" ---------------------------------------------------------------------------
" ctrl + w in insert mode behaves like in normal mode
imap <C-w> <C-o><C-w>
" + and - change the window height without ctrl + w
map - <C-W>-
map + <C-W>+

" ctrl + arrow keys / ctrl + hjkl jump between windows
noremap <C-Down>  <C-W>j
noremap <C-Up>    <C-W>k
noremap <C-Left>  <C-W>h
noremap <C-Right> <C-W>l
noremap <C-j> <C-W>j
noremap <C-k> <C-W>k
noremap <C-h> <C-W>h
noremap <C-l> <C-W>l

" ---------------------------------------------------------------------------
" NERDTree
" ---------------------------------------------------------------------------
let NERDTreeHijackNetrw = 1
map <C-n> :NERDTreeToggle<CR>
map <C-f> :NERDTreeFind<CR>

augroup vimrc_nerdtree
  autocmd!
  " open NERDTree only when Vim is started with a single directory argument
  autocmd StdinReadPre * let s:std_in = 1
  autocmd VimEnter * if exists(':NERDTree') == 2 && argc() == 1
        \ && isdirectory(argv()[0]) && !exists('s:std_in')
        \ | execute 'NERDTree' fnameescape(argv()[0]) | wincmd p | enew
        \ | execute 'cd' fnameescape(argv()[0]) | endif
  " exit Vim if NERDTree is the only window remaining in the only tab
  autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1
        \ && exists('b:NERDTree') && b:NERDTree.isTabTree()
        \ | call feedkeys(":quit\<CR>:\<BS>") | endif
  " close the tab if NERDTree is the only window remaining in it
  autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree')
        \ && b:NERDTree.isTabTree()
        \ | call feedkeys(":quit\<CR>:\<BS>") | endif
augroup END

" ---------------------------------------------------------------------------
" fzf (degrades to built-in commands when the fzf binary is missing)
" ---------------------------------------------------------------------------
" binary from PATH or from the fzf plugin's do-hook (bin/fzf, bin/fzf.exe)
if executable('fzf') || !empty(glob(expand('~/.vim/plugged/fzf/bin/fzf*')))
  nnoremap <C-p>     :Files<CR>
  nnoremap <leader>b :Buffers<CR>
else
  nnoremap <C-p>     :echo "fzf binary missing (:call fzf#install())"<CR>
  nnoremap <leader>b :ls<CR>:buffer<Space>
endif

" ---------------------------------------------------------------------------
" airline / tmuxline / rainbow
" ---------------------------------------------------------------------------
let g:airline_theme = 'dark'
" buffers as tabs at the top
let g:airline#extensions#tabline#enabled = 1
" powerline symbols (needs a Nerd Font or powerline font)
let g:airline_powerline_fonts = 1
" do not overwrite the tmux status line on vim start; ~/.tmuxline.conf is
" generated explicitly with  :Tmuxline airline | TmuxlineSnapshot! ~/.tmuxline.conf
let g:airline#extensions#tmuxline#enabled = 0
let g:tmuxline_powerline_separators = 1
let g:tmuxline_preset = {
      \ 'a'    : '#S',
      \ 'b'    : '#W',
      \ 'c'    : '#H',
      \ 'win'  : '#I #W',
      \ 'cwin' : '#I #W',
      \ 'x'    : '#(cut -d " " -f 1-3 /proc/loadavg)',
      \ 'y'    : '%a',
      \ 'z'    : '%d.%m.%Y  %H:%M:%S',
      \ 'options' : {'status-justify' : 'centre'}}

let g:rainbow_active = 1

" ---------------------------------------------------------------------------
" host-specific additions
" ---------------------------------------------------------------------------
if filereadable(expand("~/.overwrites/vimrc"))
  source ~/.overwrites/vimrc
endif
