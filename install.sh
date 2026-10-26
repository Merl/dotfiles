#!/usr/bin/env bash
# install.sh - set up this environment on a host: fetch/update the repository,
# install missing dependencies, link (or copy) the dotfiles into $HOME and
# install the vim plugins.
#
# Fresh host (no checkout yet):
#   bash <(curl -fsSL https://raw.githubusercontent.com/Merl/dotfiles/master/install.sh)
# Existing checkout:
#   ~/.dotfiles/install.sh
#
# Every step is idempotent: a second run reports "ok" everywhere and changes
# nothing. Files in the way are moved to ~/.dotfiles-backup/<timestamp>/
# first; --restore undoes a run (dotfiles only, not packages).

set -euo pipefail

ORIG_ARGS=("$@")

usage() {
    cat <<'EOF'
Usage: install.sh [options]

Set up the dotfiles environment: clone/update the repository, install missing
packages, link the dotfiles into $HOME, install vim plugins.

  -n, --dry-run        show what would happen, change nothing
      --copy           copy files instead of creating symlinks
                       (default on Windows / Git Bash / MSYS2 / Cygwin)
      --no-packages    do not check or install packages (incl. starship)
      --no-vim         do not install vim plugins
      --pinned         check the vim plugins out at the commits recorded in
                       ~/.vim/plug-snapshot.vim (default: newest versions)
      --no-pull        do not update the repository (git pull --ff-only)
      --restore [DIR]  undo an installation of the dotfiles: remove the
                       links/copies made by that run and move the backed-up
                       originals back. DIR defaults to the newest not yet
                       restored directory under ~/.dotfiles-backup.
                       Home dotfiles only: packages, vim plugins and the
                       files of install.ps1 are left alone.
  -h, --help           show this help

Run outside a checkout (e.g. via curl), it clones the repository to
$DOTFILES_DIR (default ~/.dotfiles) and runs the install.sh from there.

Environment:
  DOTFILES_DIR         checkout location for the bootstrap (default ~/.dotfiles)
  DOTFILES_REPO_URL    clone from this URL instead of Forgejo/GitHub
  DOTFILES_NO_SUDO=1   behave as if root were not available (no sudo); used
                       for tests: starship is then installed into ~/.local/bin
EOF
}

# --- configuration -----------------------------------------------------------
FORGEJO_URL=ssh://git@git.shelltec.de:2222/merl/dotfiles.git
GITHUB_URL=https://github.com/Merl/dotfiles.git
WIN_SSH=C:/Windows/System32/OpenSSH/ssh.exe
# SSH_OPTS is set after the arguments: a dry run must not add host keys
STARSHIP_INSTALLER=https://starship.rs/install.sh

# files to install (relative to $HOME and to the repo root)
MANIFEST=(
    .bashrc
    .bash_profile
    .profile
    .bash_aliases
    .inputrc
    .tmux.conf
    .tmuxline.conf
    .vimrc
    .vim/autoload/plug.vim
    .vim/plug-snapshot.vim
    .config/starship.toml
    .config/mc/ini
    .sbin/tmux-merl.sh
    .gitconfig
)
MANIFEST_LINUX=(
    .selected_editor
)

# --- helpers -----------------------------------------------------------------
say()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; WARNINGS+=("$*"); }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

# act LABEL ITEM [DETAIL]: aligned status line
act() { printf '%s%-12s %s%s\n' "$PREFIX" "$1" "$2" "${3:+  ($3)}"; }

# run CMD...: execute unless in dry-run mode
run() { if [ "$DRY_RUN" -eq 0 ]; then "$@"; fi; }

have() { command -v "$1" >/dev/null 2>&1; }

# with_timeout SECONDS CMD...: use timeout(1) when available
with_timeout() {
    local s=$1; shift
    if have timeout; then timeout "$s" "$@"; else "$@"; fi
}

# resolve PATH: canonical absolute path (follows symlinks); empty if impossible
resolve() { readlink -f -- "$1" 2>/dev/null || true; }

# describe PATH: what currently exists there
describe() {
    if [ -L "$1" ]; then printf 'symlink -> %s' "$(readlink -- "$1")"
    elif [ -d "$1" ]; then printf 'directory'
    else printf 'file'
    fi
}

# is_ours MODE SRC TARGET: target is already exactly our installed file
is_ours() {
    local mode=$1 src=$2 target=$3
    if [ "$mode" = link ]; then
        [ -L "$target" ] || return 1
        [ "$(readlink -- "$target")" = "$src" ] && return 0
        [ "$(resolve "$target")" = "$(resolve "$src")" ]
    else
        [ -f "$target" ] && [ ! -L "$target" ] && cmp -s -- "$src" "$target"
    fi
}

exists() { [ -e "$1" ] || [ -L "$1" ]; }

file_sum() { cksum < "$1" 2>/dev/null || echo none; }

# file_hash FILE: tagged content checksum, recorded in installed.list for copies
file_hash() {
    local h
    if have sha256sum; then h=$(sha256sum < "$1") && printf 'sha256:%s' "${h%% *}" && return 0
    elif have shasum; then h=$(shasum -a 256 < "$1") && printf 'sha256:%s' "${h%% *}" && return 0
    fi
    h=$(cksum < "$1") && printf 'cksum:%s' "${h// /-}"
}

# hash_matches FILE TAGGED: FILE's checksum equals TAGGED (same algorithm)
hash_matches() {
    local h
    case $2 in
        sha256:*)
            if have sha256sum; then h=$(sha256sum < "$1") || return 1
            else h=$(shasum -a 256 < "$1") || return 1
            fi
            [ "sha256:${h%% *}" = "$2" ] ;;
        cksum:*)
            h=$(cksum < "$1") || return 1
            [ "cksum:${h// /-}" = "$2" ] ;;
        *) return 1 ;;
    esac
}

# real_parent PATH: nearest existing directory above PATH, symlinks resolved
real_parent() {
    local d
    d=$(dirname -- "$1")
    while [ ! -d "$d" ] && [ "$d" != / ] && [ "$d" != . ]; do d=$(dirname -- "$d"); done
    resolve "$d"
}

# inside DIR PATH: PATH (a resolved directory) is DIR or below it; compares
# directories by identity (-ef), so path spellings/mounts do not matter
inside() {
    local dir=$1 p=$2
    [ -n "$dir" ] && [ -n "$p" ] && [ -d "$dir" ] || return 1
    while :; do
        [ "$p" -ef "$dir" ] && return 0
        case $p in /|.|'') return 1 ;; esac
        p=$(dirname -- "$p")
    done
}

# norm_url URL: lower case, without trailing slashes and ".git"
norm_url() {
    local u
    u=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    u=${u%/}; u=${u%.git}; u=${u%/}
    printf '%s' "$u"
}

# is_our_url URL: one of the known remotes of this repository (or DOTFILES_REPO_URL)
is_our_url() {
    local u
    u=$(norm_url "$1")
    if [ -n "${DOTFILES_REPO_URL:-}" ] && [ "$u" = "$(norm_url "$DOTFILES_REPO_URL")" ]; then
        return 0
    fi
    printf '%s\n' "$u" | grep -Eq '^((ssh|https?|git)://)?([^@/]+@)?(git\.shelltec\.de|github\.com)(:[0-9]+)?[:/]merl/dotfiles$'
}

# has_repo_files DIR: DIR contains the files install.sh needs
has_repo_files() {
    [ -f "$1/.vimrc" ] && [ -f "$1/.vim/autoload/plug.vim" ] && [ -f "$1/install.sh" ]
}

# check_checkout DIR: dies unless DIR is a checkout of this repository that
# has an install.sh (never exec the install.sh of some other repository)
check_checkout() {
    local dir=$1 urls u ok=0
    urls=$(git -C "$dir" config --get-regexp '^remote\..*\.url$' 2>/dev/null | sed 's/^[^ ]* //' || true)
    while IFS= read -r u; do
        [ -n "$u" ] || continue
        if is_our_url "$u"; then ok=1; break; fi
    done <<< "$urls"
    if [ "$ok" -eq 0 ]; then
        die "$dir is a git checkout, but not of the dotfiles repository (remotes: ${urls:-none}). Move it away or set DOTFILES_DIR to another location."
    fi
    if ! has_repo_files "$dir"; then
        die "$dir is a dotfiles checkout without install.sh/.vimrc (old version or partial checkout?). Update it (git -C $dir pull) or move it away, or set DOTFILES_DIR."
    fi
}

# --- arguments ---------------------------------------------------------------
DRY_RUN=0
MODE=
RESTORE=0
RESTORE_DIR=
NO_PACKAGES=0
NO_VIM=0
NO_PULL=0
PINNED=0
while [ $# -gt 0 ]; do
    case $1 in
        -n|--dry-run)  DRY_RUN=1 ;;
        --copy)        MODE=copy ;;
        --no-packages) NO_PACKAGES=1 ;;
        --no-vim)      NO_VIM=1 ;;
        --no-pull)     NO_PULL=1 ;;
        --pinned)      PINNED=1 ;;
        --restore)
            RESTORE=1
            if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then RESTORE_DIR=$2; shift; fi
            ;;
        -h|--help)     usage; exit 0 ;;
        *)             usage >&2; die "unknown argument: $1" ;;
    esac
    shift
done

PREFIX=
[ "$DRY_RUN" -eq 1 ] && PREFIX='[dry-run] '
# a dry run only probes hosts that are already in known_hosts
if [ "$DRY_RUN" -eq 1 ]; then
    SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes"
else
    SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"
fi
WARNINGS=()
CHANGES=()
# set by a run that updated the checkout and restarted the new install.sh
if [ -n "${DOTFILES_REPO_UPDATED:-}" ]; then
    CHANGES+=("repository updated ($DOTFILES_REPO_UPDATED)")
    unset DOTFILES_REPO_UPDATED
fi

# --- environment -------------------------------------------------------------
[ -n "${HOME:-}" ] || die "\$HOME is not set"
[ -d "$HOME" ] || die "\$HOME ($HOME) is not a directory"
# "sudo install.sh" would install root-owned files into the user's home
if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" = 0 ] && [ "$HOME" != /root ]; then
    die "do not run this with sudo; run it as your user (it calls sudo itself for the packages)"
fi

case $(uname -s) in
    MINGW*|MSYS*|CYGWIN*) OS=windows ;;
    Linux)                OS=linux ;;
    *)                    OS=other ;;
esac

# REPO = directory of this script, symlinks resolved (empty when the script
# is not a file in a checkout, e.g. bash <(curl ...))
REPO=
script=${BASH_SOURCE[0]:-}
if [ -n "$script" ] && [ -f "$script" ]; then
    while [ -L "$script" ]; do
        dir=$(cd -P -- "$(dirname -- "$script")" && pwd)
        script=$(readlink -- "$script")
        case $script in /*) ;; *) script=$dir/$script ;; esac
    done
    REPO=$(cd -P -- "$(dirname -- "$script")" && pwd)
    has_repo_files "$REPO" || REPO=
fi

# git_ssh_candidates: ssh commands to try for the Forgejo remote, best first
git_ssh_candidates() {
    if [ "$OS" = windows ] && [ -x "/c/Windows/System32/OpenSSH/ssh.exe" ]; then
        printf '%s\n' "$WIN_SSH $SSH_OPTS"     # Windows OpenSSH: has the agent
    fi
    if have ssh; then printf '%s\n' "ssh $SSH_OPTS"; fi
}

# pick_source: sets SRC_URL and SRC_SSH (GIT_SSH_COMMAND to use, may be empty)
pick_source() {
    SRC_SSH=
    if [ -n "${DOTFILES_REPO_URL:-}" ]; then
        SRC_URL=$DOTFILES_REPO_URL
        return 0
    fi
    local c
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        if GIT_SSH_COMMAND=$c GIT_TERMINAL_PROMPT=0 with_timeout 20 \
               git ls-remote "$FORGEJO_URL" HEAD >/dev/null 2>&1; then
            SRC_URL=$FORGEJO_URL
            SRC_SSH=$c
            return 0
        fi
    done < <(git_ssh_candidates)
    SRC_URL=$GITHUB_URL
}

# =============================================================================
# bootstrap: no checkout -> clone (or update) $DOTFILES_DIR and re-exec
# =============================================================================
if [ -z "$REPO" ] && [ "$RESTORE" -eq 0 ]; then
    TARGET=${DOTFILES_DIR:-$HOME/.dotfiles}
    # guard against a loop: the install.sh started below must find its checkout
    if [ -n "${DOTFILES_BOOTSTRAPPED:-}" ]; then
        die "bootstrap started again from $TARGET/install.sh, which does not find its checkout; check $TARGET (move it away or set DOTFILES_DIR)"
    fi
    export DOTFILES_BOOTSTRAPPED=1
    say "${PREFIX}Bootstrap: not running from a dotfiles checkout; using $TARGET"
    if ! have git; then
        die "git is required for the bootstrap. Install it first (e.g. sudo apt-get install git) and run this again."
    fi
    if [ -d "$TARGET/.git" ]; then
        check_checkout "$TARGET"
        say "Checkout $TARGET exists; running its install.sh (it updates itself)."
        exec bash "$TARGET/install.sh" "${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}"
    fi
    if exists "$TARGET"; then
        die "$TARGET exists but is not a git checkout; move it away or set DOTFILES_DIR"
    fi
    pick_source
    if [ "$DRY_RUN" -eq 1 ]; then
        # Preview from a temporary clone so the remaining steps can be shown.
        tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-preview.XXXXXX")
        trap 'rm -rf -- "$tmp"' EXIT
        say "[dry-run] would clone $SRC_URL to $TARGET"
        say "[dry-run] previewing the remaining steps from a temporary clone"
        GIT_SSH_COMMAND=${SRC_SSH:-${GIT_SSH_COMMAND:-}} GIT_TERMINAL_PROMPT=0 \
            git clone -q "$SRC_URL" "$tmp/dotfiles" || die "clone of $SRC_URL failed"
        has_repo_files "$tmp/dotfiles" || die "$SRC_URL does not contain install.sh/.vimrc"
        rc=0
        DOTFILES_PREVIEW_OF=$TARGET bash "$tmp/dotfiles/install.sh" --no-pull "${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}" || rc=$?
        exit "$rc"
    fi
    say "Cloning $SRC_URL to $TARGET"
    mkdir -p -- "$(dirname -- "$TARGET")"
    if [ -n "$SRC_SSH" ]; then
        GIT_SSH_COMMAND=$SRC_SSH git clone "$SRC_URL" "$TARGET" || die "clone of $SRC_URL failed"
        case $SRC_SSH in
            "$WIN_SSH"*) git -C "$TARGET" config core.sshCommand "$WIN_SSH" ;;
        esac
    else
        GIT_TERMINAL_PROMPT=0 git clone "$SRC_URL" "$TARGET" || die "clone of $SRC_URL failed"
    fi
    check_checkout "$TARGET"
    exec bash "$TARGET/install.sh" --no-pull "${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}"
fi

unset DOTFILES_BOOTSTRAPPED
if [ -n "$REPO" ]; then
    HOME_REAL=$(cd -P -- "$HOME" && pwd)
    [ "$HOME_REAL" != "$REPO" ] || die "the repository is \$HOME itself (old bare-repo checkout?); clone it elsewhere, e.g. ~/.dotfiles"
fi
if [ -z "$MODE" ]; then
    if [ "$OS" = windows ]; then MODE="copy"; else MODE="link"; fi
fi

BACKUP_ROOT=$HOME/.dotfiles-backup

# =============================================================================
# restore (dotfiles only)
# =============================================================================
# installed.list lines: action<TAB>key<TAB>target<TAB>source<TAB>checksum
#   backup           the original was moved to <backup dir>/<key> (logged right
#                    after the move, so it is restorable even if the install failed)
#   link | copy      our symlink/copy was installed at target; copies carry the
#                    checksum of the installed file
#   rollback         installing failed and the original was put back at once
#   backup+link, backup+copy   older logs: backup and install in one line,
#                    no checksum (compared with the current repository file)

# is_installed MODE SRC SUM TARGET: TARGET is still what that run installed
is_installed() {
    local mode=$1 src=$2 sum=$3 target=$4
    case $mode in
        link) is_ours link "$src" "$target" ;;
        copy)
            if [ -n "$sum" ] && [ "$sum" != - ]; then
                [ -f "$target" ] && [ ! -L "$target" ] && hash_matches "$target" "$sum"
            else
                is_ours copy "$src" "$target"
            fi ;;
        *) return 1 ;;
    esac
}

# restore_key KEY: undo all logged actions for KEY; fails on a problem
restore_key() {
    local k=$1 i target="" inst="" src="" sum="" backed=0 rolled=0 removed=0 bak
    for i in "${!L_KEY[@]}"; do
        [ "${L_KEY[i]}" = "$k" ] || continue
        target=${L_TGT[i]}
        case ${L_ACT[i]} in
            backup)   backed=1 ;;
            rollback) rolled=1 ;;
            link|copy) inst=${L_ACT[i]}; src=${L_SRC[i]}; sum=${L_SUM[i]} ;;
            backup+link|backup+copy)
                backed=1; inst=${L_ACT[i]#backup+}; src=${L_SRC[i]}; sum=${L_SUM[i]} ;;
            *) warn "$LIST: unknown action '${L_ACT[i]}' for $k; skipped"; return 1 ;;
        esac
    done
    bak=$RESTORE_DIR/$k
    if [ "$rolled" -eq 1 ] && [ -z "$inst" ]; then
        act ok "$k" "install had failed; original was put back then"
        return 0
    fi
    # never remove or move a file that lies inside the repository
    if inside "$LIST_REPO" "$(real_parent "$target")"; then
        warn "$target: its directory resolves into the repository ($LIST_REPO); left alone"
        return 1
    fi
    if [ "$backed" -eq 1 ] && ! exists "$bak"; then
        if exists "$target" && ! is_installed "$inst" "$src" "$sum" "$target"; then
            act ok "$k" "already put back"
            return 0
        fi
        warn "backup $bak is missing; $target left as it is"
        return 1
    fi
    if [ -n "$inst" ] && exists "$target"; then
        if ! is_installed "$inst" "$src" "$sum" "$target"; then
            local note=
            [ "$backed" -eq 0 ] || note=" (the original stays in $bak)"
            warn "$target is not our $inst any more ($(describe "$target")); left alone$note"
            return 1
        fi
        act remove "$k"
        run rm -f -- "$target" || { warn "could not remove $target"; return 1; }
        removed=1
    fi
    if [ "$backed" -eq 1 ]; then
        if [ "$removed" -eq 0 ] && exists "$target"; then
            warn "$target exists ($(describe "$target")); the original stays in $bak"
            return 1
        fi
        act "put back" "$k"
        if ! { run mkdir -p -- "$(dirname -- "$target")" && run mv -- "$bak" "$target"; }; then
            warn "could not move $bak back to $target"
            return 1
        fi
    fi
    return 0
}

if [ "$RESTORE" -eq 1 ]; then
    if [ -z "$RESTORE_DIR" ]; then
        for d in "$BACKUP_ROOT"/*/; do
            d=${d%/}
            if [ -f "$d/installed.list" ] && [ ! -e "$d/restored" ]; then RESTORE_DIR=$d; fi
        done
        [ -n "$RESTORE_DIR" ] || die "nothing to restore in $BACKUP_ROOT"
    fi
    RESTORE_DIR=${RESTORE_DIR%/}
    LIST=$RESTORE_DIR/installed.list
    [ -f "$LIST" ] || die "$LIST not found"
    [ -e "$RESTORE_DIR/restored" ] && warn "$RESTORE_DIR was already restored once"
    # the repository that run installed from (the current one for old logs)
    LIST_REPO=$(sed -n 's/^# repo=//p' "$LIST" | head -n 1)
    LIST_REPO=${LIST_REPO:-$REPO}
    [ -z "$LIST_REPO" ] || LIST_REPO=$(resolve "$LIST_REPO")

    L_ACT=(); L_KEY=(); L_TGT=(); L_SRC=(); L_SUM=()
    while IFS=$'\t' read -r action key target src sum; do
        case $action in ''|'#'*) continue ;; esac
        L_ACT+=("$action"); L_KEY+=("$key"); L_TGT+=("$target"); L_SRC+=("${src:-}"); L_SUM+=("${sum:-}")
    done < "$LIST"

    # undo in reverse order, each key once
    keys=()
    for ((i = ${#L_KEY[@]} - 1; i >= 0; i--)); do
        seen=0
        for x in "${keys[@]+"${keys[@]}"}"; do
            if [ "$x" = "${L_KEY[i]}" ]; then seen=1; break; fi
        done
        [ "$seen" -eq 1 ] || keys+=("${L_KEY[i]}")
    done

    say "${PREFIX}Restoring from $RESTORE_DIR"
    problems=0
    for k in "${keys[@]+"${keys[@]}"}"; do
        restore_key "$k" || problems=$((problems + 1))
    done

    say ""
    if [ "$problems" -gt 0 ]; then
        say "${PREFIX}Restore incomplete: $problems problem(s), see above. $RESTORE_DIR is not marked as restored; fix the problems and run --restore $RESTORE_DIR again."
    else
        [ "$DRY_RUN" -eq 1 ] || date '+%Y-%m-%d %H:%M:%S' > "$RESTORE_DIR/restored"
        say "${PREFIX}Restore finished."
    fi
    say "Packages and vim plugins are not removed. Empty directories created by the install and the backup directory itself are kept."
    if [ "$OS" = windows ]; then
        say "Not restored (install.ps1): PowerShell profile backups in $BACKUP_ROOT/<timestamp>/_documents/ and Windows Terminal settings.json.bak-<timestamp>; move them back by hand."
    fi
    [ "$problems" -eq 0 ] || exit 1
    exit 0
fi

REPO_SHOWN=${DOTFILES_PREVIEW_OF:-$REPO}
say "${PREFIX}dotfiles setup: repo $REPO_SHOWN, home $HOME, mode $MODE"

# =============================================================================
# 1. update the checkout
# =============================================================================
step "Repository"
if [ "$NO_PULL" -eq 1 ]; then
    act skip "git pull" "--no-pull"
elif ! have git || ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    act skip "git pull" "not a git checkout"
elif [ -n "$(git -C "$REPO" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    warn "$REPO has local changes; not pulling"
elif ! git -C "$REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    warn "$REPO: current branch has no upstream; not pulling"
elif [ "$DRY_RUN" -eq 1 ]; then
    act pull "$REPO" "would run git pull --ff-only"
else
    pull_ssh=${GIT_SSH_COMMAND:-}
    if [ -z "$pull_ssh" ] && [ -z "$(git -C "$REPO" config core.sshCommand 2>/dev/null || true)" ]; then
        pull_ssh=$(git_ssh_candidates | head -n 1)
    fi
    before_head=$(git -C "$REPO" rev-parse --short HEAD)
    before_sum=$(file_sum "$REPO/install.sh")
    if GIT_SSH_COMMAND=$pull_ssh GIT_TERMINAL_PROMPT=0 with_timeout 60 \
           git -C "$REPO" pull -q --ff-only; then
        after_head=$(git -C "$REPO" rev-parse --short HEAD)
        if [ "$after_head" = "$before_head" ]; then
            act ok "git pull" "already up to date"
        else
            act updated "git pull" "$before_head -> $after_head"
            CHANGES+=("repository updated ($before_head -> $after_head)")
            if [ "$(file_sum "$REPO/install.sh")" != "$before_sum" ]; then
                say "install.sh changed; restarting it."
                export DOTFILES_REPO_UPDATED="$before_head -> $after_head"
                exec bash "$REPO/install.sh" --no-pull "${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}"
            fi
        fi
    else
        warn "git pull --ff-only failed in $REPO (offline, diverged or no access); continuing with the current checkout"
    fi
fi

# =============================================================================
# 2. dependencies
# =============================================================================
# bash-completion is a file, not a command
completion_present() {
    local f
    for f in /usr/share/bash-completion/bash_completion /etc/bash_completion \
             /usr/local/share/bash-completion/bash_completion \
             /opt/homebrew/etc/profile.d/bash_completion.sh \
             /home/linuxbrew/.linuxbrew/etc/profile.d/bash_completion.sh; do
        [ -f "$f" ] && return 0
    done
    return 1
}

starship_present() { have starship || [ -x "$HOME/.local/bin/starship" ]; }

dep_present() {
    case $1 in
        bash-completion) completion_present ;;
        starship)        starship_present ;;
        *)               have "$1" ;;
    esac
}

# pkg_name PM DEP: package name of DEP for package manager PM
pkg_name() {
    case $1:$2 in
        dnf:vim)   echo vim-enhanced ;;
        brew:mc)   echo midnight-commander ;;
        brew:bash-completion) echo bash-completion@2 ;;
        *)         echo "$2" ;;
    esac
}

# apt_lists_missing: the apt package lists were never downloaded (fresh
# container/VM); apt-cache then knows no candidates at all
apt_lists_missing() { ! compgen -G '/var/lib/apt/lists/*Packages*' >/dev/null; }

# pkg_available PM PKG: the package can be installed from the configured repos
pkg_available() {
    case $1 in
        apt-get) apt-cache policy "$2" 2>/dev/null | sed -n 's/^ *Candidate: *//p' | grep -qv '(none)' ;;
        dnf)     dnf -q info "$2" >/dev/null 2>&1 ;;
        pacman)  pacman -Si "$2" >/dev/null 2>&1 ;;
        zypper)  zypper -q info "$2" 2>/dev/null | grep -q '^Name' ;;
        brew)    brew info "$2" >/dev/null 2>&1 ;;
        *)       return 1 ;;
    esac
}

# get_root: sets SUDO ("" when root, "sudo" when sudo works); fails without root
ROOT_CHECKED=0
ROOT_OK=0
SUDO=
get_root() {
    if [ "$ROOT_CHECKED" -eq 1 ]; then [ "$ROOT_OK" -eq 1 ]; return; fi
    ROOT_CHECKED=1
    if [ "${DOTFILES_NO_SUDO:-0}" = 1 ]; then
        say "DOTFILES_NO_SUDO=1: acting as if root were not available"
    elif [ "$(id -u)" -eq 0 ]; then
        ROOT_OK=1; SUDO=
    elif have sudo; then
        if [ "$DRY_RUN" -eq 1 ]; then
            ROOT_OK=1; SUDO=sudo        # assume it would work; do not prompt
        else
            say "sudo is needed to install packages (enter your password, or Ctrl-C to skip):"
            if sudo -v; then ROOT_OK=1; SUDO=sudo; fi
        fi
    fi
    [ "$ROOT_OK" -eq 1 ]
}

install_starship_user() {
    local bin=$HOME/.local/bin
    if ! have curl; then
        warn "starship: cannot install it into $bin (curl missing)"
        return 0
    fi
    act install starship "official installer into $bin"
    if [ "$DRY_RUN" -eq 1 ]; then
        say "${PREFIX}  curl -fsSL $STARSHIP_INSTALLER | sh -s -- -y -b \"$bin\""
        return 0
    fi
    mkdir -p -- "$bin"
    # the installer's stdout is a long list of shell setup hints; .bashrc
    # already initialises starship, so only errors are shown
    if curl -fsSL "$STARSHIP_INSTALLER" | sh -s -- -y -b "$bin" >/dev/null; then
        CHANGES+=("starship installed into $bin")
    else
        warn "starship: the official installer failed"
    fi
}

deps_linux() {
    local deps=(git curl vim tmux bash-completion mc starship) d missing=()
    for d in "${deps[@]}"; do
        if dep_present "$d"; then act ok "$d"; else act missing "$d"; missing+=("$d"); fi
    done
    [ "${#missing[@]}" -gt 0 ] || return 0

    local pm=
    for c in apt-get dnf pacman zypper brew; do
        if have "$c"; then pm=$c; break; fi
    done

    local pkgs=() starship_user=0 starship_recheck=0 p
    if [ -z "$pm" ]; then
        warn "no supported package manager found (apt-get, dnf, pacman, zypper, brew); install yourself: ${missing[*]}"
        for d in "${missing[@]}"; do if [ "$d" = starship ]; then starship_user=1; fi; done
    else
        for d in "${missing[@]}"; do
            p=$(pkg_name "$pm" "$d")
            if [ "$d" = starship ] && ! pkg_available "$pm" "$p"; then
                if [ "$pm" = apt-get ] && apt_lists_missing; then
                    # decided again after apt-get update (below)
                    say "starship: apt package lists are empty; checking again after apt-get update"
                    starship_recheck=1
                else
                    say "starship is not available via $pm; it will be installed into ~/.local/bin"
                    starship_user=1
                    continue
                fi
            fi
            pkgs+=("$p")
        done
    fi

    if [ "${#pkgs[@]}" -gt 0 ]; then
        local cmd=()
        if [ "$pm" = brew ]; then
            cmd=(brew install "${pkgs[@]}")
        elif get_root; then
            case $pm in
                apt-get) cmd=(apt-get install -y "${pkgs[@]}") ;;
                dnf)     cmd=(dnf install -y "${pkgs[@]}") ;;
                pacman)  cmd=(pacman -S --needed --noconfirm "${pkgs[@]}") ;;
                zypper)  cmd=(zypper --non-interactive install "${pkgs[@]}") ;;
            esac
            [ -n "$SUDO" ] && cmd=("$SUDO" "${cmd[@]}")
        fi
        if [ "${#cmd[@]}" -eq 0 ]; then
            # without root: starship goes to ~/.local/bin, the rest is reported
            local sys=()
            for p in "${pkgs[@]}"; do
                if [ "$p" = starship ]; then starship_user=1; else sys+=("$p"); fi
            done
            if [ "${#sys[@]}" -gt 0 ]; then
                warn "no root access: missing system packages not installed: ${sys[*]} (ask an admin: $pm install ${sys[*]})"
            fi
        else
            if [ "$pm" = apt-get ]; then
                act run "${SUDO:+$SUDO }apt-get update"
                run ${SUDO:+"$SUDO"} apt-get update -q || warn "apt-get update failed"
                if [ "$starship_recheck" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] && ! pkg_available apt-get starship; then
                    say "starship is not available via apt-get; it will be installed into ~/.local/bin"
                    starship_user=1
                    local rest=()
                    for p in "${pkgs[@]}"; do [ "$p" = starship ] || rest+=("$p"); done
                    pkgs=("${rest[@]+"${rest[@]}"}")
                    cmd=(${SUDO:+"$SUDO"} apt-get install -y "${pkgs[@]+"${pkgs[@]}"}")
                    [ "${#pkgs[@]}" -gt 0 ] || cmd=()
                fi
            fi
            [ "${#cmd[@]}" -eq 0 ] || act run "${cmd[*]}"
            if [ "$DRY_RUN" -eq 0 ] && [ "${#cmd[@]}" -gt 0 ]; then
                if "${cmd[@]}"; then
                    CHANGES+=("packages installed: ${pkgs[*]}")
                else
                    warn "package installation failed: ${cmd[*]}"
                    for p in "${pkgs[@]}"; do if [ "$p" = starship ]; then starship_user=1; fi; done
                fi
            fi
        fi
    fi

    if [ "$starship_user" -eq 1 ] && ! starship_present; then
        install_starship_user
    fi
}

deps_windows() {
    if have pacman && [ -n "${MSYSTEM:-}" ]; then
        # MSYS2 (Git for Windows has no pacman)
        local d missing=()
        for d in tmux vim mc bash-completion; do
            if { [ "$d" = bash-completion ] && completion_present; } || have "$d"; then
                act ok "$d"
            else
                act missing "$d"; missing+=("$d")
            fi
        done
        if [ "${#missing[@]}" -gt 0 ]; then
            act run "pacman -S --needed --noconfirm ${missing[*]}"
            if [ "$DRY_RUN" -eq 0 ]; then
                if pacman -S --needed --noconfirm "${missing[@]}"; then
                    CHANGES+=("MSYS2 packages installed: ${missing[*]}")
                else
                    warn "pacman failed: ${missing[*]}"
                fi
            fi
        fi
    else
        act skip packages "Git Bash: packages are installed by install.ps1 (winget)"
    fi
}

step "Packages"
if [ "$NO_PACKAGES" -eq 1 ]; then
    act skip packages "--no-packages"
elif [ "$OS" = windows ]; then
    deps_windows
else
    deps_linux
fi

# =============================================================================
# 3. dotfiles
# =============================================================================
step "Dotfiles"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=$BACKUP_ROOT/$STAMP
n=1
while [ -e "$BACKUP" ]; do n=$((n + 1)); BACKUP=$BACKUP_ROOT/$STAMP-$n; done
BACKUP_CREATED=0
BACKED_UP=()
INSTALLED=0
FAILED=0   # dotfiles that could not be installed (exit code 1)

ensure_backup() {
    [ "$BACKUP_CREATED" -eq 1 ] && return 0
    BACKUP_CREATED=1
    [ "$DRY_RUN" -eq 1 ] && return 0
    mkdir -p -- "$BACKUP"
    {
        printf '# dotfiles install.sh %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf '# repo=%s\n# mode=%s\n# home=%s\n' "$REPO" "$MODE" "$HOME"
        printf '# action<TAB>key<TAB>target<TAB>source<TAB>checksum\n'
        printf '# actions: backup (original moved here), link/copy (installed), rollback (install failed, original put back)\n'
    } > "$BACKUP/installed.list"
}

# log ACTION KEY TARGET [SRC [SUM]]: append a line to installed.list
log() {
    [ "$DRY_RUN" -eq 0 ] || return 0
    printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:--}" "${5:--}" >> "$BACKUP/installed.list"
}

REPO_REAL=$(resolve "$REPO")
REPO_REAL=${REPO_REAL:-$REPO}

# install_one SRC TARGET KEY: KEY is the relpath used in the backup and log
install_one() {
    local src=$1 target=$2 key=$3 label=$MODE detail="" backed=0 parent
    [ -f "$src" ] || { warn "missing in repo: $src"; return 0; }

    # a parent directory (e.g. ~/.vim) is a symlink into the repository:
    # the target is the repository file itself
    if exists "$target" && [ ! -L "$target" ] && [ "$target" -ef "$src" ]; then
        act ok "$key" "parent directory links into the repository"
        return 0
    fi
    # ... or into some other place in the repository: never move or create
    # files there
    parent=$(real_parent "$target")
    if inside "$REPO_REAL" "$parent"; then
        warn "$key: $(dirname -- "$target") resolves into the repository ($parent); not touched. Replace that symlinked directory by a real one."
        FAILED=$((FAILED + 1))
        return 0
    fi

    if exists "$target" && is_ours "$MODE" "$src" "$target"; then
        act ok "$key"
        return 0
    fi

    ensure_backup
    if exists "$target"; then
        detail="was: $(describe "$target")"
        label=backup+$MODE
        run mkdir -p -- "$(dirname -- "$BACKUP/$key")"
        if ! run mv -- "$target" "$BACKUP/$key"; then
            warn "$key: could not move $target to $BACKUP; skipped"
            FAILED=$((FAILED + 1))
            return 0
        fi
        log backup "$key" "$target"
        BACKED_UP+=("$key")
        backed=1
    fi
    act "$label" "$key" "$detail"
    if ! { run mkdir -p -- "$(dirname -- "$target")" &&
           if [ "$MODE" = link ]; then run ln -s -- "$src" "$target"; else run cp -p -- "$src" "$target"; fi; }; then
        if [ "$backed" -eq 1 ] && ! exists "$target" && mv -- "$BACKUP/$key" "$target"; then
            log rollback "$key" "$target"
            unset 'BACKED_UP[${#BACKED_UP[@]}-1]'
            warn "$key: installing $target failed; the original was put back"
        elif [ "$backed" -eq 1 ]; then
            warn "$key: installing $target failed; the original is in $BACKUP/$key (undo: --restore $BACKUP)"
        else
            warn "$key: installing $target failed"
        fi
        FAILED=$((FAILED + 1))
        return 0
    fi
    INSTALLED=$((INSTALLED + 1))
    if [ "$MODE" = copy ]; then
        log copy "$key" "$target" "$src" "$(run file_hash "$target")"
    else
        log link "$key" "$target" "$src"
    fi
}

files=("${MANIFEST[@]}")
[ "$OS" = linux ] && files+=("${MANIFEST_LINUX[@]}")
for rel in "${files[@]}"; do
    install_one "$REPO/$rel" "$HOME/$rel" "$rel"
done
if [ "$INSTALLED" -gt 0 ]; then
    CHANGES+=("$INSTALLED dotfile(s) installed")
fi

# =============================================================================
# 4. vim plugins
# =============================================================================
# plugin directory names from the Plug lines of .vimrc
vim_plugins() { sed -n "s/^Plug '[^']*\/\([^'/]*\)'.*/\1/p" "$REPO/.vimrc"; }
PLUGGED=$HOME/.vim/plugged
fzf_bin_present() { compgen -G "$PLUGGED/fzf/bin/fzf*" >/dev/null; }
vim_batch() {
    # TERM=dumb disables the autoinstall in .vimrc; stdin from /dev/null
    # because vim -es reads Ex commands from stdin
    TERM=dumb with_timeout 600 vim -N -u "$HOME/.vimrc" -i NONE -es "$@" '+qa!' </dev/null
}

# snapshot_pins: "name commit" per plugin from the snapshot
SNAPSHOT=$REPO/.vim/plug-snapshot.vim
snapshot_pins() {
    sed -n "s/^silent! let g:plugs\['\([^']*\)'\]\.commit = '\([0-9a-f]\{7,\}\)'.*/\1 \2/p" "$SNAPSHOT"
}
# off_pin: plugins whose checkout is not at the snapshot commit (space-separated)
off_pin() {
    local name commit head
    while read -r name commit; do
        head=$(git -C "$PLUGGED/$name" rev-parse HEAD 2>/dev/null || true)
        [ "$head" = "$commit" ] || printf '%s ' "$name"
    done < <(snapshot_pins)
}

# pin_plugins: check the plugins out at the snapshot commits (--pinned)
pin_plugins() {
    local off still
    if [ ! -f "$SNAPSHOT" ]; then warn "--pinned: $SNAPSHOT not found"; return 0; fi
    off=$(off_pin); off=${off% }
    if [ -z "$off" ]; then
        act ok "pinned" "$(snapshot_pins | wc -l | tr -d ' ') plugins at the snapshot commits"
        return 0
    fi
    act pin "vim plugins" "$off -> commits from plug-snapshot.vim"
    [ "$DRY_RUN" -eq 0 ] || return 0
    # the snapshot ends with PlugUpdate!, which checks out g:plugs[*].commit
    vim_batch -S "$SNAPSHOT" || warn "vim (plug-snapshot.vim) returned an error (exit $?)"
    still=$(off_pin); still=${still% }
    if [ -n "$still" ]; then
        warn "vim plugins not at the snapshot commits: $still"
    else
        CHANGES+=("vim plugins pinned to plug-snapshot.vim: $off")
    fi
}

step "Vim plugins"
if [ "$NO_VIM" -eq 1 ]; then
    act skip "vim plugins" "--no-vim"
elif ! have vim; then
    act skip "vim plugins" "vim not installed"
elif ! have git; then
    act skip "vim plugins" "git not installed"
else
    missing_plugins=()
    while IFS= read -r p; do
        [ -d "$PLUGGED/$p" ] || missing_plugins+=("$p")
    done < <(vim_plugins)
    if [ "${#missing_plugins[@]}" -eq 0 ]; then
        act ok "vim plugins" "$(vim_plugins | wc -l | tr -d ' ') installed"
    else
        act install "vim plugins" "${missing_plugins[*]}"
        if [ "$DRY_RUN" -eq 0 ]; then
            vim_batch '+PlugInstall --sync' || warn "vim PlugInstall returned an error (exit $?)"
            still=()
            while IFS= read -r p; do
                [ -d "$PLUGGED/$p" ] || still+=("$p")
            done < <(vim_plugins)
            if [ "${#still[@]}" -gt 0 ]; then
                warn "vim plugins still missing: ${still[*]}"
            else
                CHANGES+=("vim plugins installed: ${missing_plugins[*]}")
            fi
        fi
    fi
    if [ -d "$PLUGGED/fzf" ] || [ "$DRY_RUN" -eq 1 ]; then
        if fzf_bin_present; then
            act ok "fzf binary"
        elif have fzf; then
            act ok "fzf binary" "from PATH: $(command -v fzf)"
        else
            act install "fzf binary" "fzf#install()"
            if [ "$DRY_RUN" -eq 0 ]; then
                vim_batch '+call fzf#install()' || true
                if fzf_bin_present; then
                    CHANGES+=("fzf binary downloaded")
                else
                    warn "fzf binary missing in $PLUGGED/fzf/bin (in vim: :call fzf#install())"
                fi
            fi
        fi
    fi
    if [ "$PINNED" -eq 1 ]; then pin_plugins; fi
fi

# =============================================================================
# 5. summary
# =============================================================================
step "Summary"
if [ "${#CHANGES[@]}" -eq 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        say "[dry-run] see above for what would change."
    else
        say "Everything is in place; nothing changed."
    fi
else
    for c in "${CHANGES[@]}"; do
        if [ "$DRY_RUN" -eq 1 ]; then say "- would change: $c"; else say "- changed: $c"; fi
    done
fi
if [ "$DRY_RUN" -eq 1 ]; then
    if [ "${#BACKED_UP[@]}" -gt 0 ]; then say "[dry-run] Originals would be moved to $BACKUP"; fi
elif [ "${#BACKED_UP[@]}" -gt 0 ]; then
    say "Originals moved to $BACKUP (undo: $REPO_SHOWN/install.sh --restore)"
elif [ "$INSTALLED" -gt 0 ]; then
    say "Log: $BACKUP/installed.list (undo: $REPO_SHOWN/install.sh --restore)"
fi
for w in "${WARNINGS[@]+"${WARNINGS[@]}"}"; do say "- warning: $w"; done

say ""
say "Notes:"
say "- git: host-specific settings (editor, difftools, credentials, includeIf) go into ~/.overwrites/gitconfig."
if [ "$OS" != windows ] && [ "$INSTALLED" -gt 0 ]; then
    say "- tmux: the new config takes effect when the next tmux server starts (running servers are not reloaded)."
fi
for k in "${BACKED_UP[@]+"${BACKED_UP[@]}"}"; do
    if [ "$k" = .bashrc ]; then
        say "- Your old ~/.bashrc is in $BACKUP/.bashrc: move host-specific parts to ~/.overwrites/bashrc.sh."
    fi
done
if [ -d "$HOME/.cfg" ]; then
    say "- ~/.cfg (legacy bare repository from 2018) still exists; it was not touched. Remove it yourself when no longer needed."
fi
if [ "${#CHANGES[@]}" -gt 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    say "- Open a new shell (or: exec bash -l) to pick up the changes."
fi
[ "$FAILED" -eq 0 ] || exit 1
