" defaults as we cannot rely on system vimrc
set nocompatible              " be iMproved, required
filetype off                  " required
syntax on
set background=dark
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif
if has("autocmd")
  filetype plugin indent on
endif
set showcmd             " Show (partial) command in status line.
set showmatch           " Show matching brackets.
set ignorecase          " Do case insensitive matching
set smartcase           " Do smart case matching
set incsearch           " Incremental search
set autowrite           " Automatically save before commands like :next and :make
set hidden              " Hide buffers when they are abandoned
set mouse=              " Disable mouse usage (all modes)

" Vundle
" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'

" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
"Plugin 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
" Plugin 'L9'
" Git plugin not hosted on GitHub
"Plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
"Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
"Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
" Install L9 and avoid a Naming conflict if you've already installed a
" different version somewhere else.
" Plugin 'ascenator/L9', {'name': 'newL9'}

Plugin 'bufexplorer.zip'
Plugin 'fholgado/minibufexpl.vim'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Plugin 'scrooloose/nerdtree'
Plugin 'rainbow.zip'
Plugin 'altercation/vim-colors-solarized'
Plugin 'tpope/vim-scriptease'
Plugin 'tpope/vim-sensible'
Plugin 'tpope/vim-vinegar'
Plugin 'tpope/vim-vividchalk'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-rhubarb'
Plugin 'shumphrey/fugitive-gitlab.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'wincent/command-t'
Plugin 'edkolev/tmuxline.vim'
Plugin 'ryanoasis/vim-devicons'

call vundle#end()            " required
filetype plugin indent on    " required

" pathogen - should not be neccesarry with Vundle
" execute pathogen#infect()

" whitespaces as tabs
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab
" treat .md as markdown
autocmd BufNewFile,BufReadPost *.md set filetype=markdown
" let NERDTree take over Netrw
let NERDTreeHijackNetrw=1
" display line numbers
set number

" Themes
"let g:solarized_termcolors=256
"colorscheme solarized
"colorscheme vividchalk
"colorscheme default

" make ctrl + w in insertmode behave like in normal mode
imap <C-w> <C-o><C-w>
" map + and - to de/increase window size without need for ctrl + w
map - <C-W>-
map + <C-W>+

" map ctrl + arrow keys to jump through windows without need for ctrl + w
noremap <C-Down>  <C-W>j
noremap <C-Up>    <C-W>k
noremap <C-Left>  <C-W>h
noremap <C-Right> <C-W>l

" map hjkl + arrow keys to jump through windows without need for ctrl + w
noremap <C-j> <C-W>j
noremap <C-k> <C-W>k
noremap <C-h> <C-W>h
noremap <C-l> <C-W>l

" map ctrl + n to toogle NERDTree
map <C-n> :NERDTreeToggle<CR>
map <C-f> :NERDTreeFind<CR>

" map ctrl + b to :MBEFocus
map <C-b> :MBEFocus<CR>

" open NERDTree if empty vim is started
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" open NERDTree if dir is opened
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif

" close vim if NERDTree is last open window
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" enable airline tab theme
let g:airline#extensions#tabline#enabled = 1
" airline use powerline font
let g:airline_powerline_fonts = 1
" disable overwriting tmux line on vim start
let g:airline#extensions#tmuxline#enabled = 0

" map the leader to "," instead of "\" (less keystrokes on german keyboard)
let mapleader = ","

" set vim to xterm-256color mode if tmux-256color is set
if &term == "tmux-256color"
    set term=xterm-256color
endif

" vim endless undo
" src: https://vi.stackexchange.com/questions/6/how-can-i-use-the-undofile
if !isdirectory($HOME."/.vim")
    call mkdir($HOME."/.vim", "", 0770)
endif
if !isdirectory($HOME."/.vim/undo-dir")
    call mkdir($HOME."/.vim/undo-dir", "", 0700)
endif
set undodir=~/.vim/undo-dir
set undofile


let $LOCALFILE=expand("~/.overwrites/vimrc")
if filereadable($LOCALFILE)
    source $LOCALFILE
endif
 
