## Start General
Set-Alias grep findstr
function exploreit { explorer.exe . }
function pwshedit { code $profile.CurrentUserAllHosts }
function c. { Set-Location .. }
function c.. { Set-Location ../../ }
function c... { Set-Location ../../../ }
function c.... { Set-Location ../../../../ }
function c..... { Set-Location ../../../../../ }
function cg { Set-Location (&git rev-parse --show-toplevel) }
function cddev { Set-Location "$PS_USER_FOLDER\dev\" }
function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}
function ll($params) { lsd -lAFh $params }
function lb($params) { lsd -lhSA $params }
function lm($params) { lsd -tA -1 $params }
function touch($file) {
    New-Item -Path "$file" -ItemType File
}
## End General

# GIT
Import-Module git-aliases -DisableNameChecking

# flutter
function fl-rebuild { flutter pub run build_runner build --delete-conflicting-outputs }