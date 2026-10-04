[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw "ASSERTION FAILED: $Message"
}

function Resolve-ChezmoiRepoRoot {
    $sourcePath = ((& chezmoi.exe source-path 2>&1) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourcePath)) {
        Fail "unable to resolve chezmoi source path"
    }

    foreach ($candidate in @(
        $sourcePath,
        [IO.Path]::GetDirectoryName($sourcePath)
    )) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (
            (Test-Path -LiteralPath (Join-Path $candidate "install.ps1") -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $candidate "fonts") -PathType Container)
        ) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }

    Fail "unable to resolve the chezmoi working tree containing downloaded fonts from '$sourcePath'"
}

$sourceRepoRoot = Resolve-ChezmoiRepoRoot
$sourceDir = Join-Path $sourceRepoRoot "fonts"
$userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$fontRegistrySubKey = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
$manifest = Join-Path $RepoRoot "scripts\windows\managed-fonts.txt"

if (-not (Test-Path -LiteralPath $userFontsDir -PathType Container)) {
    Fail "current-user font directory is missing: $userFontsDir"
}
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    Fail "managed font manifest is missing: $manifest"
}

$sourceFonts = @(
    Get-ChildItem -Path $sourceDir -Include *.otc,*.otf,*.ttc,*.ttf -Recurse -File |
        Sort-Object Name -Unique
)
if ($sourceFonts.Count -eq 0) {
    Fail "no downloaded fonts were found in $sourceDir"
}

$requiredPatterns = @(
    Get-Content -LiteralPath $manifest |
        Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") } |
        ForEach-Object { $_.Trim() }
)

foreach ($requiredPattern in $requiredPatterns) {
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

Write-Host "Windows font assertions passed for $($sourceFonts.Count) installed font files from $sourceRepoRoot."
