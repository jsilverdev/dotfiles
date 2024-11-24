$PS_USER_FOLDER = "D:\$ENV:USERNAME"
if (Test-Path -Path $PS_USER_FOLDER) {
    $ENV:STARSHIP_CACHE = "$PS_USER_FOLDER\Temp\starship"
}
else {
    $PS_USER_FOLDER = "$HOME"
}
$ENV:STARSHIP_CONFIG = "$HOME\.config\starship\config.toml"

# fnm
$ENV:FNM_DIR = "$HOME\fnm"