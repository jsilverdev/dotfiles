[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Get-DirectoryEntry {
    param([Parameter(Mandatory)][string]$Path)

    $parent = [IO.Path]::GetDirectoryName($Path)
    $leaf = [IO.Path]::GetFileName($Path)

    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) {
        return $null
    }

    Get-ChildItem -LiteralPath $parent -Force -ErrorAction Stop |
        Where-Object Name -eq $leaf |
        Select-Object -First 1
}

function Test-BrokenLink {
    param([Parameter(Mandatory)]$Item)

    if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return $false
    }

    try {
        $target = $Item.ResolveLinkTarget($true)
        return $null -eq $target -or -not $target.Exists
    }
    catch {
        return $true
    }
}

$managedPaths = @(& chezmoi.exe --source $RepoRoot managed --path-style absolute)
if ($LASTEXITCODE -ne 0) {
    throw "chezmoi managed failed with exit code $LASTEXITCODE."
}

$homeRoot = [IO.Path]::GetFullPath($HOME).TrimEnd([IO.Path]::DirectorySeparatorChar)

foreach ($managedPath in $managedPaths) {
    if ([string]::IsNullOrWhiteSpace($managedPath)) {
        continue
    }

    $fullPath = [IO.Path]::GetFullPath([string]$managedPath)
    $relativePath = [IO.Path]::GetRelativePath($homeRoot, $fullPath)

    if ([IO.Path]::IsPathRooted($relativePath) -or $relativePath -eq ".." -or $relativePath.StartsWith("..$([IO.Path]::DirectorySeparatorChar)")) {
        continue
    }

    $current = $homeRoot
    foreach ($component in $relativePath -split '[\\/]') {
        if ([string]::IsNullOrWhiteSpace($component) -or $component -eq ".") {
            continue
        }
        if ($component -eq "..") {
            break
        }

        $current = Join-Path $current $component
        $item = Get-DirectoryEntry -Path $current
        if ($null -eq $item) {
            break
        }

        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            if (Test-BrokenLink -Item $item) {
                Write-Host "Removing broken managed reparse point: $current" -ForegroundColor Yellow
                if ($item.PSIsContainer) {
                    [IO.Directory]::Delete($current)
                }
                else {
                    [IO.File]::Delete($current)
                }
            }

            # Never traverse through a reparse point, whether valid or broken.
            break
        }
    }
}
