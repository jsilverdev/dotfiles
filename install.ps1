### Check winget
try {
    winget --version > $null
    Write-Host "winget is installed or enabled" -ForegroundColor Green
} catch {
    Write-Host "winget is not installed, please install it" -ForegroundColor Red
    exit
}

### Start Installing my apps
Write-Output "Installing apps...`n"
$apps = @(
    "Starship.Starship",
    "zyedidia.micro",
    "lsd-rs.lsd",
    "sharkdp.bat",
    "Schniz.fnm",
    "Fastfetch-cli.Fastfetch",
    "junegunn.fzf",
    "sharkdp.fd",
    "dandavison.delta",
    "Microsoft.VisualStudioCode",
    "Microsoft.PowerToys"
)

foreach ($app in $apps) {
    winget list --id $app -n 1 | Out-Null
    if (-not $?) {
        Write-Host "$app is not installed. Installing..." -ForegroundColor Yellow
        winget install -e --id $app
    } else {
        Write-Host "$app is already installed" -ForegroundColor Green
    }
}
Write-Output ""
### End Installing my apps

### Start DotBot
$CONFIG = "install.win.conf.yaml"
$DOTBOT_DIR = "lib/dotbot"

$DOTBOT_BIN = "bin/dotbot"
$BASEDIR = $PSScriptRoot

Set-Location $BASEDIR
git -C $DOTBOT_DIR submodule sync --quiet --recursive
git submodule update --init --recursive $DOTBOT_DIR

$PYTHON = Get-Command python3* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -First 1

if (![string]::IsNullOrEmpty($PYTHON) -and ![string]::IsNullOrEmpty((&$PYTHON --version))) {

    ## PROFILE_LOCATION:
    $env:PROFILE_LOCATION=$profile.CurrentUserAllHosts

    &$PYTHON $(Join-Path $BASEDIR -ChildPath $DOTBOT_DIR | Join-Path -ChildPath $DOTBOT_BIN) -d $BASEDIR -c $CONFIG $Args
    return
}
Write-Error "Error: Cannot find Python."
### End DotBot
