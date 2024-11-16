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
        if ((Get-WindowsDeveloperLicense).IsValid) {
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
    if ($null -eq (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
        Write-Output "Enable winget..."
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        RefreshPath
    }
}

function ConfigureSSHKey() {
    ## This is only with admin:
    # Get-Service -Name ssh-agent | Set-Service -StartupType Auto
    # Start-Service ssh-agent # If not Started

    $keyPath = "$HOME\.ssh\jsilverdev_key"

    if (!(Test-Path -Path $keyPath)) {
        Write-Host "SSH key not found at $keyPath. Generate..." -ForegroundColor Yellow
        ssh-keygen -t ed25519 -C "jsilverdev" -f "$keyPath" -N ""
    }
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
        winget list --accept-source-agreements --id $appId -n 1 | Out-Null
    }

    if (-not $?) {
        Write-Host "$appId is not installed. Installing..." -ForegroundColor Yellow
        winget install -e --accept-source-agreements --accept-package-agreements --id $appId
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

function FindPython3 {
    return Get-Command -Name python -ErrorAction SilentlyContinue |
                   Where-Object { & $_.Source --version 2>&1 | Select-String -Pattern "^Python 3\.\d+\.\d+" } |
                   Select-Object -First 1 -ExpandProperty Source
}
function InstallPython3 {
    $wingetPython3 = winget search "python.python.3" | Select-String "Python.Python" | ForEach-Object {
        # Extract both the Id (package name) and Version using regex
        if ($_ -match '(\S+)\s+(\S+)\s+(\d+\.\d+\.\d+)') {
            # Return both Id and Version as an object
            [PSCustomObject]@{
                Id      = $Matches[2]
                Version = [Version]$Matches[3]
            }
        }
    } | Sort-Object Version -Descending | Select-Object -First 1
    winget install -e --id $wingetPython3.Id
    RefreshPath
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
$installs = @(
    $(InstallWithWinget -appId "zyedidia.micro" -alias "micro"),
    $(InstallWithWinget -appId "lsd-rs.lsd" -alias "lsd"),
    $(InstallWithWinget -appId "sharkdp.bat" -alias "bat"),
    $(InstallWithWinget -appId "Fastfetch-cli.Fastfetch" -alias "fastfetch"),
    $(InstallWithWinget -appId "junegunn.fzf" -alias "fzf"),
    $(InstallWithWinget -appId "sharkdp.fd" -alias "fd"),
    $(InstallWithWinget -appId "dandavison.delta" -alias "delta"),
    $(InstallWithWinget -appId "Microsoft.VisualStudioCode" -alias "code"),
    $(InstallWithWinget -appId "Starship.Starship" -alias "starship"),
    $(InstallWithWinget -appId "Microsoft.PowerToys" -alias "")
)

foreach ($install in $installs) {
    $install
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

### Start DotBot
$CONFIG = "install.conf.yaml"
$DOTBOT_DIR = "lib/dotbot"

$DOTBOT_BIN = "bin/dotbot"
$BASEDIR = $PSScriptRoot

Set-Location $BASEDIR
git -C $DOTBOT_DIR submodule sync --quiet --recursive
git submodule update --init --recursive $DOTBOT_DIR

$PYTHON = FindPython3
if ([string]::IsNullOrEmpty($PYTHON)) {
    Write-Host "Cannot find Python 3. Installing..." -ForegroundColor Yellow
    InstallPython3
    $PYTHON = FindPython3

    if ([string]::IsNullOrEmpty($PYTHON)) {
        Write-Host "Error: Python can't not be found. Aborting..." -ForegroundColor Red
        exit
    }
}
Write-Host "Running Dotbot..." -ForegroundColor Cyan
$env:PROFILE_LOCATION = $profile.CurrentUserAllHosts ## PROFILE_LOCATION
&$PYTHON $(Join-Path $BASEDIR -ChildPath $DOTBOT_DIR | Join-Path -ChildPath $DOTBOT_BIN) -d $BASEDIR -c $CONFIG $Args

### End DotBot

### Start Installing optional apps

$optionalApps = @(
    @{ id = "1"; name = "fnm" ; install = { InstallWithWinget -appId "Schniz.fnm" -alias "fnm" } },
    @{ id = "2"; name = "puro"; install = { InstallPuroFVM } },
    @{ id = "3"; name = "DBeaver"; install = { InstallWithWinget -appId "dbeaver.dbeaver" } },
    @{ id = "4"; name = "Postman"; install = { InstallWithWinget -appId "Postman.Postman" } },
    @{ id = "5"; name = "Bruno"; install = { InstallWithWinget -appId "Bruno.Bruno" } },
    @{ id = "6"; name = "kubectl"; install = { InstallWithWinget -appId "Kubernetes.kubectl" -alias "kubectl" } }
)

Write-Host "             Optionals"
Write-Host "-----------------------------------" -ForegroundColor Cyan
Write-Host "         Choose to Install"
Write-Host "-----------------------------------" -ForegroundColor Cyan
$optionalApps | ForEach-Object { $_.id + ". Install " + $_.name }
Write-Host "-----------------------------------" -ForegroundColor Cyan

$rawOptions = Read-Host ("Select one or more options separated by commas [1,2,3...]" )
$options = $rawOptions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -Unique

if ($options.Count -eq 0) {
    Write-Host "Skipping optional installs..." -ForegroundColor Yellow
    exit
}

foreach ($app in $optionalApps) {
    if ($options -contains $app.id) {
        & $app.install
    }
}
## Refresh Path
RefreshPath
### End Installing optional apps
