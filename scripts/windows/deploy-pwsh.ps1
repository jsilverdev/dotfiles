[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$sourceRoot = Join-Path $repo "home\.chezmoitemplates\pwsh"
$destinationRoot = Join-Path $HOME ".config\pwsh"
$files = @(
    @{ Source = "env.ps1"; Destination = (Join-Path $destinationRoot "env.ps1") },
    @{ Source = "lib\helpers.ps1"; Destination = (Join-Path $destinationRoot "lib\helpers.ps1") },
    @{ Source = "lib\aliases.ps1"; Destination = (Join-Path $destinationRoot "lib\aliases.ps1") },
    @{ Source = "profile.ps1"; Destination = $PROFILE.CurrentUserAllHosts }
)

foreach ($file in $files) {
    $source = Join-Path $sourceRoot $file.Source
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "PowerShell source file not found: $source"
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $file.Destination) -Force | Out-Null

    # Remove a legacy symlink before copying the regular runtime file.
    # Copy-Item otherwise follows a broken link and fails instead of replacing it.
    if (Test-Path -LiteralPath $file.Destination -PathType Leaf) {
        $existing = Get-Item -LiteralPath $file.Destination -Force
        if (($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Remove-Item -LiteralPath $file.Destination -Force
        }
    }

    Copy-Item -LiteralPath $source -Destination $file.Destination -Force
}

if ($env:DOTFILES_SIGNING_REQUIRED -eq "1" -or (Get-ExecutionPolicy) -eq "AllSigned") {
    $helper = Join-Path $repo "scripts\windows\signing.ps1"
    $bridge = Join-Path $repo "scripts\windows\invoke-ps-script.cmd"
    foreach ($destination in @($files | ForEach-Object Destination)) {
        & $bridge $helper -Action ProtectFiles -Path $destination
        if ($LASTEXITCODE -ne 0) {
            throw "PowerShell runtime signing failed for $destination with exit code $LASTEXITCODE."
        }
    }
}
