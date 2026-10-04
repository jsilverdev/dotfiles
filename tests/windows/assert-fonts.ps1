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
$fontRegistrySubKey = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
    Fail "font source directory is missing: $sourceDir"
}
if (-not (Test-Path -LiteralPath $userFontsDir -PathType Container)) {
    Fail "current-user font directory is missing: $userFontsDir"
}

$sourceFonts = @(Get-ChildItem -Path $sourceDir -Include *.otc,*.otf,*.ttc,*.ttf -Recurse -File | Sort-Object Name -Unique)
if ($sourceFonts.Count -eq 0) {
    Fail "no downloaded fonts were found in $sourceDir"
}

foreach ($requiredPattern in @("CascadiaCode*.ttf", "CaskaydiaCove*.ttf", "CaskaydiaMono*.ttf")) {
    if (@($sourceFonts | Where-Object Name -Like $requiredPattern).Count -eq 0) {
        Fail "expected font family is missing from the downloaded source: $requiredPattern"
    }
}

$registryKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($fontRegistrySubKey, $false)
if ($null -eq $registryKey) {
    Fail "current-user font registry key is missing: HKCU\$fontRegistrySubKey"
}

try {
    foreach ($font in $sourceFonts) {
        $destination = Join-Path $userFontsDir $font.Name
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            Fail "font was not installed for the current user: $destination"
        }

        $registryName = "$($font.Name) (dotfiles)"
        $registeredPath = $registryKey.GetValue(
            $registryName,
            $null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        )
        if ($null -eq $registeredPath) {
            Fail "font registry entry is missing: $registryName"
        }

        if (-not [string]::Equals(
            [IO.Path]::GetFullPath([string]$registeredPath),
            [IO.Path]::GetFullPath($destination),
            [StringComparison]::OrdinalIgnoreCase
        )) {
            Fail "font registry entry '$registryName' points to '$registeredPath' instead of '$destination'"
        }
    }
}
finally {
    $registryKey.Dispose()
}

Write-Host "Windows font assertions passed for $($sourceFonts.Count) installed font files."
