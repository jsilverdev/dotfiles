function RefreshPath() {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function InstallWithWinget() {
    param(
        [string]$appId,
        [string]$alias,
        [string]$customArgs = ""
    )

    if (-not ([string]::IsNullOrEmpty($alias))) {
        Get-Command -Name $alias -ErrorAction SilentlyContinue | Out-Null
    }
    else {
        winget list --accept-source-agreements --id $appId -n 1 | Out-Null
    }

    if (-not $?) {
        Write-Host "$appId is not installed. Installing..." -ForegroundColor Yellow
        winget install -e --accept-source-agreements --accept-package-agreements --id $appId --custom "$customArgs"
    }
}

# Check winget and activate
if ($null -eq (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
    Write-Output "Enable winget..."
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    RefreshPath
}

# List apps to install
Write-Host "Installing must-have apps..." -ForegroundColor Cyan
$installs = @(
    $(InstallWithWinget -appId "Git.Git" -alias "git" -customArgs '/Components="gitlfs,assoc,windowsterminal" /o:SSHOption=ExternalOpenSSH /o:CurlOption=WinSSL /o:CRLFOption=CRLFCommitAsIs'),
    $(InstallWithWinget -appId "Microsoft.PowerShell")
)

# For each app, check if not present and install
foreach ($install in $installs) {
    $install
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
