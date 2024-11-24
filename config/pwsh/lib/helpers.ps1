# Start starship
function Invoke-Starship-PreCommand {
    $host.ui.RawUI.WindowTitle = "PowerShell:` $pwd `a"
}
Invoke-Expression (&starship init powershell)
# End starship

## Start Fzf
$FD_COMMAND = 'fd'
if (Get-Command "$FD_COMMAND" -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_COMMAND = "$FD_COMMAND --ignore-file $HOME\.fdignore --type f --follow --exclude .git"
    $env:FZF_CTRL_T_COMMAND = "$env:FZF_DEFAULT_COMMAND"
    $env:FZF_ALT_C_COMMAND = "$FD_COMMAND --ignore-file $HOME\.fdignore --type d"
}
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
## End Fzf

# fnm
if (Get-Command -Name fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}