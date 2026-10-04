[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Get-DirectoryEntry {
    param([Parameter(Mandatory)][string]$Path)

    $parent = [IO.Path]::GetDirectoryName($Path)
    $leaf = [IO.Path]::GetFileName($Path)
    if ([string]::IsNullOrWhiteSpace($parent) -or [string]::IsNullOrWhiteSpace($leaf)) {
        return $null
    }

    $directory = [IO.DirectoryInfo]::new($parent)
    if (-not $directory.Exists) {
        return $null
    }

    return @($directory.EnumerateFileSystemInfos() | Where-Object Name -eq $leaf | Select-Object -First 1)
}

function Ensure-DestinationDirectory {
    param([Parameter(Mandatory)][string]$Destination)

    $parent = [IO.Path]::GetDirectoryName($Destination)
    if ([string]::IsNullOrWhiteSpace($parent)) {
        throw "Destination has no parent directory: $Destination"
    }

    try {
        [IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    catch {
        throw "Unable to create destination directory '$parent': $($_.Exception.Message)"
    }

    if (-not [IO.Directory]::Exists($parent)) {
        throw "Destination directory is unavailable after creation: $parent"
    }
}

function Remove-LegacyDestinationLink {
    param([Parameter(Mandatory)][string]$Destination)

    $entry = Get-DirectoryEntry -Path $Destination
    if ($null -eq $entry -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return
    }

    Write-Host "Replacing legacy PowerShell reparse point: $Destination" -ForegroundColor Yellow

    if (($entry.Attributes -band [IO.FileAttributes]::Directory) -ne 0) {
        [IO.Directory]::Delete($Destination)
    }
    else {
        [IO.File]::Delete($Destination)
    }
}

function Copy-RuntimeFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not [IO.File]::Exists($Source)) {
        throw "PowerShell source file not found: $Source"
    }

    Ensure-DestinationDirectory -Destination $Destination
    Remove-LegacyDestinationLink -Destination $Destination

    try {
        [IO.File]::Copy($Source, $Destination, $true)
    }
    catch {
        throw "Unable to deploy PowerShell runtime file '$Source' to '$Destination': $($_.Exception.Message)"
    }
}

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
    Copy-RuntimeFile -Source (Join-Path $sourceRoot $file.Source) -Destination $file.Destination
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
