# Start starship
function Invoke-Starship-PreCommand {
    $host.ui.RawUI.WindowTitle = "PowerShell:` $pwd `a"
}
Invoke-Expression (&starship init powershell)
# End starship

## Start Fzf
$FD_COMMAND = 'fd'
if (Get-Command "$FD_COMMAND" -ErrorAction SilentlyContinue) {
    # Commands
    $env:FZF_DEFAULT_COMMAND = "$FD_COMMAND --ignore-file $HOME\.fdignore --type f --follow --exclude .git"
    $env:FZF_CTRL_T_COMMAND = "$env:FZF_DEFAULT_COMMAND"
    $env:FZF_ALT_C_COMMAND = "$FD_COMMAND --ignore-file $HOME\.fdignore --type d"

    # Options
    $env:FZF_DEFAULT_OPTS = "
        --extended --border --info=inline --height 80%
        --color=border:#808080,spinner:#fede5d,hl:#7E8E91,fg:#E3E5E5,header:#7E8E91,info:#1d99f3,pointer:#1d99f3,marker:#03edf9,fg+:#E3E5E5,prompt:#03edf9,hl+:#03edf9
        "

    $FZF_CTRL_T_TOGGLE = 'ctrl-a:transform:if "%FZF_PROMPT%"=="Default> " (echo ^change-prompt^(All^> ^)^+^reload^(' + $FD_COMMAND + ' --hidden --no-ignore --follow --exclude .git^)) else (echo ^change-prompt^(Default^> ^)^+^reload^(' + $env:FZF_DEFAULT_COMMAND + '^))'
    $env:FZF_CTRL_T_OPTS = "
        --scheme=path
        --prompt 'Default> '
        --bind '$FZF_CTRL_T_TOGGLE'
        --header 'CTRL-A: Toggle Show'
        --preview 'bat -n --color=always --line-range :200 {}'"

    $FZF_ALT_C_TOGGLE = 'ctrl-a:transform:if "%FZF_PROMPT%"=="Default> " (echo ^change-prompt^(All^> ^)^+^reload^(' + $FD_COMMAND + ' --type d --hidden --no-ignore --exclude .git^)) else (echo ^change-prompt^(Default^> ^)^+^reload^(' + $env:FZF_ALT_C_COMMAND + '^))'
    $env:FZF_ALT_C_OPTS = "
        --scheme=path
        --prompt 'Default> '
        --bind '$FZF_ALT_C_TOGGLE'
        --header 'CTRL-A: Toggle Show'"

    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
## End Fzf

# fnm
if (Get-Command -Name fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}