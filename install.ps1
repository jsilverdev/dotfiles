### Start Utils
function RefreshPath() {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function CheckIsPowershellCompatible() {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "This script requires PowerShell 7 or newer. Exiting..." -ForegroundColor Red
        exit
    }
}

function EnsureDevModeIsEnabled() {
    try {
        $license = Get-WindowsDeveloperLicense
        if ($license.IsValid -eq $true) {
            Write-Host "Developer Mode is Enabled" -ForegroundColor Green
        }
        else {
            Write-Host "Please enable the Developer Mode before continue" -ForegroundColor Red
            exit
        }
    }
    catch {
        Write-Host "An error occurred while checking the developer license: $_" -ForegroundColor Red
        exit
    }
}

function CheckWinget() {
    try {
        winget --version > $null
        Write-Host "winget is installed or enabled" -ForegroundColor Green
    }
    catch {
        Write-Host "winget is not installed, please install it" -ForegroundColor Red
        exit
    }
}

function ConfigureSSHKey() {
    ## Create key
    # ssh-keygen -t ed25519 -C "jrp8900@gmail.com"

    ## This is only with admin:
    # Get-Service -Name ssh-agent | Set-Service -StartupType Auto
    Start-Service ssh-agent # If not Started

    $keyPath = "$HOME\.ssh\jsilverdev_key"

    if (!(Test-Path -Path $keyPath)) {
        Write-Host "SSH key not found at $keyPath. Aborting..." -ForegroundColor Red
        exit
    }
    ssh-add $keyPath
}

function InstallWithWinget() {
    param(
        [string]$appId,
        [string]$alias
    )

    if (-not ([string]::IsNullOrEmpty($alias))) {
        Get-Command -Name $alias -ErrorAction SilentlyContinue | Out-Null
    }
    else {
        winget list --id $appId -n 1 | Out-Null
    }

    if (-not $?) {
        Write-Host "$appId is not installed. Installing..." -ForegroundColor Yellow
        winget install -e --id $appId
    }
    else {
        Write-Host "$appId is already installed" -ForegroundColor Green
    }
}

function InstallPuroFVM {
    if (Get-Command puro -ErrorAction SilentlyContinue) {
        Write-Host "puro is already installed" -ForegroundColor Green
        return
    }
    Write-Host "Installing Puro FVM..." -ForegroundColor Cyan
    $apiUrl = "https://api.github.com/repos/pingbird/puro/releases/latest"
    $latestGitInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }
    $tagName = $latestGitInfo.tag_name
    Invoke-WebRequest -Uri "https://puro.dev/builds/$tagName/windows-x64/puro.exe" -OutFile "$env:temp\puro.exe"; &"$env:temp\puro.exe" install-puro --promote

}
### End Utils

### Start Pre-requirements
RefreshPath
CheckIsPowershellCompatible
EnsureDevModeIsEnabled
CheckWinget
ConfigureSSHKey
### End Pre-requirements

### Start Installing must-have apps
Write-Host "Installing must-have apps..." -ForegroundColor Cyan
$apps = @(
    @{ id = "zyedidia.micro"; alias = "micro" },
    @{ id = "lsd-rs.lsd"; alias = "lsd" },
    @{ id = "sharkdp.bat"; alias = "bat" },
    @{ id = "Fastfetch-cli.Fastfetch"; alias = "fastfetch" },
    @{ id = "junegunn.fzf"; alias = "fzf" },
    @{ id = "sharkdp.fd"; alias = "fd" },
    @{ id = "dandavison.delta"; alias = "delta" },
    @{ id = "Microsoft.VisualStudioCode"; alias = "code" },
    @{ id = "Starship.Starship"; alias = "starship" },
    @{ id = "Microsoft.PowerToys"; alias = "" },
    @{ id = "Python.Python.3.12" ; alias = "" } # for dotbot
)

foreach ($app in $apps) {
    InstallWithWinget -appId $app.id -alias $app.alias
}
# Install must-have modules
if (-not (Get-Module -ListAvailable -Name PSFzf)) {
    Install-Module -Name PSFzf -Scope CurrentUser -Force
}
else {
    Write-Host "PSFzf module is already installed" -ForegroundColor Green
}
if (-not (Get-Module -ListAvailable -Name git-aliases)) {
    Install-Module -Name git-aliases -Scope CurrentUser -AllowClobber
}
else {
    Write-Host "git-aliases module is already installed" -ForegroundColor Green
}
### End Installing must-have apps

### Start Installing optional apps
Write-Host "-----------------------------------" -ForegroundColor Cyan
Write-Host "         Choose to Install"
Write-Host "-----------------------------------" -ForegroundColor Cyan
Write-Host "1. Install fnm"
Write-Host "2. Install puro"
Write-Host "-----------------------------------" -ForegroundColor Cyan

$rawOptions = Read-Host "Select one or more options separated by commas [1,2]"
$options = $rawOptions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -Unique

foreach ($opt in $options) {
    switch ($opt) {
        "1" { InstallWithWinget -appId "Schniz.fnm" -alias "fnm" }
        "2" { InstallPuroFVM }
        default { Write-Host "Invalid option: $opt" -ForegroundColor Red }
    }
}
### End Installing optional apps

## Refresh Path
RefreshPath

### Start DotBot
$CONFIG = "install.win.conf.yaml"
$DOTBOT_DIR = "lib/dotbot"

$DOTBOT_BIN = "bin/dotbot"
$BASEDIR = $PSScriptRoot

Set-Location $BASEDIR
git -C $DOTBOT_DIR submodule sync --quiet --recursive
git submodule update --init --recursive $DOTBOT_DIR

$python3Paths = Get-Command -Name python* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path | Where-Object { $_ -match "python3" }
foreach ($path in $python3Paths) {
    if (Test-Path $path) {
        $PYTHON = $path
        break
    }
}

if (![string]::IsNullOrEmpty($PYTHON) -and ![string]::IsNullOrEmpty((&$PYTHON --version))) {

    ## PROFILE_LOCATION:
    $env:PROFILE_LOCATION = $profile.CurrentUserAllHosts

    &$PYTHON $(Join-Path $BASEDIR -ChildPath $DOTBOT_DIR | Join-Path -ChildPath $DOTBOT_BIN) -d $BASEDIR -c $CONFIG $Args
    return
}
Write-Host "Error: Cannot find Python. Abort configure Dotbot" -ForegroundColor Red
### End DotBot
