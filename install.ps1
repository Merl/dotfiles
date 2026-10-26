# install.ps1 - set up the dotfiles environment on Windows.
# Runs on Windows PowerShell 5.1 and PowerShell 7. Keep this file ASCII-only.
#
# Fresh host:
#   irm https://raw.githubusercontent.com/Merl/dotfiles/master/install.ps1 | iex
# Existing checkout:
#   powershell -ExecutionPolicy Bypass -File $HOME\.dotfiles\install.ps1 [-DryRun]
#
# Steps (each idempotent; a second run changes nothing):
#   1. winget packages: Git.Git, Starship.Starship, DEVCOM.JetBrainsMonoNerdFont
#   2. clone (Forgejo via Windows OpenSSH if it authenticates, else GitHub)
#      or update (git pull --ff-only) the repository
#   3. PowerShell profile -> <Documents>\PowerShell and <Documents>\WindowsPowerShell
#   4. Windows Terminal settings.json: font, 'serenity' ssh profile, default profile
#   5. Git Bash: install.sh --no-packages (home dotfiles, vim plugins)
#
# Options (run as a file): -DryRun -NoPackages -NoTerminal -NoBash -Pinned
#   -HomeDir DIR -DocumentsDir DIR -TerminalSettings FILE -DotfilesDir DIR
# Options cannot be passed through "irm | iex"; use environment variables:
#   DOTFILES_DRYRUN=1, DOTFILES_NO_PACKAGES=1, DOTFILES_NO_TERMINAL=1,
#   DOTFILES_NO_BASH=1, DOTFILES_PINNED=1, DOTFILES_HOME, DOTFILES_DOCUMENTS,
#   DOTFILES_TERMINAL_SETTINGS, DOTFILES_DIR, DOTFILES_REPO_URL (clone source)
#
# There is deliberately no param() block: under "irm | iex" it would assign
# $DryRun etc. in the caller's session. The options are parsed from $args.

# Everything runs inside a script block so that "irm | iex" does not leave
# variables, functions, StrictMode or $ErrorActionPreference behind in the
# caller's session.
& {
param([object[]]$ArgList, [string]$ScriptFile)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# $PSCommandPath is the caller's script when "irm | iex" runs inside a script;
# only accept it if it is this file
if ($ScriptFile -and -not ((Test-Path -LiteralPath $ScriptFile -PathType Leaf) -and
        ((Get-Content -LiteralPath $ScriptFile -TotalCount 1) -eq '# install.ps1 - set up the dotfiles environment on Windows.'))) {
    $ScriptFile = ''
}

# ---------------------------------------------------------------------------
# configuration
# ---------------------------------------------------------------------------
$ForgejoUrl   = 'ssh://git@git.shelltec.de:2222/merl/dotfiles.git'
$GithubUrl    = 'https://github.com/Merl/dotfiles.git'
$WinSsh       = 'C:/Windows/System32/OpenSSH/ssh.exe'
$Packages    = @('Git.Git', 'Starship.Starship', 'DEVCOM.JetBrainsMonoNerdFont')
$FontFace     = 'JetBrainsMono NF'
$SshProfile   = 'serenity'
$SshCommand   = 'C:\Windows\System32\OpenSSH\ssh.exe -A merl@serenity.shelltec.de'
$Pwsh7Guid    = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
$ProfileRel   = 'windows\Microsoft.PowerShell_profile.ps1'
$ProfileDirs  = @('PowerShell', 'WindowsPowerShell')

# ---------------------------------------------------------------------------
# options: arguments (run as a file), else environment variables (irm | iex)
# ---------------------------------------------------------------------------
$SwitchNames = @('DryRun', 'NoPackages', 'NoTerminal', 'NoBash', 'Pinned')
$ValueNames  = @('HomeDir', 'DocumentsDir', 'TerminalSettings', 'DotfilesDir')
$Usage = 'Usage: install.ps1 [-DryRun] [-NoPackages] [-NoTerminal] [-NoBash] [-Pinned] ' +
         '[-HomeDir DIR] [-DocumentsDir DIR] [-TerminalSettings FILE] [-DotfilesDir DIR]'

# ConvertFrom-ArgList ARGS: hashtable of the options in ARGS
#   -Name, -Name:$true/$false for switches; -Name VALUE or -Name:VALUE
function ConvertFrom-ArgList([object[]]$List) {
    if ($null -eq $List) { $List = @() }
    $o = @{}
    foreach ($n in $SwitchNames) { $o[$n] = $false }
    foreach ($n in $ValueNames) { $o[$n] = '' }
    $o['Help'] = $false
    $i = 0
    while ($i -lt $List.Count) {
        $a = [string]$List[$i]
        $i++
        if ($a -notmatch '^--?([A-Za-z?]+)(:(.*))?$') { throw "unknown argument '$a'. $Usage" }
        $name = $Matches[1]
        $hasInline = [bool]$Matches[2]
        $inline = $Matches[3]
        if (@('h', 'help', '?') -contains $name) { $o['Help'] = $true; continue }
        $sw = @($SwitchNames | Where-Object { $_ -eq $name })
        if ($sw.Count -eq 1) {
            $o[$sw[0]] = (-not $hasInline) -or ($inline -notmatch '^(\$?false|0)$')
            continue
        }
        $vn = @($ValueNames | Where-Object { $_ -eq $name })
        if ($vn.Count -eq 1) {
            if ($hasInline -and $inline -ne '') { $o[$vn[0]] = $inline; continue }
            if ($i -ge $List.Count) { throw "-$($vn[0]) needs a value. $Usage" }
            $o[$vn[0]] = [string]$List[$i]
            $i++
            continue
        }
        throw "unknown argument '$a'. $Usage"
    }
    return $o
}

function Get-EnvFlag([string]$Name) {
    $v = [Environment]::GetEnvironmentVariable($Name)
    return ($null -ne $v -and $v -ne '' -and $v -ne '0' -and $v -ne 'false')
}
function Get-EnvText([string]$Name) {
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ($null -eq $v) { return '' }
    return $v
}
function Select-First {
    foreach ($a in $args) { if ($null -ne $a -and "$a" -ne '') { return "$a" } }
    return ''
}

# arguments only count when this runs as a script file (not via iex)
$P = ConvertFrom-ArgList $(if ($ScriptFile) { @($ArgList) } else { @() })
if ($P.Help) { Write-Host $Usage; return }

$DryRun     = $P.DryRun     -or (Get-EnvFlag 'DOTFILES_DRYRUN')
$NoPackages = $P.NoPackages -or (Get-EnvFlag 'DOTFILES_NO_PACKAGES')
$NoTerminal = $P.NoTerminal -or (Get-EnvFlag 'DOTFILES_NO_TERMINAL')
$NoBash     = $P.NoBash     -or (Get-EnvFlag 'DOTFILES_NO_BASH')
$Pinned     = $P.Pinned     -or (Get-EnvFlag 'DOTFILES_PINNED')
$NoPull     = Get-EnvFlag 'DOTFILES_NO_PULL'      # internal: set for child runs
$HomeDir    = Select-First $P.HomeDir (Get-EnvText 'DOTFILES_HOME') $HOME
$DocsDir    = Select-First $P.DocumentsDir (Get-EnvText 'DOTFILES_DOCUMENTS') ([Environment]::GetFolderPath('MyDocuments'))
$WtOverride = Select-First $P.TerminalSettings (Get-EnvText 'DOTFILES_TERMINAL_SETTINGS')
$TargetDir  = Select-First $P.DotfilesDir (Get-EnvText 'DOTFILES_DIR') (Join-Path $HomeDir '.dotfiles')
$RepoUrl    = Get-EnvText 'DOTFILES_REPO_URL'

# a dry run only probes hosts that are already in known_hosts
$SshOpts = if ($DryRun) { '-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes' }
           else { '-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new' }

$Prefix  = if ($DryRun) { '[dry-run] ' } else { '' }
$Stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$Changes  = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$Errors   = New-Object System.Collections.Generic.List[string]
$Manual   = New-Object System.Collections.Generic.List[string]
$S = @{ Git = $null; Rerun = $false; ChildCode = 0 }   # shared state for the functions below

# changes/warnings/errors handed over by a parent run (bootstrap, restart)
foreach ($pair in @(@('DOTFILES_CHANGES', $Changes), @('DOTFILES_WARNINGS', $Warnings), @('DOTFILES_ERRORS', $Errors))) {
    $v = Get-EnvText $pair[0]
    if ($v) { foreach ($line in ($v -split "`n")) { if ($line) { $pair[1].Add($line) } } }
    Remove-Item -LiteralPath "Env:$($pair[0])" -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
function Write-Step([string]$Text) { Write-Host ''; Write-Host "==> $Text" }
function Write-Act([string]$Label, [string]$Item, [string]$Detail = '') {
    $line = '{0}{1,-12} {2}' -f $Prefix, $Label, $Item
    if ($Detail) { $line += "  ($Detail)" }
    Write-Host $line
}
function Add-Warning([string]$Text) {
    Write-Host "WARNING: $Text" -ForegroundColor Yellow
    $Warnings.Add($Text)
}
# errors make the run fail (exit code 1 when run as a file)
function Add-Error([string]$Text) {
    Write-Host "ERROR: $Text" -ForegroundColor Red
    $Errors.Add($Text)
}

# Get-ForwardArgs: the current options as arguments for a child install.ps1
function Get-ForwardArgs([switch]$AddNoPackages) {
    $a = @('-HomeDir', $HomeDir, '-DocumentsDir', $DocsDir, '-DotfilesDir', $TargetDir)
    if ($WtOverride) { $a += @('-TerminalSettings', $WtOverride) }
    if ($AddNoPackages -or $NoPackages) { $a += '-NoPackages' }
    if ($NoTerminal) { $a += '-NoTerminal' }
    if ($NoBash)     { $a += '-NoBash' }
    if ($Pinned)     { $a += '-Pinned' }
    if ($DryRun)     { $a += '-DryRun' }
    return $a
}

# Invoke-Child FILE ARGS: run FILE (an install.ps1) in a new PowerShell
# process with NoPull, handing over what this run changed/warned so far;
# sets $S.ChildCode to its exit code (its output goes straight to the console)
function Invoke-Child([string]$File, [string[]]$ArgList) {
    $hostExe = (Get-Process -Id $PID).Path
    $names = @('DOTFILES_NO_PULL', 'DOTFILES_CHANGES', 'DOTFILES_WARNINGS', 'DOTFILES_ERRORS')
    $saved = @{}
    foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }
    try {
        $env:DOTFILES_NO_PULL  = '1'
        $env:DOTFILES_CHANGES  = ($Changes -join "`n")
        $env:DOTFILES_WARNINGS = ($Warnings -join "`n")
        $env:DOTFILES_ERRORS   = ($Errors -join "`n")
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $hostExe -NoProfile -ExecutionPolicy Bypass -File $File @ArgList
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $old }
    } finally {
        foreach ($n in $names) {
            # ($null would become '' and leave an empty variable in PowerShell 7)
            if ($null -eq $saved[$n]) { Remove-Item -LiteralPath "Env:$n" -ErrorAction SilentlyContinue }
            else { Set-Item -LiteralPath "Env:$n" -Value $saved[$n] }
        }
    }
    if ($null -eq $code) { $code = 1 }
    $S.ChildCode = $code
}

# Invoke-Native EXE ARGS: run a native command, capture output and exit code
# without letting stderr turn into terminating errors (PowerShell 5.1).
function Invoke-Native([string]$Exe, [string[]]$ArgList) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $Exe @ArgList 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
    return [pscustomobject]@{ Code = $code; Output = (@($out) -join "`n") }
}

function Update-PathFromRegistry {
    $parts = @()
    foreach ($scope in 'Machine', 'User') {
        $v = [Environment]::GetEnvironmentVariable('Path', $scope)
        if ($v) { $parts += $v -split ';' }
    }
    $parts += $env:Path -split ';'
    $seen = @{}
    $result = foreach ($p in $parts) {
        if ($p -and -not $seen.ContainsKey($p.ToLowerInvariant())) { $seen[$p.ToLowerInvariant()] = 1; $p }
    }
    $env:Path = ($result -join ';')
}

function Test-Checkout([string]$Dir) {
    if (-not $Dir) { return $false }
    return ((Test-Path -LiteralPath (Join-Path $Dir '.vimrc')) -and
            (Test-Path -LiteralPath (Join-Path $Dir $ProfileRel)) -and
            (Test-Path -LiteralPath (Join-Path $Dir 'install.ps1')))
}

function Get-Git {
    $g = Get-Command git -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    foreach ($c in "$env:ProgramFiles\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe") {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

# run git with a temporary GIT_SSH_COMMAND (and no credential prompts)
function Invoke-Git([string]$SshCommand, [string[]]$ArgList, [switch]$Live) {
    $oldSsh = $env:GIT_SSH_COMMAND
    $oldPrompt = $env:GIT_TERMINAL_PROMPT
    try {
        if ($SshCommand) { $env:GIT_SSH_COMMAND = $SshCommand }
        $env:GIT_TERMINAL_PROMPT = '0'
        if ($Live) {
            $old = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try { & $S.Git @ArgList; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
            return [pscustomobject]@{ Code = $code; Output = '' }
        }
        return Invoke-Native $S.Git $ArgList
    } finally {
        $env:GIT_SSH_COMMAND = $oldSsh
        $env:GIT_TERMINAL_PROMPT = $oldPrompt
    }
}

# ---------------------------------------------------------------------------
# 1. winget packages
# ---------------------------------------------------------------------------
function Install-Packages {
    Write-Step 'Packages (winget)'
    if ($NoPackages) { Write-Act 'skip' 'packages' 'NoPackages'; return }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Add-Warning ('winget not found. Install "App Installer" from the Microsoft Store ' +
            '(https://aka.ms/getwinget), then run this again; or install manually: ' + ($Packages -join ', '))
        return
    }
    $missing = @()
    foreach ($id in $Packages) {
        $r = Invoke-Native $winget.Source @('list', '--id', $id, '-e', '--accept-source-agreements', '--disable-interactivity')
        if ($r.Code -eq 0 -and $r.Output -match [regex]::Escape($id)) {
            Write-Act 'ok' $id
        } else {
            Write-Act 'missing' $id
            $missing += $id
        }
    }
    foreach ($id in $missing) {
        Write-Act 'install' $id 'winget install'
        if ($DryRun) { continue }
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $winget.Source install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $old }
        if ($code -eq 0) { $Changes.Add("winget: installed $id") }
        else { Add-Warning "winget install $id failed (exit $code)" }
    }
    if ($missing.Count -gt 0 -and -not $DryRun) { Update-PathFromRegistry }
}

# ---------------------------------------------------------------------------
# 2. repository
# ---------------------------------------------------------------------------
# returns @{ Url; Ssh } for the clone
function Select-Source {
    if ($RepoUrl) { return @{ Url = $RepoUrl; Ssh = '' } }
    if (Test-Path -LiteralPath $WinSsh) {
        $ssh = "$WinSsh $SshOpts"
        $r = Invoke-Git $ssh @('ls-remote', $ForgejoUrl, 'HEAD')
        if ($r.Code -eq 0) { return @{ Url = $ForgejoUrl; Ssh = $ssh } }
        Write-Host "Forgejo not reachable via ssh (no key/agent?); using GitHub."
    }
    return @{ Url = $GithubUrl; Ssh = '' }
}

function Update-Checkout([string]$Dir) {
    Write-Step 'Repository'
    if ($NoPull) { Write-Act 'skip' 'git pull' 'already done by the parent run'; return }
    if (-not $S.Git) { Add-Warning 'git not found; repository not updated'; return }
    $r = Invoke-Native $S.Git @('-C', $Dir, 'rev-parse', '--git-dir')
    if ($r.Code -ne 0) { Write-Act 'skip' 'git pull' 'not a git checkout'; return }
    $r = Invoke-Native $S.Git @('-C', $Dir, 'status', '--porcelain', '--untracked-files=no')
    if ($r.Output.Trim()) { Add-Warning "$Dir has local changes; not pulling"; return }
    $r = Invoke-Native $S.Git @('-C', $Dir, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    if ($r.Code -ne 0) { Add-Warning "$Dir`: current branch has no upstream; not pulling"; return }
    if ($DryRun) { Write-Act 'pull' $Dir 'would run git pull --ff-only'; return }
    $ssh = ''
    $cfg = Invoke-Native $S.Git @('-C', $Dir, 'config', 'core.sshCommand')
    if (-not $env:GIT_SSH_COMMAND -and $cfg.Code -ne 0 -and (Test-Path -LiteralPath $WinSsh)) { $ssh = "$WinSsh $SshOpts" }
    $before = (Invoke-Native $S.Git @('-C', $Dir, 'rev-parse', '--short', 'HEAD')).Output
    $self = Join-Path $Dir 'install.ps1'
    $selfHash = (Get-FileHash -LiteralPath $self -Algorithm SHA256).Hash
    $r = Invoke-Git $ssh @('-C', $Dir, 'pull', '-q', '--ff-only')
    if ($r.Code -ne 0) {
        Add-Warning "git pull --ff-only failed in $Dir (offline, diverged or no access); continuing with the current checkout"
        return
    }
    $after = (Invoke-Native $S.Git @('-C', $Dir, 'rev-parse', '--short', 'HEAD')).Output
    if ($after -eq $before) { Write-Act 'ok' 'git pull' 'already up to date'; return }
    Write-Act 'updated' 'git pull' "$before -> $after"
    $Changes.Add("repository updated ($before -> $after)")
    if ((Get-FileHash -LiteralPath $self -Algorithm SHA256).Hash -ne $selfHash) { $S.Rerun = $true }
}

# ---------------------------------------------------------------------------
# 3. PowerShell profile
# ---------------------------------------------------------------------------
function Install-PsProfile([string]$Repo) {
    Write-Step 'PowerShell profile'
    $src = Join-Path $Repo $ProfileRel
    $name = Split-Path $src -Leaf
    $srcBytes = [IO.File]::ReadAllBytes($src)
    foreach ($d in $ProfileDirs) {
        $target = Join-Path (Join-Path $DocsDir $d) $name
        $key = "_documents\$d\$name"
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $cur = [IO.File]::ReadAllBytes($target)
            if ([Convert]::ToBase64String($cur) -eq [Convert]::ToBase64String($srcBytes)) {
                Write-Act 'ok' $target
                continue
            }
            $backup = Join-Path (Join-Path (Join-Path $HomeDir '.dotfiles-backup') $Stamp) $key
            Write-Act 'backup+copy' $target "old file -> $backup"
            if (-not $DryRun) {
                New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
                Move-Item -LiteralPath $target -Destination $backup
            }
        } else {
            Write-Act 'copy' $target
        }
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
            Copy-Item -LiteralPath $src -Destination $target
            $Changes.Add("PowerShell profile -> $target")
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Windows Terminal
# ---------------------------------------------------------------------------
function Get-Prop($Obj, [string]$Name) {
    if ($null -eq $Obj -or -not ($Obj -is [System.Management.Automation.PSCustomObject])) { return $null }
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}
function Set-Prop($Obj, [string]$Name, $Value) {
    if ($Obj.PSObject.Properties[$Name]) { $Obj.$Name = $Value }
    else { $Obj | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

# Small JSON writer: stable 2-space output on 5.1 and 7 (ConvertTo-Json differs
# between versions and escapes more than needed in 5.1).
function ConvertTo-JsonText($Value, [int]$Level = 0) {
    $ind = '  ' * ($Level + 1)
    $end = '  ' * $Level
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string] -or $Value -is [char]) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('"')
        foreach ($ch in ([string]$Value).ToCharArray()) {
            switch ($ch) {
                '"'  { [void]$sb.Append('\"'); break }
                '\'  { [void]$sb.Append('\\'); break }
                "`n" { [void]$sb.Append('\n'); break }
                "`r" { [void]$sb.Append('\r'); break }
                "`t" { [void]$sb.Append('\t'); break }
                default {
                    if ([int]$ch -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) }
                    else { [void]$sb.Append($ch) }
                }
            }
        }
        [void]$sb.Append('"')
        return $sb.ToString()
    }
    if ($Value -is [datetime]) { return ConvertTo-JsonText ($Value.ToString('o')) $Level }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal] -or
        $Value -is [single] -or $Value -is [int16] -or $Value -is [byte] -or $Value -is [bigint]) {
        return ([System.Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture))
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $props = @($Value.PSObject.Properties)
        if ($props.Count -eq 0) { return '{}' }
        $items = foreach ($p in $props) { $ind + (ConvertTo-JsonText $p.Name 0) + ': ' + (ConvertTo-JsonText $p.Value ($Level + 1)) }
        return "{`n" + ($items -join ",`n") + "`n$end}"
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $o = [pscustomobject]@{}
        foreach ($k in $Value.Keys) { $o | Add-Member -NotePropertyName ([string]$k) -NotePropertyValue $Value[$k] }
        return ConvertTo-JsonText $o $Level
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $arr = @($Value)
        if ($arr.Count -eq 0) { return '[]' }
        $items = foreach ($v in $arr) { $ind + (ConvertTo-JsonText $v ($Level + 1)) }
        return "[`n" + ($items -join ",`n") + "`n$end]"
    }
    return ConvertTo-JsonText ([string]$Value) $Level
}

function Find-TerminalSettings {
    if ($WtOverride) { return @($WtOverride) }
    $found = @()
    $pkgs = Join-Path $env:LOCALAPPDATA 'Packages'
    if (Test-Path -LiteralPath $pkgs) {
        foreach ($d in (Get-ChildItem -LiteralPath $pkgs -Directory -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue)) {
            $f = Join-Path $d.FullName 'LocalState\settings.json'
            if (Test-Path -LiteralPath $f) { $found += $f }
        }
    }
    $f = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    if (Test-Path -LiteralPath $f) { $found += $f }
    return $found
}

function Update-TerminalFile([string]$File) {
    Write-Host "settings: $File"
    if (-not (Test-Path -LiteralPath $File)) { Add-Warning "$File not found"; return }
    $text = [IO.File]::ReadAllText($File)
    $plan = @("profiles.defaults.font.face = '$FontFace'",
              "profile '$SshProfile' with commandline '$SshCommand'",
              "defaultProfile = $Pwsh7Guid (PowerShell 7), if that profile exists")
    # comments (outside strings) -> do not rewrite, the user's comments would be lost
    $noStrings = [regex]::Replace($text, '"(?:[^"\\]|\\.)*"', '""')
    $hasComments = $noStrings -match '//|/\*'
    try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    if ($null -eq $json -or -not ($json -is [System.Management.Automation.PSCustomObject])) {
        Add-Warning "$File could not be parsed as plain JSON; change manually: $($plan -join '; ')"
        $Manual.Add("${File}: " + ($plan -join '; '))
        return
    }
    $profiles = Get-Prop $json 'profiles'
    if (-not ($profiles -is [System.Management.Automation.PSCustomObject])) {
        Add-Warning "$File uses the old 'profiles' list format; change manually: $($plan -join '; ')"
        $Manual.Add("${File}: " + ($plan -join '; '))
        return
    }
    $todo = @()

    # font in profiles.defaults
    $defaults = Get-Prop $profiles 'defaults'
    if (-not ($defaults -is [System.Management.Automation.PSCustomObject])) {
        $defaults = [pscustomobject]@{}; Set-Prop $profiles 'defaults' $defaults
    }
    $font = Get-Prop $defaults 'font'
    if (-not ($font -is [System.Management.Automation.PSCustomObject])) {
        $font = [pscustomobject]@{}; Set-Prop $defaults 'font' $font
    }
    if ((Get-Prop $font 'face') -ne $FontFace) { Set-Prop $font 'face' $FontFace; $todo += "font face -> $FontFace" }
    else { Write-Act 'ok' 'font' $FontFace }

    # ssh profile
    $list = @(Get-Prop $profiles 'list' | Where-Object { $null -ne $_ })
    $ssh = @($list | Where-Object { (Get-Prop $_ 'name') -eq $SshProfile }) | Select-Object -First 1
    if ($null -eq $ssh) {
        $ssh = [pscustomobject]@{}
        Set-Prop $ssh 'guid' ('{' + [guid]::NewGuid().ToString() + '}')
        Set-Prop $ssh 'name' $SshProfile
        Set-Prop $ssh 'commandline' $SshCommand
        Set-Prop $ssh 'hidden' $false
        $list += $ssh
        Set-Prop $profiles 'list' $list
        $todo += "add profile '$SshProfile'"
    } elseif ((Get-Prop $ssh 'commandline') -ne $SshCommand) {
        Set-Prop $ssh 'commandline' $SshCommand
        $todo += "profile '$SshProfile': commandline -> $SshCommand"
    } else {
        Write-Act 'ok' "profile $SshProfile"
    }

    # default profile: PowerShell 7, if present
    $hasPwsh7 = @($list | Where-Object { (Get-Prop $_ 'guid') -eq $Pwsh7Guid }).Count -gt 0
    if (-not $hasPwsh7) {
        Write-Act 'skip' 'defaultProfile' 'no PowerShell 7 profile in settings'
    } elseif ((Get-Prop $json 'defaultProfile') -ne $Pwsh7Guid) {
        Set-Prop $json 'defaultProfile' $Pwsh7Guid
        $todo += "defaultProfile -> PowerShell 7"
    } else {
        Write-Act 'ok' 'defaultProfile' 'PowerShell 7'
    }

    if ($todo.Count -eq 0) { return }
    foreach ($t in $todo) { Write-Act 'change' $t }
    if ($hasComments) {
        Add-Warning "$File contains comments; not rewritten. Change manually: $($todo -join '; ')"
        $Manual.Add("${File}: " + ($todo -join '; '))
        return
    }
    $backup = "$File.bak-$Stamp"
    Write-Act 'backup' $backup
    if ($DryRun) { return }
    Copy-Item -LiteralPath $File -Destination $backup
    $out = (ConvertTo-JsonText $json 0) + "`n"
    [IO.File]::WriteAllText($File, $out, (New-Object System.Text.UTF8Encoding($false)))
    $Changes.Add("Windows Terminal: $($todo -join '; ') ($File; backup $backup)")
}

function Update-Terminal {
    Write-Step 'Windows Terminal'
    if ($NoTerminal) { Write-Act 'skip' 'Windows Terminal' 'NoTerminal'; return }
    $files = @(Find-TerminalSettings)
    if ($files.Count -eq 0) {
        Add-Warning 'Windows Terminal settings.json not found (start Windows Terminal once, then run this again)'
        return
    }
    foreach ($f in $files) { Update-TerminalFile $f }
}

# ---------------------------------------------------------------------------
# 5. Git Bash: install.sh
# ---------------------------------------------------------------------------
function Get-GitBash {
    $cands = @()
    if ($S.Git) {
        $gitRoot = Split-Path (Split-Path $S.Git)     # ...\Git\cmd\git.exe -> ...\Git
        $cands += (Join-Path $gitRoot 'bin\bash.exe')
        $cands += (Join-Path (Split-Path $gitRoot) 'bin\bash.exe')   # ...\Git\mingw64\bin\git.exe
    }
    $cands += "$env:ProgramFiles\Git\bin\bash.exe"
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}

function Invoke-BashInstall([string]$Repo) {
    Write-Step 'Git Bash dotfiles (install.sh)'
    if ($NoBash) { Write-Act 'skip' 'install.sh' 'NoBash'; return }
    $bash = Get-GitBash
    if (-not $bash) { Add-Warning 'Git Bash (bash.exe) not found; home dotfiles not installed'; return }
    $argList = @((($Repo -replace '\\', '/') + '/install.sh'), '--no-packages', '--no-pull')
    if ($DryRun) { $argList += '--dry-run' }
    if ($Pinned) { $argList += '--pinned' }
    Write-Host "running: $bash $($argList -join ' ')  (HOME=$HomeDir)"
    $oldHome = $env:HOME
    $old = $ErrorActionPreference
    try {
        $env:HOME = ($HomeDir -replace '\\', '/')
        $ErrorActionPreference = 'Continue'
        & $bash @argList
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
        $env:HOME = $oldHome
    }
    if ($code -ne 0) { Add-Error "install.sh failed (exit $code)" }
}

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
# Write-Summary: print it; returns the exit code (1 if there were errors)
function Write-Summary {
    Write-Step 'Summary'
    if ($Changes.Count -eq 0) {
        if ($DryRun) { Write-Host '[dry-run] see above for what would change.' }
        elseif ($Manual.Count -gt 0 -or $Warnings.Count -gt 0 -or $Errors.Count -gt 0) { Write-Host 'Nothing changed; see the notes below.' }
        else { Write-Host 'Everything is in place; nothing changed.' }
    } else {
        $verb = if ($DryRun) { 'would change' } else { 'changed' }
        foreach ($c in $Changes) { Write-Host "- ${verb}: $c" }
    }
    foreach ($m in $Manual)   { Write-Host "- manual: $m" }
    foreach ($w in $Warnings) { Write-Host "- warning: $w" }
    foreach ($e in $Errors)   { Write-Host "- error: $e" -ForegroundColor Red }
    Write-Host '- Open a new PowerShell / Windows Terminal window to pick up profile, font and PATH changes.'
    if ($Errors.Count -gt 0) { return 1 }
    return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
Write-Host "${Prefix}dotfiles setup (Windows, PowerShell $($PSVersionTable.PSVersion))"
Write-Host "home $HomeDir, documents $DocsDir"

$Repo = $null
if ($ScriptFile) {
    $d = Split-Path -Parent $ScriptFile
    if (Test-Checkout $d) { $Repo = (Resolve-Path -LiteralPath $d).Path }
}

if ($Repo) {
    # run from a checkout: update it first; restart if install.ps1 changed
    $S.Git = Get-Git
    Update-Checkout $Repo
    if ($S.Rerun) {
        Write-Host 'install.ps1 changed; restarting it.'
        Invoke-Child (Join-Path $Repo 'install.ps1') (Get-ForwardArgs)
        if ($S.ChildCode -ne 0) {
            Write-Host "ERROR: the restarted install.ps1 failed (exit $($S.ChildCode))" -ForegroundColor Red
        }
        exit $S.ChildCode
    }
    Install-Packages
    $S.Git = Get-Git
    Install-PsProfile $Repo
    Update-Terminal
    Invoke-BashInstall $Repo
    $rc = Write-Summary
    exit $rc
}

# bootstrap: invoked via irm | iex (or from outside a checkout)
Install-Packages
$S.Git = Get-Git
Write-Step 'Bootstrap'
$tmp = $null
$runDir = $TargetDir
$handed = $false
try {
    if (-not $S.Git) {
        Add-Error 'git not found (winget package Git.Git); cannot clone the repository'
    } elseif (Test-Checkout $TargetDir) {
        Write-Act 'ok' $TargetDir 'checkout exists'
        Update-Checkout $TargetDir
    } elseif (Test-Path -LiteralPath $TargetDir) {
        Add-Error "$TargetDir exists but is not a dotfiles checkout; move it away or set DOTFILES_DIR"
    } else {
        $src = Select-Source
        if ($DryRun) {
            Write-Act 'clone' $TargetDir "would clone $($src.Url)"
            # inside try: an interrupted preview still removes the temporary clone
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-preview-' + [guid]::NewGuid().ToString('N'))
            $runDir = Join-Path $tmp 'dotfiles'
            Write-Host '[dry-run] previewing the remaining steps from a temporary clone'
        } else {
            Write-Act 'clone' $TargetDir $src.Url
        }
        $r = Invoke-Git $src.Ssh @('clone', '-q', $src.Url, $runDir) -Live
        if ($r.Code -ne 0) {
            Add-Error "git clone $($src.Url) failed"
        } elseif (-not (Test-Checkout $runDir)) {
            Add-Error "$($src.Url) does not contain install.ps1/.vimrc/$ProfileRel"
        } else {
            if ($src.Ssh -and -not $DryRun) {
                [void](Invoke-Native $S.Git @('-C', $runDir, 'config', 'core.sshCommand', $WinSsh))
            }
            if (-not $DryRun) { $Changes.Add("repository cloned to $TargetDir") }
        }
    }
    if ($Errors.Count -eq 0) {
        # the checkout's install.ps1 does the rest and prints the summary
        # (including what this run changed)
        Invoke-Child (Join-Path $runDir 'install.ps1') (Get-ForwardArgs -AddNoPackages)
        $handed = $true
    }
} finally {
    if ($tmp) { Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue }
}
if ($handed) {
    $rc = $S.ChildCode
    if ($rc -ne 0) { Write-Host "ERROR: $runDir\install.ps1 failed (exit $rc)" -ForegroundColor Red }
} else {
    $rc = Write-Summary
}
# "exit" would close the caller's window under irm | iex
if ($ScriptFile) { exit $rc }
} @(Get-Variable -Name args -ValueOnly -ErrorAction SilentlyContinue) $(Get-Variable -Name PSCommandPath -ValueOnly -ErrorAction SilentlyContinue)
