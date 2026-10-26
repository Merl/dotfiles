# dotfiles

Login, shell, tmux and vim configuration for my hosts (primarily `serenity`, Debian 13; also Windows/Git Bash).

> **Status: being rebuilt (October 2026).** The 2018 setup is being replaced with a leaner one. bash-it and the Powerline prompt are replaced by [Starship](https://starship.rs) and a small custom `.bash_aliases`; the tmux and vim configuration is being updated for current versions (tmux 3.5, Vim 9.1).

## Layout

The repository root mirrors `$HOME`: every file lives at the path it ends up at in the home directory.

| File | Purpose |
|---|---|
| `.bash_profile` | bash login shells: only sources `.profile` |
| `.profile` | login shell; sets PATH, sources `.bashrc` |
| `.bashrc` | interactive bash |
| `.bash_aliases` | aliases and small functions (see below) |
| `.inputrc` | readline: Up/Down search history for what has been typed |
| `.config/starship.toml` | Starship prompt (needs a Nerd Font) |
| `.tmux.conf`, `.tmuxline.conf` | tmux incl. status line |
| `.sbin/tmux-merl.sh` | `tm [session]`: attach to the tmux session (default `merl`) or create it; runs `~/.overwrites/tmux.sh` for new sessions |
| `.vimrc`, `.vim/` | Vim; plugins via vim-plug (vendored `.vim/autoload/plug.vim`, pinned commits in `.vim/plug-snapshot.vim`, restore with `vim -S ~/.vim/plug-snapshot.vim`) |
| `.config/mc/` | Midnight Commander |
| `.gitconfig`, `.selected_editor` | git, Debian editor choice |

## Aliases (`.bash_aliases`)

Deliberately few shortcuts, and none shadows a real program (hence no `gs` for ghostscript, no `as`, no `ash`).

| Area | Shortcuts |
|---|---|
| Navigation | `ll` `l` `la` `..` `...` `....` `-` `md` `c` `h` |
| Editor | `v` (vim), `svim` (sudoedit) |
| ssh | `s` = `ssh -l root` |
| git | `g` `gst` `ga` `gap` `gc` `gca` `gco` `gsw` `gb` `gd` `gds` `gl` `gf` `gpl` `gp` `gcl` |
| tmux | `tm` (attach/create `merl`), `txl` `txn` `txa` |
| systemd (Linux only) | `sc` `scs` `scu` `jf` `jb` |
| apt (Debian only) | `au` `aug` `ai` `aps` `apsh` |
| Functions | `mkcd dir`, `buf file…` (timestamped copy), `del file…` (move to trash), `ips`, `myip`, `command_exists cmd` |

Tab completion comes from the system package `bash-completion` (git, ssh, tmux, make, systemctl, apt).

Host-specific additions live outside the repo in `~/.overwrites/` (`bashrc.sh`, `tmux.sh`). tmux is not started automatically at login.

## Windows (Git Bash / MSYS2)

The same files work in Git for Windows' Git Bash and in MSYS2; home is `C:\Users\<user>`, vim uses `~/.vim`.

- tmux is not available there: `tm` reports it, `txl`/`txn`/`txa` are not defined. Use tmux on the server (or in WSL).
- Aliases that need `sudoedit`, `systemctl` or `apt` are only defined where these exist.
- Prompt: Starship if installed (`winget install Starship.Starship`), otherwise a fallback PS1 with the git branch.
- The fzf binary for vim is downloaded by vim-plug (do-hook), on Linux and Windows.
- Windows-specific settings (e.g. `GIT_SSH` pointing to Windows OpenSSH) belong in `~/.overwrites/bashrc.sh`.

## Remotes

| Name | Target |
|---|---|
| `origin` | `ssh://git@git.shelltec.de:2222/merl/dotfiles.git` (Forgejo, private) |
| `github` | `git@github.com:Merl/dotfiles.git` |

Changes are pushed to both.

## Installation

**Previously (2018):** bare repository in `$HOME`, no install script:

```sh
git clone --bare <url> ~/.cfg
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
config checkout          # aborts if e.g. ~/.bashrc already exists
config config status.showUntrackedFiles no
config submodule update --init
```

**New:** a reproducible install script is planned. It will back up existing files and not force-attach to tmux. Until then, use the steps above.
