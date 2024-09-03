$CONFIG = "install.win.conf.yaml"
$DOTBOT_DIR = "lib/dotbot"

$DOTBOT_BIN = "bin/dotbot"
$BASEDIR = $PSScriptRoot

Set-Location $BASEDIR
git -C $DOTBOT_DIR submodule sync --quiet --recursive
git submodule update --init --recursive $DOTBOT_DIR

$PYTHON = Get-Command python3* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -First 1

if (![string]::IsNullOrEmpty($PYTHON) -and ![string]::IsNullOrEmpty((&$PYTHON --version))) {
    &$PYTHON $(Join-Path $BASEDIR -ChildPath $DOTBOT_DIR | Join-Path -ChildPath $DOTBOT_BIN) -d $BASEDIR -c $CONFIG $Args
    return
}
Write-Error "Error: Cannot find Python."