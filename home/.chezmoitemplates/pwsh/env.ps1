$preferredEditor = if (Get-Command code -ErrorAction SilentlyContinue) {
    "code"
}
elseif (Get-Command micro -ErrorAction SilentlyContinue) {
    "micro"
}
else {
    "notepad"
}
$env:VISUAL = $preferredEditor
$env:EDITOR = $preferredEditor
$env:PAGER = "delta"
$env:PYTHONIOENCODING = "utf-8"

$PS_USER_FOLDER = "D:\$env:USERNAME"
if (-not (Test-Path -LiteralPath $PS_USER_FOLDER -PathType Container -ErrorAction SilentlyContinue)) {
    $PS_USER_FOLDER = $HOME
}
$env:STARSHIP_CACHE = Join-Path $PS_USER_FOLDER "Temp\starship"
$env:STARSHIP_CONFIG = "$HOME\.config\starship\config.toml"
