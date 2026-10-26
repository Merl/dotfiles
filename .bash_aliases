# ~/.bash_aliases – sourced by ~/.bashrc (Linux and Git Bash)
# Kept small on purpose; replaces the former bash-it aliases and base plugin.

command_exists() { command -v "$1" >/dev/null 2>&1; }

# --- ls / navigation ---------------------------------------------------------
if ls --color=auto -d . >/dev/null 2>&1; then
    alias ls='ls --color=auto'
fi
alias ll='ls -lh'
alias l='ls -lAh'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias md='mkdir -p'
alias grep='grep --color=auto'
alias c='clear'
alias h='history'

# --- Editor ------------------------------------------------------------------
alias v='vim'
alias svim='sudoedit'

# --- ssh ---------------------------------------------------------------------
alias s='ssh -l root'

# --- git (no gs on purpose: would shadow ghostscript) ------------------------
alias g='git'
alias gst='git status -sb'
alias ga='git add'
alias gap='git add -p'
alias gc='git commit -v'
alias gca='git commit -v --amend'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch -vv'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gf='git fetch --all --prune'
alias gpl='git pull --ff-only'
alias gp='git push'
alias gcl='git clone'

# --- tmux --------------------------------------------------------------------
alias txl='tmux ls'
alias txn='tmux new -s'
alias txa='tmux attach -t'
# tm [session]: attach to (or create) session "merl", see ~/.sbin/tmux-merl.sh
tm() { "$HOME/.sbin/tmux-merl.sh" "$@"; }

# --- systemd / apt (only where available) ------------------------------------
if command_exists systemctl; then
    alias sc='systemctl'
    alias scs='systemctl status'
    alias scu='systemctl --user'
    alias jf='journalctl -f'
    alias jb='journalctl -b'
fi
if command_exists apt; then
    alias au='sudo apt update'
    alias aug='sudo apt update && sudo apt upgrade'
    alias ai='sudo apt install'
    alias aps='apt search'      # not "as": GNU assembler
    alias apsh='apt show'       # not "ash": Almquist shell
fi

# --- functions ---------------------------------------------------------------
# create a directory and cd into it
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# timestamped backup copy: buf file -> file.20261026-142233
buf() {
    local f
    for f in "$@"; do
        cp -a -- "$f" "$f.$(date +%Y%m%d-%H%M%S)"
    done
}

# move to trash instead of rm (gio or trash-cli, otherwise fail)
del() {
    if command_exists gio; then
        gio trash -- "$@"
    elif command_exists trash-put; then
        trash-put -- "$@"
    else
        echo "del: neither gio nor trash-put available" >&2
        return 1
    fi
}

# local addresses
ips() {
    if command_exists ip; then
        ip -br addr
    else
        ipconfig | grep -i 'IPv[46]'
    fi
}

# public address (queries an external service)
myip() { curl -fsS https://api.ipify.org && echo; }
