$PS_USER_FOLDER = "D:\$ENV:USERNAME"
if (Test-Path -Path $PS_USER_FOLDER) {
    $ENV:STARSHIP_CACHE = "$PS_USER_FOLDER\Temp\starship"
} else {
    $PS_USER_FOLDER = "$HOME"
}
$ENV:STARSHIP_CONFIG = "$HOME\.config\starship.toml"

function Invoke-Starship-PreCommand {
    $host.ui.RawUI.WindowTitle = "$env:USERNAME@$env:COMPUTERNAME`: $pwd `a"
}
Invoke-Expression (&starship init powershell)

# General
function pwshedit { code $profile.CurrentUserAllHosts }
function c. { cd .. }
function c.. { cd ../../ }
function c... { cd ../../../ }
function c.... { cd ../../../../ }
function c..... { cd ../../../../../ }
function cg { cd (&git rev-parse --show-toplevel) }
function cddev { cd "$PS_USER_FOLDER\dev\" }

# flutter
function fl-rebuild { flutter pub run build_runner build --delete-conflicting-outputs }