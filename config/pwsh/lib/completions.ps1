# fnm completions
if (Get-Command -Name "fnm" -ErrorAction SilentlyContinue | Out-Null) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
