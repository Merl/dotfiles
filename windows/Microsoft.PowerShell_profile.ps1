# PowerShell profile ($PROFILE.CurrentUserCurrentHost), shared by
# PowerShell 7 and Windows PowerShell 5.1. Deployed to:
#   <MyDocuments>\PowerShell\Microsoft.PowerShell_profile.ps1         (7)
#   <MyDocuments>\WindowsPowerShell\Microsoft.PowerShell_profile.ps1  (5.1)
# Keep this file ASCII-only: 5.1 reads files without BOM as ANSI.
# Counterpart of ~/.bashrc, ~/.inputrc and ~/.bash_aliases for Windows.
# Host-local additions (not in the repo): ~/.overwrites/profile.ps1

# --- Prompt: Starship with the same config as bash --------------------------
$env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship.toml'
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# --- PSReadLine (like ~/.inputrc) -------------------------------------------
if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -BellStyle None -HistoryNoDuplicates
    # Up/Down: search history for what has already been typed
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    # Tab: show all candidates as a menu (like show-all-if-ambiguous)
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

$env:EDITOR = 'vim'

# --- Shortcuts (subset of ~/.bash_aliases) ----------------------------------
# PowerShell aliases cannot take arguments, so these are functions. gc, gp
# and gl are built-in aliases (Get-Content, Get-ItemProperty, Get-Location)
# and are left alone.
function g    { git @args }
function gst  { git status -sb @args }
function ga   { git add @args }
function gap  { git add -p @args }
function gco  { git checkout @args }
function gsw  { git switch @args }
function gb   { git branch -vv @args }
function gd   { git diff @args }
function gds  { git diff --staged @args }
function glg  { git log --oneline --graph --decorate -20 @args }
function gf   { git fetch --all --prune @args }
function gpl  { git pull --ff-only @args }
function gcl  { git clone @args }

function ll   { Get-ChildItem -Force @args }
function ..   { Set-Location .. }
function ...  { Set-Location ..\.. }
function mkcd { param([Parameter(Mandatory)] [string] $Path)
                New-Item -ItemType Directory -Force -Path $Path | Out-Null
                Set-Location $Path }
function myip { (Invoke-RestMethod https://api.ipify.org).ToString() }
if (Get-Command vim -ErrorAction SilentlyContinue) {
    Set-Alias v vim
}

# config: git for the dotfiles checkout, from any directory (as in .bashrc).
# The checkout is where this profile links to, else $env:DOTFILES_DIR, else
# the path install.sh recorded in ~/.config/dotfiles/checkout, else
# ~/.dotfiles.
#   config status | diff | log ...  any git command
#   config check                    compare the copies with the checkout
#                                   (install.ps1 -Check)
#   config sync [message]           commit all changes, pull --rebase, push
#                                   to every remote, then install.ps1
#                                   refreshes the copies (this profile and
#                                   the Git Bash files); where this profile
#                                   is a copy, install.ps1 -Adopt first takes
#                                   edited copies into the checkout (a
#                                   conflict stops the sync)
function config {
    $f = Join-Path $HOME '.config\dotfiles\checkout'
    $p = if ($PROFILE) { Get-Item -LiteralPath $PROFILE -Force -ErrorAction SilentlyContinue }
    $linked = $p -and $p.LinkType -eq 'SymbolicLink'
    if ($linked) { $repo = Split-Path (Split-Path ([string](@($p.Target)[0]))) }
    elseif ($env:DOTFILES_DIR) { $repo = $env:DOTFILES_DIR }
    elseif (Test-Path $f) { $repo = (Get-Content $f -TotalCount 1).Trim() }
    else { $repo = Join-Path $HOME '.dotfiles' }
    $ps = (Get-Process -Id $PID).Path
    $installer = Join-Path $repo 'install.ps1'
    if ($args.Count -gt 0 -and $args[0] -eq 'check') {
        & $ps -NoProfile -ExecutionPolicy Bypass -File $installer -Check -DotfilesDir $repo
        return
    }
    if ($args.Count -eq 0 -or $args[0] -ne 'sync') { git -C $repo @args; return }
    if ($args.Count -gt 1) { $msg = $args[1..($args.Count - 1)] -join ' ' }
    else { $msg = "Update from $env:COMPUTERNAME" }
    if (-not $linked) {
        & $ps -NoProfile -ExecutionPolicy Bypass -File $installer -Adopt -DotfilesDir $repo
        if ($LASTEXITCODE) { Write-Host 'config sync: stopped, nothing committed (see above)'; return }
    }
    git -C $repo add -A; if ($LASTEXITCODE) { return }
    git -C $repo diff --cached --quiet
    if ($LASTEXITCODE) {
        git -C $repo diff --cached --stat
        git -C $repo commit -q -m $msg; if ($LASTEXITCODE) { return }
    }
    git -C $repo pull -q --rebase; if ($LASTEXITCODE) { return }
    foreach ($r in (git -C $repo remote)) {
        git -C $repo push -q $r HEAD; if ($LASTEXITCODE) { return }
    }
    git -C $repo log --oneline -1
    & $ps -NoProfile -ExecutionPolicy Bypass -File $installer -NoPackages -NoTerminal -DotfilesDir $repo
}

# --- Host-local additions ---------------------------------------------------
$local = Join-Path $HOME '.overwrites\profile.ps1'
if (Test-Path $local) { . $local }
Remove-Variable local
