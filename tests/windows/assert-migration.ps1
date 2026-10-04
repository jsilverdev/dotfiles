[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw "ASSERTION FAILED: $Message"
}

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

$fdignore = Get-DirectoryEntry -Path (Join-Path $HOME ".fdignore")
if ($null -eq $fdignore -or ($fdignore.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Fail "managed .fdignore was not restored as a regular file"
}

$starshipDirectory = Get-DirectoryEntry -Path (Join-Path $HOME ".config\starship")
if ($null -eq $starshipDirectory -or -not $starshipDirectory.PSIsContainer -or ($starshipDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Fail "managed starship parent was not restored as a regular directory"
}
if (-not (Test-Path -LiteralPath (Join-Path $HOME ".config\starship\config.toml") -PathType Leaf)) {
    Fail "managed starship config is missing"
}

$unrelated = Get-DirectoryEntry -Path (Join-Path $HOME ".dotfiles-ci-unrelated-broken-link")
if ($null -eq $unrelated -or -not (Test-BrokenLink -Item $unrelated)) {
    Fail "unrelated broken link was modified or removed"
}

Write-Host "Broken managed-link migration assertions passed."
