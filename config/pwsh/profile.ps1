# Load env vars
. "~\env.ps1"

# Run ssh-agent if not running
$sshAgent = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
if (-not ($sshAgent -and $sshAgent.Status -eq 'Running')) {
    Start-Service -Name "ssh-agent"
}

# Load starship
function Invoke-Starship-PreCommand {
    $host.ui.RawUI.WindowTitle = "PowerShell:` $pwd `a"
}
Invoke-Expression (&starship init powershell)

# General
Set-Alias grep findstr

Import-Module git-aliases -DisableNameChecking

#Fzf (Import the fuzzy finder and set a shortcut key to begin searching)
$FD_COMMAND = 'fd'
if (Get-Command "$FD_COMMAND" -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_COMMAND = "$FD_COMMAND --ignore-file $HOME\.fdignore --type f --follow --exclude .git"
    $env:FZF_CTRL_T_COMMAND = "$env:FZF_DEFAULT_COMMAND"
    $env:FZF_ALT_C_COMMAND = "$FD_COMMAND --ignore-file $HOME\.fdignore --type d"
}
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

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

# flutter
function fl-rebuild { flutter pub run build_runner build --delete-conflicting-outputs }