# Load env vars
. "~\env.ps1"

# Load starship
function Invoke-Starship-PreCommand {
    $host.ui.RawUI.WindowTitle = "PowerShell:` $pwd `a"
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