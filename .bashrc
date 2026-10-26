# ~/.bashrc: interactive bash (Debian/serenity and Windows Git Bash).
# Prompt: Starship if installed, otherwise a small fallback PS1.
# Aliases and functions live in ~/.bash_aliases, readline in ~/.inputrc.
# Host-local additions (not in the repo): ~/.overwrites/bashrc.sh

# Not interactive: do nothing.
case $- in
    *i*) ;;
      *) return ;;
esac

# --- PATH ----------------------------------------------------------------------
# Also done in ~/.profile; repeated here for shells that skip it (Git Bash
# reads ~/.bash_profile, not ~/.profile). Idempotent: no duplicate entries.
for _d in "$HOME/.local/bin" "$HOME/.sbin"; do
    case ":$PATH:" in
        *":$_d:"*) ;;
        *) [ -d "$_d" ] && PATH="$_d:$PATH" ;;
    esac
done
unset _d
export PATH

# --- History -------------------------------------------------------------------
HISTCONTROL=ignoreboth          # no duplicates, no lines starting with a space
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT='%F %T  '
shopt -s histappend             # append to the history file, don't overwrite
# Write each command to the history file right away, so other shells (tmux
# panes) can pick it up with `history -n`. Cheap: no re-reading per prompt.
#
# _prompt_cmd_add adds a command to PROMPT_COMMAND once, so sourcing this file
# twice (Git Bash's default ~/.bash_profile sources ~/.profile AND ~/.bashrc,
# or a manual `. ~/.bashrc`) doesn't stack entries in front of starship_precmd
# (Starship moves an existing PROMPT_COMMAND into STARSHIP_PROMPT_COMMAND).
_prompt_cmd_add() {
    case "; $PROMPT_COMMAND; ${STARSHIP_PROMPT_COMMAND-}; " in
        *"; $1; "*) ;;
        *) PROMPT_COMMAND="$1${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
    esac
}
_prompt_cmd_add 'history -a'

# --- Shell options -------------------------------------------------------------
shopt -s checkwinsize           # update LINES/COLUMNS after each command
shopt -s globstar               # ** matches recursively
[ -t 0 ] && stty -ixon 2>/dev/null   # free Ctrl-S/Ctrl-Q from flow control

# --- Environment ---------------------------------------------------------------
export EDITOR=vim
export VISUAL=vim

# less for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# LS_COLORS (the ls/grep color aliases are in ~/.bash_aliases)
if command -v dircolors >/dev/null 2>&1; then
    if [ -r ~/.dircolors ]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
fi

# --- Completion ----------------------------------------------------------------
# System package bash-completion (Debian). Git Bash has none; its login
# profile loads git completion itself.
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# --- Aliases and functions -----------------------------------------------------
[ -f ~/.bash_aliases ] && . ~/.bash_aliases

# Dotfiles bare repo (2018 layout; legacy, harmless)
alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# --- tmux: refresh environment after re-attach -----------------------------------
# tmux updates SSH_AUTH_SOCK, SSH_CONNECTION and DISPLAY in the session
# environment on every attach (update-environment, tmux default), but shells
# that are already running keep their old values. refresh_env copies the
# current values from the session into this shell; inside tmux it runs before
# every prompt (one `tmux show-environment` call), so agent forwarding keeps
# working after a reconnect. A variable the new client doesn't have is
# unset, except SSH_AUTH_SOCK while it still points to a live socket.
refresh_env() {
    [ -n "$TMUX" ] || return 0
    local line
    while IFS= read -r line; do
        case $line in
            SSH_AUTH_SOCK=*|SSH_CONNECTION=*|DISPLAY=*) export "$line" ;;
            -SSH_AUTH_SOCK) [ -S "${SSH_AUTH_SOCK-}" ] || unset SSH_AUTH_SOCK ;;
            -SSH_CONNECTION|-DISPLAY) unset "${line#-}" ;;
        esac
    done < <(tmux show-environment 2>/dev/null)
}
if [ -n "$TMUX" ]; then
    _prompt_cmd_add refresh_env
fi

# --- Prompt --------------------------------------------------------------------
# Set the window title only on terminals that understand it.
case $TERM in
    xterm*|rxvt*|tmux*|screen*|alacritty|foot*|wezterm) _title=1 ;;
    *) _title= ;;
esac
if command -v starship >/dev/null 2>&1; then
    # Window title user@host: dir (Starship does not set one by itself)
    if [ -n "$_title" ]; then
        _set_win_title() { printf '\033]0;%s@%s: %s\007' "${USER:-$USERNAME}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"; }
        starship_precmd_user_func=_set_win_title
    fi
    eval "$(starship init bash)"
else
    # Fallback: git branch via git-prompt.sh if available, else plain.
    if ! declare -F __git_ps1 >/dev/null; then
        for _f in /usr/lib/git-core/git-sh-prompt \
                  /usr/share/git-core/contrib/completion/git-prompt.sh \
                  /ucrt64/share/git/completion/git-prompt.sh \
                  /mingw64/share/git/completion/git-prompt.sh \n                  /usr/share/git/completion/git-prompt.sh; do
            [ -r "$_f" ] && { . "$_f"; break; }
        done
        unset _f
    fi
    _c_user='\[\e[1;32m\]'; [ "$EUID" -eq 0 ] && _c_user='\[\e[1;31m\]'
    PS1=
    [ -n "$_title" ] && PS1='\[\e]0;\u@\h: \w\a\]'
    PS1="$PS1$_c_user"'\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]'
    if declare -F __git_ps1 >/dev/null; then
        GIT_PS1_SHOWDIRTYSTATE=1
        PS1="$PS1"'\[\e[33m\]$(__git_ps1 " (%s)")\[\e[0m\]'
    fi
    PS1="$PS1"'\$ '
    unset _c_user
fi
unset _title

# --- Host-local additions ------------------------------------------------------
if [ -f ~/.overwrites/bashrc.sh ]; then
    . ~/.overwrites/bashrc.sh
fi

# No tmux autostart: use `tm` (~/.sbin/tmux-merl.sh) to attach/create session merl.
