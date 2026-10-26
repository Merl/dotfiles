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
| `.vimrc`, `.vim/` | Vim; plugins via vim-plug (vendored `.vim/autoload/plug.vim`; tested commits in `.vim/plug-snapshot.vim`, applied with `install.sh --pinned` or `vim -S ~/.vim/plug-snapshot.vim`) |
| `.config/mc/ini` | Midnight Commander; `auto_save_setup=false` so mc doesn't rewrite the repo file on exit (save on purpose with F9 › Options › Save setup). `panels.ini` is runtime state and not managed |
| `.gitconfig`, `.selected_editor` | git, Debian editor choice |
| `.config/weechat/` | WeeChat (Linux; see below) |

## WeeChat

`~/.config/weechat` is a symlink to the whole directory in the repo, because WeeChat replaces its `.conf` files on save (write + rename), which would break single-file links. `/set …` + `/save` therefore changes the repo work tree: `config diff` shows it, `config sync` commits and pushes it (while it is uncommitted, `install.sh` does not pull).

- Servers: Libera.Chat, QuakeNet, IRCNet, EuIRC; connect directly (TLS except QuakeNet), autoconnect on, nicks `Merl[DT]`, `Merl[]`.
- No secrets in the repo: passwords go into WeeChat's secured data (`/secure set libera_pw …`, then e.g. `/set irc.server.libera.sasl_password "${sec.data.libera_pw}"`); `sec.conf` is git-ignored and stays on the host.
- Scripts (`install.sh` downloads them from weechat.org into `~/.local/share/weechat` and autoloads them, if weechat is installed): highmon, screen_away (away while tmux is detached), queryman, whois_on_query, tmux_env.
- A legacy `~/.weechat` takes precedence over `~/.config/weechat`; `install.sh` warns while it exists.

Useful keys: `Alt+1…0` / `Alt+j NN` buffer, `Alt+←/→` previous/next buffer, `Alt+a` next buffer with activity, `Alt+w`+arrow switch window, `Alt+z` zoom window, `Alt+l` bare display (for copying), `F1`/`F2` scroll buffer list, `F11`/`F12` nicklist, `Ctrl+r` search. In tmux `C-a` is the prefix: use `Home` (or `C-a a`) for beginning of line.

## Aliases (`.bash_aliases`)

Deliberately few shortcuts, and none shadows a real program (hence no `gs` for ghostscript, no `as`, no `ash`).

| Area | Shortcuts |
|---|---|
| Navigation | `ll` `l` `la` `..` `...` `....` `-` `md` `c` `h` |
| Editor | `v` (vim), `svim` (sudoedit) |
| ssh | `s` = `ssh -l root` |
| git | `g` `gst` `ga` `gap` `gc` `gca` `gco` `gsw` `gb` `gd` `gds` `gl` `gf` `gpl` `gp` `gcl` |
| dotfiles | `config <git command>` runs git in the dotfiles checkout from anywhere (`config status`, `config diff`); `config check` compares the home copies with the checkout (`install.sh --check`); `config sync [message]` commits all changes, pulls (rebase) and pushes to every remote. Where the dotfiles are copies (Windows), `sync` first takes edited home copies into the checkout (`install.sh --adopt`; a conflict stops it before anything is committed) and at the end runs the installer to refresh the copies. Also in the PowerShell profile. The checkout is found via the `~/.bashrc` link (PowerShell: the profile link), `$DOTFILES_DIR`, or `~/.config/dotfiles/checkout` (written by `install.sh`) |
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
- Symlinks or copies: see [Links and copies on Windows](#links-and-copies-on-windows). Copies can be edited in place; `config sync` takes the edits into the checkout.

### PowerShell (7 and 5.1) and Windows Terminal

- `windows/Microsoft.PowerShell_profile.ps1` is shared by PowerShell 7 and Windows PowerShell 5.1 and goes to `<Documents>\PowerShell\` and `<Documents>\WindowsPowerShell\` (`[Environment]::GetFolderPath('MyDocuments')`); keep it ASCII-only for 5.1. It uses the same `~/.config/starship.toml`, PSReadLine history search on Up/Down, and a subset of the shortcuts as functions (`glg` instead of `gl`; `gc`, `gp`, `gl` are built-in PowerShell aliases). Host-local additions: `~/.overwrites/profile.ps1`.
- `install.ps1` installs the prerequisites (Starship, JetBrainsMono Nerd Font) and the profile, and configures Windows Terminal: font `JetBrainsMono NF` in `profiles.defaults`, PowerShell 7 as default profile, an SSH profile using `C:\Windows\System32\OpenSSH\ssh.exe` (the ssh agent runs there).

## Remotes

| Name | Target |
|---|---|
| `origin` | `ssh://git@git.shelltec.de:2222/merl/dotfiles.git` (Forgejo, private) |
| `github` | `git@github.com:Merl/dotfiles.git` |

Changes are pushed to both.

## Installation

One command per host; it fetches the repository and everything it needs. Every step is idempotent: running it again changes nothing when all is in place and otherwise only fixes what is missing or different.

**Linux** (also Git Bash/MSYS2):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Merl/dotfiles/master/install.sh)
bash <(curl -fsSL https://raw.githubusercontent.com/Merl/dotfiles/master/install.sh) --dry-run   # preview
```

**Windows** (PowerShell 5.1 or 7):

```powershell
irm https://raw.githubusercontent.com/Merl/dotfiles/master/install.ps1 | iex
```

Later runs from the checkout: `~/.dotfiles/install.sh [options]`, or on Windows `powershell -ExecutionPolicy Bypass -File $HOME\.dotfiles\install.ps1 [options]`.

### `install.sh`

Run it as your normal user, not with `sudo` (it refuses to run under sudo with a non-root `HOME`; it calls sudo itself for the packages).

1. **Repository.** Run outside a checkout (as in the one-liner), it clones to `$DOTFILES_DIR` (default `~/.dotfiles`): from Forgejo if `git ls-remote` over ssh authenticates (BatchMode, `StrictHostKeyChecking=accept-new`; with `--dry-run` `StrictHostKeyChecking=yes`, so a dry run never adds a host key and an unknown host simply means GitHub; in Git Bash Windows OpenSSH is tried first and then stored as `core.sshCommand`), otherwise from GitHub over https. Then it runs the `install.sh` of that checkout. An existing `$DOTFILES_DIR` is only used if one of its remotes is this repository (Forgejo or GitHub `Merl/dotfiles`, ssh or https, or `DOTFILES_REPO_URL`) and it contains `install.sh`; otherwise the bootstrap stops and asks to move it away or set `DOTFILES_DIR`. Inside a checkout it runs `git pull --ff-only` (skipped with a warning when the work tree has local changes, the branch has no upstream, or the pull fails) and restarts itself if `install.sh` changed.
2. **Packages** (Linux): git, curl, vim, tmux, bash-completion, mc, starship. Only missing ones are installed, in one call of apt-get (with `apt-get update` first), dnf, pacman, zypper or brew. If apt has never downloaded its package lists (fresh container/VM), whether starship comes from apt is decided after `apt-get update`. Root: directly as root, otherwise `sudo -v` (asks for the password). Without root, missing system packages are reported and the run continues. starship is installed into `~/.local/bin` with the official installer when the package manager has no package for it or there is no root. Git Bash: nothing (`install.ps1` uses winget); MSYS2 with pacman: tmux, vim, mc, bash-completion.
3. **Dotfiles:** an explicit list of files from the repo into `$HOME`.
   - **Linux:** symlinks to the repo, so `git pull` updates them; `--copy` forces copies. **Windows (Git Bash/MSYS2/Cygwin):** symlinks or copies, see [Links and copies on Windows](#links-and-copies-on-windows).
   - Already installed (our symlink, or an identical copy) → `ok`. Anything else in the way is moved to `~/.dotfiles-backup/<YYYYmmdd-HHMMSS>/<path>` first; `installed.list` there logs what was done (each move right after it happened, and each installed copy with its SHA-256). The backup directory is only created when something changes. If installing a file fails after the move, the original is put back at once (or stays restorable with `--restore`), the run continues and exits with status 1.
   - A parent directory that is a symlink into the repository (e.g. `~/.vim -> ~/.dotfiles/.vim`) is fine: the files are then the repository files themselves (`ok`). A parent that resolves to some other place inside the repository is refused with a warning; nothing is moved or created inside the repository.
   - `.gitconfig` is installed too; host-specific git settings (editor, difftools, credential helpers, `includeIf`) belong in `~/.overwrites/gitconfig`, which it includes last.
   - `.config/weechat` is a directory and is only linked on Linux (skipped with `--copy`).
   - Not installed: `.selected_editor` outside Linux, `README.md`, `.gitattributes`, `.gitignore`, `windows/` (see `install.ps1`).
4. **Vim plugins:** if a plugin from `.vimrc` is missing in `~/.vim/plugged`, `vim -es '+PlugInstall --sync'` runs headless (timeout 600 s) and installs the newest version; if the fzf binary is still missing, `fzf#install()`. Plugins that are already there are not updated (`:PlugUpdate` in vim). With `--pinned`, all plugins are then checked out at the commits in `~/.vim/plug-snapshot.vim` (headless `vim -S plug-snapshot.vim`; `ok` when they already are). To go back to the newest versions: `:PlugUpdate`.
5. **WeeChat scripts** (Linux, only if `weechat` is installed): missing scripts from the list in `install.sh` are downloaded from weechat.org into `~/.local/share/weechat/<language>/` and linked into `autoload/`. Installed scripts are not updated (`/script update` + `/script upgrade` in WeeChat).
6. **Summary** of what changed, warnings, and hints (tmux config applies at the next tmux server start; running servers are not reloaded; host-specific parts of an old `~/.bashrc` go to `~/.overwrites/bashrc.sh`).

| Option | |
|---|---|
| `-n`, `--dry-run` | show what would happen, change nothing (the bootstrap previews from a temporary clone) |
| `--link` | symlinks (default on Linux; on Windows they need Developer Mode or admin rights, else the run stops) |
| `--copy` | copies instead of symlinks |
| `--check` | compare the recorded copies with the checkout (see below); read-only, exit status 1 on a conflict |
| `--adopt` | take edited home copies into the checkout (see below); changes nothing if there is a conflict; works with `--dry-run` |
| `--no-packages` | skip the package step |
| `--no-vim` | skip the vim plugins |
| `--no-pull` | do not update the checkout |
| `--pinned` | check the vim plugins out at the commits in `.vim/plug-snapshot.vim` (default: newest) |
| `--restore [DIR]` | undo a run (default: newest not yet restored backup): removes our links/copies (a copy is recognised by the checksum logged at install time, so this also works after the repository changed; a file changed since is left alone with a warning) and moves the originals back. Older runs are undone one after the other with further `--restore` calls. The backup is only marked as restored when everything worked; otherwise it says what is left and can be run again. Works with `--dry-run`. |

`--restore` covers the home dotfiles only. Not restored: packages, vim plugins, and what `install.ps1` changed on Windows: PowerShell profile backups in `~/.dotfiles-backup/<timestamp>/_documents/...` (move them back to `<Documents>\PowerShell\` / `<Documents>\WindowsPowerShell\` by hand) and Windows Terminal backups `settings.json.bak-<timestamp>` next to `settings.json` (copy back by hand).

### Links and copies on Windows

On Windows a symlink needs Developer Mode (Settings > System > For developers) or admin rights. `install.sh` and `install.ps1` decide the same way:

1. `--link` / `--copy` (`install.ps1 -Link` / `-Copy`, or `DOTFILES_LINK=1` / `DOTFILES_COPY=1` for `irm | iex`),
2. else the choice remembered in `~/.config/dotfiles/mode` (`link` or `copy`),
3. else, if a probe in a temporary directory can create a symlink and the run is interactive (a terminal, no `--dry-run`), the question *Use symlinks instead of copies? [Y/n]*,
4. else copies, with a note in the summary (how to enable Developer Mode, or that `--link` would work).

An option or an answer is remembered in `~/.config/dotfiles/mode`; the fallback in 4. is not, so a later run asks once symlinks have become possible. `install.ps1` decides first and passes `--link`/`--copy` on to `install.sh`. In link mode `install.sh` creates real NTFS symlinks (`MSYS=winsymlinks:nativestrict`, never MSYS' copy fallback) and `install.ps1` links both PowerShell profiles to `windows/Microsoft.PowerShell_profile.ps1` in the checkout. A remembered `link` on a host where symlinks do not work falls back to copies with a warning; an explicit `--link` stops instead. Switching works in both directions: what is in the way (a copy, or a link when switching to copies) is backed up to `~/.dotfiles-backup/<timestamp>/` and replaced.

**Copies can be edited in place.** Every copy is recorded in `~/.config/dotfiles/copies.list` (`install.sh` its files, `install.ps1` the two profiles): source relative to the checkout, target (on Windows as `C:/Users/...`), SHA-256 as installed; links and removed files drop out of it. `install.sh --check` (`config check`, `install.ps1 -Check`) compares each copy (H) and its checkout file (R) with the recorded checksum (S); `install.sh --adopt` (`install.ps1 -Adopt`, and the first step of `config sync` where the dotfiles are copies) acts on it:

| State | `--check` reports | `--adopt` |
|---|---|---|
| H = S, R = S | unchanged | nothing |
| H = S, R ≠ S | checkout newer (e.g. after a pull) | nothing; the next install refreshes the copy |
| H ≠ S, R = S | home copy changed | copies the home file into the checkout (`cp -p`), updates S |
| H = R, S differs | in sync | updates S |
| H ≠ S, R ≠ S, H ≠ R | **conflict** (both paths shown) | nothing at all; exit status 1 |
| target missing, or now a link | missing / skip | nothing |

Copies of one source (the two PowerShell profiles): if only one changed, or both the same way, that change is adopted; changed differently is a conflict. `--adopt` only writes to plain files inside the checkout (no `..`, no symlinked directories) and respects `--dry-run`. A plain install still replaces an edited copy (with a warning; the edited version is in the backup), so take edits in with `config sync` or `--adopt` first. `--restore` removes the copies it takes away from `copies.list`.

Environment: `DOTFILES_DIR` (checkout location), `DOTFILES_REPO_URL` (clone source instead of Forgejo/GitHub, e.g. `file:///tmp/dotfiles` for tests), `DOTFILES_NO_SUDO=1` (act as if there were no root, for tests).

### `install.ps1` (Windows)

Runs on Windows PowerShell 5.1 and PowerShell 7 (ASCII-only file). Steps:

1. **winget:** `Git.Git`, `Starship.Starship`, `DEVCOM.JetBrainsMonoNerdFont`; only missing ones are installed, then `PATH` is reloaded from the registry. Without winget it says how to get it.
2. **Repository:** invoked via `irm | iex` (no script file) it clones to `$HOME\.dotfiles` (Forgejo via Windows OpenSSH if that authenticates, else GitHub; a dry run previews from a temporary clone that is removed afterwards, also on Ctrl-C) or updates an existing checkout, then runs the checkout's `install.ps1` in a child process (`-ExecutionPolicy Bypass`); that one prints the summary including what the bootstrap did. Run from a checkout, the `git pull --ff-only` (as in `install.sh`) comes first, before winget, and if it changed `install.ps1`, the new version is started with the same options (without pulling again).
3. **PowerShell profile:** `windows/Microsoft.PowerShell_profile.ps1` is linked (link mode) or copied to `<Documents>\PowerShell\` and `<Documents>\WindowsPowerShell\`; a different existing file (or link) is moved to `$HOME\.dotfiles-backup\<timestamp>\_documents\...` first. Copies are recorded in `copies.list`. Links or copies: see [Links and copies on Windows](#links-and-copies-on-windows) (the question, if any, comes before winget).
4. **Windows Terminal** (`settings.json` of the Store, Preview and unpackaged versions): `profiles.defaults.font.face = "JetBrainsMono NF"`, a profile `serenity` running `C:\Windows\System32\OpenSSH\ssh.exe -A merl@serenity.shelltec.de`, and PowerShell 7 as `defaultProfile` if that profile exists. Written only if something differs, after a backup `settings.json.bak-<timestamp>`, as UTF-8 without BOM. A file with comments is not rewritten; the needed changes are listed instead.
5. **Git Bash:** `install.sh --no-packages --no-pull` (plus `--link`/`--copy` when a choice was made, `--pinned`, `--dry-run`) with the same `HOME` (dotfiles, vim plugins).

Errors (install.sh or a child run failed, clone failed) are listed in the summary; run as a file, the exit code is then 1. There is no `param()` block, so `irm | iex` leaves the caller's variables alone; when run as a file, the options are read from the arguments.

| Parameter | Environment variable (for `irm \| iex`) | |
|---|---|---|
| `-DryRun` | `DOTFILES_DRYRUN=1` | show what would happen |
| `-NoPackages` | `DOTFILES_NO_PACKAGES=1` | skip winget |
| `-NoTerminal` | `DOTFILES_NO_TERMINAL=1` | leave Windows Terminal alone |
| `-NoBash` | `DOTFILES_NO_BASH=1` | skip `install.sh` |
| `-Pinned` | `DOTFILES_PINNED=1` | vim plugins at the snapshot commits (`install.sh --pinned`) |
| `-Link` | `DOTFILES_LINK=1` | symlinks (needs Developer Mode or admin rights) |
| `-Copy` | `DOTFILES_COPY=1` | copies |
| `-Check` | | only `install.sh --check` via Git Bash (compare the copies with the checkout) |
| `-Adopt` | | only `install.sh --adopt` via Git Bash (with `-DryRun`: preview) |
| `-HomeDir` | `DOTFILES_HOME` | home directory (tests) |
| `-DocumentsDir` | `DOTFILES_DOCUMENTS` | Documents folder (tests) |
| `-TerminalSettings` | `DOTFILES_TERMINAL_SETTINGS` | one `settings.json` to edit (tests) |
| `-DotfilesDir` | `DOTFILES_DIR` | checkout location |
| | `DOTFILES_REPO_URL` | clone source (tests) |

Example: `$env:DOTFILES_DRYRUN = 1; irm https://raw.githubusercontent.com/Merl/dotfiles/master/install.ps1 | iex`

**Legacy (2018):** the repo used to be checked out as a bare repository `~/.cfg` with work tree `$HOME` (`alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'`; today `config` is a function for the normal checkout, see Aliases). `install.sh` does not use or touch `~/.cfg`; remove it manually once the new setup works.
