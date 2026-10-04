[CmdletBinding()]
param(
    [Alias("u")]
    [switch]$Update,

    [switch]$NonInteractive,


    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
$NonInteractive = $NonInteractive -or $env:DOTFILES_NONINTERACTIVE -eq "1"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = $PSScriptRoot
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$managedModulesPath = Join-Path $RepoRoot "scripts\windows\managed-modules.txt"
if (-not (Test-Path -LiteralPath $managedModulesPath -PathType Leaf)) {
    throw "The managed PowerShell module list is missing from $RepoRoot."
}
$ManagedModules = @(Get-Content -LiteralPath $managedModulesPath | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })

$managedAppsPath = Join-Path $RepoRoot "scripts\windows\managed-apps.csv"
if (-not (Test-Path -LiteralPath $managedAppsPath -PathType Leaf)) {
    throw "The managed WinGet application catalog is missing from $RepoRoot."
}
$ManagedApps = @(Import-Csv -LiteralPath $managedAppsPath)
if ($ManagedApps.Count -eq 0) {
    throw "The managed WinGet application catalog is empty."
}

function Refresh-Path {
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $pathEntries = foreach ($pathValue in @(
        $PSHOME
        $env:Path
        [Environment]::GetEnvironmentVariable("Path", "Machine")
        [Environment]::GetEnvironmentVariable("Path", "User")
    )) {
        if ([string]::IsNullOrWhiteSpace($pathValue)) { continue }
        foreach ($entry in $pathValue -split [IO.Path]::PathSeparator) {
            $entry = $entry.Trim()
            if ($entry -and $seen.Add($entry)) { $entry }
        }
    }

    $env:Path = $pathEntries -join [IO.Path]::PathSeparator
}

function Check-RequiredApps {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "This installer requires PowerShell 7 or newer."
    }
    foreach ($command in @("git", "winget")) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            throw "$command is not available. Run bootstrap.cmd first."
        }
    }
}

function Invoke-SigningHelper {
    param(
        [Parameter(Mandatory)][ValidateSet("ProtectFiles", "ProtectModule")][string]$Action,
        [string[]]$Path,
        [string]$ModuleName
    )

    if ($env:DOTFILES_SIGNING_REQUIRED -ne "1" -and (Get-ExecutionPolicy) -ne "AllSigned") {
        return
    }

    $helper = Join-Path $RepoRoot "scripts\windows\signing.ps1"
    $bridge = Join-Path $RepoRoot "scripts\windows\invoke-ps-script.cmd"
    if (-not (Test-Path -LiteralPath $helper) -or -not (Test-Path -LiteralPath $bridge)) {
        throw "The centralized PowerShell signing helper is missing from $RepoRoot."
    }

    $arguments = @($helper, "-Action", $Action)
    if ($Path) { $arguments += @("-Path") + $Path }
    if ($ModuleName) { $arguments += @("-ModuleName", $ModuleName) }
    & $bridge @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "The centralized PowerShell signing helper failed for $Action."
    }
}
function Save-ManagedModuleForAllSigned {
    param([Parameter(Mandatory)][string]$Name)

    $windowsPowerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
        throw "Windows PowerShell is required to provision modules under AllSigned."
    }

    # Download directly into the PowerShell 7 current-user module root without
    # loading PowerShellGet or PackageManagement inside pwsh under AllSigned.
    $moduleRoot = Join-Path $HOME "Documents\PowerShell\Modules"
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

    $escapedName = $Name.Replace("'", "''")
    $escapedRoot = $moduleRoot.Replace("'", "''")
    $command = @(
        "`$ErrorActionPreference = 'Stop'"
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12"
        "Save-Module -Name '$escapedName' -Path '$escapedRoot' -Repository PSGallery -Force -AcceptLicense"
    ) -join [Environment]::NewLine
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

    $originalPSModulePath = $env:PSModulePath
    try {
        $env:PSModulePath = @(
            (Join-Path $HOME "Documents\WindowsPowerShell\Modules")
            (Join-Path $env:ProgramFiles "WindowsPowerShell\Modules")
            (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\Modules")
        ) -join [IO.Path]::PathSeparator

        & $windowsPowerShell -NoProfile -NonInteractive -EncodedCommand $encodedCommand
        if ($LASTEXITCODE -ne 0) {
            throw "Windows PowerShell could not save module '$Name' for PowerShell 7 (exit code $LASTEXITCODE)."
        }
    }
    finally {
        $env:PSModulePath = $originalPSModulePath
    }
}

function Install-WithWinget {
    param(
        [Parameter(Mandatory)][string]$AppId,
        [string]$Alias,
        [string]$Scope,
        [switch]$Update
    )

    $installed = if ($Alias) {
        $null -ne (Get-Command -Name $Alias -ErrorAction SilentlyContinue)
    }
    else {
        & winget list --id $AppId --exact --source winget --accept-source-agreements *> $null
        $LASTEXITCODE -eq 0
    }

    $scopeArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($Scope)) {
        $scopeArgs = @("--scope", $Scope)
    }

    if (-not $installed) {
        Write-Host "Installing $AppId..." -ForegroundColor Cyan
        & winget install --id $AppId --exact --source winget @scopeArgs --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { throw "WinGet could not install $AppId in scope '$Scope' (exit code $LASTEXITCODE)." }
        return
    }

    if (-not $Update) {
        Write-Host "$AppId is already installed" -ForegroundColor Green
        return
    }

    $upgradeCandidates = @(
        & winget list --upgrade-available --id $AppId --exact --source winget --accept-source-agreements 2>&1 |
            ForEach-Object { [string]$_ }
    )
    $upgradeAvailable = @($upgradeCandidates | Where-Object { $_ -match [regex]::Escape($AppId) }).Count -gt 0
    if (-not $upgradeAvailable) {
        Write-Host "$AppId is already up to date" -ForegroundColor Green
        return
    }

    Write-Host "Updating $AppId..." -ForegroundColor Yellow
    & winget upgrade --id $AppId --exact --source winget @scopeArgs --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "WinGet could not update $AppId (exit code $LASTEXITCODE)." }
}

function Install-MustHaveApps {
    Write-Host "Installing baseline apps..." -ForegroundColor Cyan

    $coreApps = @($ManagedApps | Where-Object Category -eq "core")
    foreach ($app in $coreApps) {
        Install-WithWinget -AppId $app.AppId -Alias $app.Alias -Scope $app.Scope -Update:$Update
    }

    if (-not $NonInteractive) {
        foreach ($app in @($ManagedApps | Where-Object Category -eq "workstation")) {
            Install-WithWinget -AppId $app.AppId -Alias $app.Alias -Scope $app.Scope -Update:$Update
        }
    }
    else {
        Write-Host "Skipping workstation applications in non-interactive mode." -ForegroundColor Yellow
    }

    Refresh-Path
    foreach ($app in $coreApps) {
        if ([string]::IsNullOrWhiteSpace($app.Alias)) { continue }
        if (-not (Get-Command -Name $app.Alias -ErrorAction SilentlyContinue)) {
            throw "Baseline CLI tool '$($app.Alias)' is unavailable after WinGet provisioning."
        }
    }

    if ($Update) {
        & mise use -g starship@latest
        if ($LASTEXITCODE -ne 0) { throw "mise could not update starship." }
    }
    else {
        & mise which starship *> $null
        if ($LASTEXITCODE -ne 0) {
            & mise use -g starship@latest
            if ($LASTEXITCODE -ne 0) { throw "mise could not install starship." }
        }
    }

    $allSigned = $env:DOTFILES_SIGNING_REQUIRED -eq "1"
    $userModuleRoots = @(
        (Join-Path $HOME "Documents\PowerShell\Modules"),
        (Join-Path $HOME ".local\share\powershell\Modules")
    )

    foreach ($module in $ManagedModules) {
        $installedModule = @(Get-Module -ListAvailable -Name $module | Where-Object {
            $moduleBase = [IO.Path]::GetFullPath($_.ModuleBase).TrimEnd([IO.Path]::DirectorySeparatorChar)
            @($userModuleRoots | Where-Object {
                $root = [IO.Path]::GetFullPath($_).TrimEnd([IO.Path]::DirectorySeparatorChar)
                $moduleBase.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
                $moduleBase.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
            }).Count -gt 0
        } | Select-Object -First 1)

        if ($installedModule.Count -eq 0 -or $Update) {
            $verb = if ($installedModule.Count -eq 0) { "Installing" } else { "Updating" }
            Write-Host "$verb $module module..." -ForegroundColor Cyan

            if ($allSigned) {
                Save-ManagedModuleForAllSigned -Name $module
            }
            else {
                Install-Module -Name $module -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -AcceptLicense -Confirm:$false
            }
        }
        else {
            Write-Host "$module module is already installed" -ForegroundColor Green
        }

        Invoke-SigningHelper -Action ProtectModule -ModuleName $module
    }
}

function Install-OptionalApps {
    if ($NonInteractive) {
        Write-Host "Skipping optional applications in non-interactive mode." -ForegroundColor Yellow
        return
    }

    $optionalApps = @($ManagedApps | Where-Object Category -eq "optional")
    Write-Host "             Optionals"
    Write-Host "-----------------------------------" -ForegroundColor Cyan
    for ($i = 0; $i -lt $optionalApps.Count; $i++) {
        Write-Host ("{0}. Install {1}" -f ($i + 1), $optionalApps[$i].Name)
    }
    Write-Host "You can use ranges like 1-4 or individual numbers separated by commas" -ForegroundColor Yellow

    $rawOptions = Read-Host "Select options [e.g. 1-4,8,10]"
    $options = @()
    foreach ($option in $rawOptions -split ',') {
        $option = $option.Trim()
        if ($option -match '^(\d+)-(\d+)$' -and [int]$Matches[1] -le [int]$Matches[2]) {
            $options += [int]$Matches[1]..[int]$Matches[2]
        }
        elseif ($option -match '^\d+$') {
            $options += [int]$option
        }
    }

    $options = @($options | Where-Object { $_ -gt 0 -and $_ -le $optionalApps.Count } | Select-Object -Unique | Sort-Object)
    foreach ($index in $options) {
        $app = $optionalApps[$index - 1]
        Write-Host "Installing $($app.Name)..." -ForegroundColor Cyan
        Install-WithWinget -AppId $app.AppId -Alias $app.Alias -Scope $app.Scope -Update:$Update
    }
    if ($options.Count -eq 0) { Write-Host "Skipping optional installs..." -ForegroundColor Yellow }
    Refresh-Path
}

function Expand-FontArchive {
    param(
        [Parameter(Mandatory)][string]$Archive,
        [Parameter(Mandatory)][string]$Destination
    )

    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($null -eq $tar) {
        throw "tar.exe is required to extract font archives."
    }

    Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    & $tar.Source -xf $Archive -C $Destination
    if ($LASTEXITCODE -ne 0) {
        throw "Font archive extraction failed for $Archive (exit code $LASTEXITCODE)."
    }
}

function Get-ManagedFontPatterns {
    $manifest = Join-Path $RepoRoot "scripts\windows\managed-fonts.txt"
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "The managed font manifest is missing from $RepoRoot."
    }

    return @(Get-Content -LiteralPath $manifest | Where-Object {
        $_.Trim() -and -not $_.Trim().StartsWith("#")
    } | ForEach-Object { $_.Trim() })
}

function Download-Fonts {
    $fonts = Join-Path $RepoRoot "fonts"
    New-Item -ItemType Directory -Force -Path $fonts | Out-Null

    if (@(Get-ChildItem -LiteralPath $fonts -Filter "CascadiaCode*.ttf" -File -ErrorAction SilentlyContinue).Count -eq 0) {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/cascadia-code/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
        $asset = @($release.assets | Where-Object name -Match '^CascadiaCode-.*\.zip$' | Select-Object -First 1)
        if ($asset.Count -ne 1) {
            throw "Unable to locate the Cascadia Code ZIP asset in the latest GitHub release."
        }

        $archive = Join-Path $fonts "CascadiaCode.zip"
        $extract = Join-Path $fonts ".extract-CascadiaCode"
        try {
            Write-Host "Downloading Cascadia Code..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $archive
            Expand-FontArchive -Archive $archive -Destination $extract
            Remove-Item -Recurse -Force (Join-Path $extract "ttf\static") -ErrorAction SilentlyContinue

            $fontFiles = @(Get-ChildItem -LiteralPath $extract -Filter *.ttf -Recurse -File)
            if ($fontFiles.Count -eq 0) {
                throw "Cascadia Code archive did not contain any TTF files."
            }
            $fontFiles | Move-Item -Destination $fonts -Force
        }
        finally {
            Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($font in @(
        @{ Name = "Caskaydia Cove Nerd Font"; Asset = "CascadiaCode"; Pattern = "CaskaydiaCove*.ttf" },
        @{ Name = "Caskaydia Mono Nerd Font"; Asset = "CascadiaMono"; Pattern = "CaskaydiaMono*.ttf" }
    )) {
        if (@(Get-ChildItem -LiteralPath $fonts -Filter $font.Pattern -File -ErrorAction SilentlyContinue).Count -gt 0) {
            continue
        }

        $archive = Join-Path $fonts "$($font.Asset).tar.xz"
        $extract = Join-Path $fonts ".extract-$($font.Asset)"
        try {
            Write-Host "Downloading $($font.Name)..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$($font.Asset).tar.xz" -OutFile $archive
            Expand-FontArchive -Archive $archive -Destination $extract

            $fontFiles = @(Get-ChildItem -LiteralPath $extract -Filter *.ttf -Recurse -File)
            if ($fontFiles.Count -eq 0) {
                throw "$($font.Name) archive did not contain any TTF files."
            }
            $fontFiles | Move-Item -Destination $fonts -Force
        }
        finally {
            Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($requiredPattern in Get-ManagedFontPatterns) {
        if (@(Get-ChildItem -LiteralPath $fonts -Filter $requiredPattern -File -ErrorAction SilentlyContinue).Count -eq 0) {
            throw "Expected font files are missing after download: $requiredPattern"
        }
    }
}

function Install-UserFonts {
    $sourceDir = Join-Path $RepoRoot "fonts"
    $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $fontRegistrySubKey = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        throw "Font source directory not found: $sourceDir"
    }

    New-Item -ItemType Directory -Path $userFontsDir -Force | Out-Null

    $sourceFonts = @(Get-ChildItem -Path $sourceDir -Include *.otc,*.otf,*.ttc,*.ttf -Recurse -File | Sort-Object Name -Unique)
    if ($sourceFonts.Count -eq 0) {
        throw "No font files were downloaded to $sourceDir."
    }

    $registryKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($fontRegistrySubKey)
    if ($null -eq $registryKey) {
        throw "Unable to open the current-user font registry key."
    }

    try {
        foreach ($font in $sourceFonts) {
            $destination = Join-Path $userFontsDir $font.Name
            $registryName = "$($font.Name) (dotfiles)"

            if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                Copy-Item -LiteralPath $font.FullName -Destination $destination
            }

            $registeredPath = $registryKey.GetValue(
                $registryName,
                $null,
                [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
            )
            if ([string]$registeredPath -ne $destination) {
                $registryKey.SetValue($registryName, $destination, [Microsoft.Win32.RegistryValueKind]::String)
            }
        }
    }
    finally {
        $registryKey.Dispose()
    }

    Write-Host "Installed/registered $($sourceFonts.Count) current-user font files." -ForegroundColor Green
}

function Configure-Git {
    $localConfig = Join-Path $HOME ".gitconfig.local"
    if (-not (Test-Path -LiteralPath $localConfig)) { New-Item -ItemType File -Path $localConfig | Out-Null }
    Write-Host "Git successfully configured!" -ForegroundColor Green
}

function Configure-WindowsTerminal {
    $source = Join-Path $RepoRoot "assets\win-terminal\config.json"
    $destination = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path -LiteralPath $destination)) { Write-Host "Windows Terminal settings file not found. Skipping configuration." -ForegroundColor Yellow; return }
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { Write-Host "jq is unavailable. Skipping Windows Terminal configuration." -ForegroundColor Yellow; return }
    & jq --indent 4 --slurpfile src $source '. as $original | $src[0] | to_entries | map(select(.key != "profiles")) | reduce .[] as $item ($original; . * {($item.key): $item.value}) | . * {"profiles": {"defaults": $src[0].profiles.defaults}}' $destination | Set-Content -Path $destination
    if ($LASTEXITCODE -ne 0) { throw "Windows Terminal configuration merge failed." }
}

function Configure-Wsl {
    if ($NonInteractive) {
        Write-Host "Skipping WSL installation in non-interactive mode." -ForegroundColor Yellow
        return
    }
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Host "Installing WSL..." -ForegroundColor Cyan
        & wsl --install --no-distribution
    }
}

Refresh-Path
Check-RequiredApps

Download-Fonts
Install-UserFonts

Configure-Git
Install-MustHaveApps

if (-not $NonInteractive) {
    Configure-WindowsTerminal
    Install-OptionalApps
}
else {
    Write-Host "Skipping terminal configuration and optional applications in non-interactive mode." -ForegroundColor Yellow
}

Configure-Wsl
