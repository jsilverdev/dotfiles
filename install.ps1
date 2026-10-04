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

function Download-Fonts {
    $fonts = Join-Path $RepoRoot "fonts"
    New-Item -ItemType Directory -Force -Path $fonts | Out-Null

    if (-not (Test-Path (Join-Path $fonts "CascadiaCode.ttf"))) {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/cascadia-code/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
        $asset = @($release.assets | Where-Object name -Match '^CascadiaCode-.*\.zip$' | Select-Object -First 1)
        if ($asset.Count -ne 1) { throw "Unable to locate the Cascadia Code ZIP asset in the latest GitHub release." }

        $zip = Join-Path $fonts "CascadiaCode.zip"
        $extract = Join-Path $fonts "CascadiaCode"
        Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $zip
        Expand-Archive $zip -DestinationPath $extract -Force
        Remove-Item -Recurse -Force (Join-Path $extract "ttf\static") -ErrorAction SilentlyContinue
        Get-ChildItem -Path $extract -Filter *.ttf -Recurse -File | Move-Item -Destination $fonts -Force
        Remove-Item -Recurse -Force $zip, $extract
    }

    $nerdRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
    foreach ($font in @(
        @{ folder = (Join-Path $fonts "CaskaydiaCoveNerdFont"); filename = "CascadiaCode" },
        @{ folder = (Join-Path $fonts "CaskaydiaMonoNerdFont"); filename = "CascadiaMono" }
    )) {
        if (Test-Path "$($font.folder)-Regular.ttf") { continue }
        $zip = "$($font.folder).zip"
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/download/$($nerdRelease.tag_name)/$($font.filename).zip" -OutFile $zip
        Expand-Archive $zip -DestinationPath $font.folder -Force
        Get-ChildItem -Path $font.folder -Filter *.ttf -Recurse -File | Move-Item -Destination $fonts -Force
        Remove-Item -Recurse -Force $zip, $font.folder
    }
}

function Install-UserFonts {
    $sourceDir = Join-Path $RepoRoot "fonts"
    $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $fontRegistryKey = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        throw "Font source directory not found: $sourceDir"
    }

    New-Item -ItemType Directory -Path $userFontsDir -Force | Out-Null
    New-Item -Path $fontRegistryKey -Force | Out-Null

    $sourceFonts = @(Get-ChildItem -Path $sourceDir -Include *.otc,*.otf,*.ttc,*.ttf -Recurse -File)
    if ($sourceFonts.Count -eq 0) {
        throw "No font files were downloaded to $sourceDir."
    }

    foreach ($font in $sourceFonts | Sort-Object Name -Unique) {
        $destination = Join-Path $userFontsDir $font.Name
        $registryName = "$($font.Name) (dotfiles)"

        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            Copy-Item -LiteralPath $font.FullName -Destination $destination
        }

        $registeredPath = $null
        try {
            $registeredPath = Get-ItemPropertyValue -Path $fontRegistryKey -Name $registryName -ErrorAction Stop
        }
        catch {
        }

        if ($registeredPath -ne $destination) {
            New-ItemProperty -Path $fontRegistryKey -Name $registryName -Value $destination -PropertyType String -Force | Out-Null
        }
    }
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
