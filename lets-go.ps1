function RefreshPath() {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
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

# Check winget and activate
if ($null -eq (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
    Write-Output "Enable winget..."
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    RefreshPath
}

# List apps to install
$core_apps = @(
    $(InstallWithWinget -appId "Git.Git" -alias "git"),
    $(InstallWithWinget -appId "Microsoft.PowerShell" -alias "")
)

# For each app, check if not present and install
foreach ($app in $core_apps) {
    InstallWithWinget -appId $app
}

# If not already set, specify dotfiles destination directory and source repo
if (!$DOTFILES_DIR) { $DOTFILES_DIR = "$HOME\.dotfiles" }
if (!$DOTFILES_REPO) { $DOTFILES_REPO = "https://github.com/jsilverdev/dotfiles.git" }

# Reload PATH
RefreshPath

if (-not (Test-Path -Path $DOTFILES_DIR -PathType Container)) {
    New-Item -ItemType Directory -Path "$DOTFILES_DIR" -Force
    git clone --recursive "$DOTFILES_REPO" "$DOTFILES_DIR"
}

Set-Location -Path $DOTFILES_DIR
$installScript = Join-Path $DOTFILES_DIR "install.ps1"
& pwsh.exe -F $installScript
