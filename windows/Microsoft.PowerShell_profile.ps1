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

# --- Host-local additions ---------------------------------------------------
$local = Join-Path $HOME '.overwrites\profile.ps1'
if (Test-Path $local) { . $local }
Remove-Variable local
