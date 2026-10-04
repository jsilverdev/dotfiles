[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw "ASSERTION FAILED: $Message"
}

$sourceDir = Join-Path $RepoRoot "fonts"
$userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$fontRegistryKey = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
    Fail "font source directory is missing: $sourceDir"
}
if (-not (Test-Path -LiteralPath $userFontsDir -PathType Container)) {
    Fail "current-user font directory is missing: $userFontsDir"
}
if (-not (Test-Path -LiteralPath $fontRegistryKey)) {
    Fail "current-user font registry key is missing: $fontRegistryKey"
}

$sourceFonts = @(Get-ChildItem -Path $sourceDir -Include *.otc,*.otf,*.ttc,*.ttf -Recurse -File | Sort-Object Name -Unique)
if ($sourceFonts.Count -eq 0) {
    Fail "no downloaded fonts were found in $sourceDir"
}

$requiredPatterns = @(
    "CascadiaCode*.ttf",
    "CaskaydiaCoveNerdFont*.ttf",
    "CaskaydiaMonoNerdFont*.ttf"
)
foreach ($pattern in $requiredPatterns) {
    if (@($sourceFonts | Where-Object Name -Like $pattern).Count -eq 0) {
        Fail "expected font family is missing from the downloaded source: $pattern"
    }
}

foreach ($font in $sourceFonts) {
    $destination = Join-Path $userFontsDir $font.Name
    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        Fail "font was not installed for the current user: $destination"
    }

    $registryName = "$($font.Name) (dotfiles)"
    try {
        $registeredPath = Get-ItemPropertyValue -Path $fontRegistryKey -Name $registryName -ErrorAction Stop
    }
    catch {
        Fail "font registry entry is missing: $registryName"
    }

    if ([string]$registeredPath -ne $destination) {
        Fail "font registry entry '$registryName' points to '$registeredPath' instead of '$destination'"
    }
}

Write-Host "Windows font assertions passed for $($sourceFonts.Count) installed font files."
