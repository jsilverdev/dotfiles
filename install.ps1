[CmdletBinding()]
param(
    [Alias("u")]
    [switch]$Update,

    [switch]$NonInteractive,

    [switch]$CoreOnly,

    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
$NonInteractive = $NonInteractive -or $env:DOTFILES_NONINTERACTIVE -eq "1"
$CoreOnly = $CoreOnly -or $env:DOTFILES_CORE_ONLY -eq "1"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = $PSScriptRoot
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$managedModulesPath = Join-Path $RepoRoot "scripts\windows\managed-modules.txt"
if (-not (Test-Path -LiteralPath $managedModulesPath -PathType Leaf)) {
    throw "The managed PowerShell module list is missing from $RepoRoot."
}
$ManagedModules = @(Get-Content -LiteralPath $managedModulesPath | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })

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

    # The signing helper performs the effective-policy check. Calling it on a
    # normal-policy machine is intentionally a no-op.
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
        "$ErrorActionPreference = 'Stop'"
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
        [switch]$Update
    )

    $installed = $false
    if ($Alias) {
        $installed = $null -ne (Get-Command -Name $Alias -ErrorAction SilentlyContinue)
    }
    else {
        & winget list --id $AppId --exact --source winget --accept-source-agreements *> $null
        $installed = $LASTEXITCODE -eq 0
    }

    if (-not $installed) {
        Write-Host "Installing $AppId..." -ForegroundColor Cyan
        & winget install --id $AppId --exact --source winget --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { throw "WinGet could not install $AppId." }
    }
    elseif ($Update) {
        $upgradeCandidates = @(
            & winget list --upgrade-available --id $AppId --exact --source winget --accept-source-agreements 2>&1 |
                ForEach-Object { [string]$_ }
        )
        $upgradeAvailable = @($upgradeCandidates | Where-Object {
            $_ -match [regex]::Escape($AppId)
        }).Count -gt 0

        if (-not $upgradeAvailable) {
            Write-Host "$AppId is already up to date" -ForegroundColor Green
        }
        else {
            Write-Host "Updating $AppId..." -ForegroundColor Yellow
            & winget upgrade --id $AppId --exact --source winget --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                throw "WinGet could not update $AppId (exit code $LASTEXITCODE)."
            }
        }
    }
    else {
        Write-Host "$AppId is already installed" -ForegroundColor Green
    }
}

function Install-MustHaveApps {
    Write-Host "Installing must-have apps..." -ForegroundColor Cyan

    $corePackages = @(
        @{ AppId = "zyedidia.micro"; Alias = "micro" },
        @{ AppId = "lsd-rs.lsd"; Alias = "lsd" },
        @{ AppId = "sharkdp.bat"; Alias = "bat" },
        @{ AppId = "Fastfetch-cli.Fastfetch"; Alias = "fastfetch" },
        @{ AppId = "junegunn.fzf"; Alias = "fzf" },
        @{ AppId = "sharkdp.fd"; Alias = "fd" },
        @{ AppId = "dandavison.delta"; Alias = "delta" },
        @{ AppId = "jqlang.jq"; Alias = "jq" },
        @{ AppId = "BurntSushi.ripgrep.MSVC"; Alias = "rg" },
        @{ AppId = "jdx.mise"; Alias = "mise" }
    )
    $workstationPackages = @(
        @{ AppId = "7zip.7zip"; Alias = $null },
        @{ AppId = "Microsoft.PowerToys"; Alias = $null },
        @{ AppId = "Microsoft.VisualStudioCode"; Alias = "code" }
    )

    foreach ($package in $corePackages) {
        Install-WithWinget -AppId $package.AppId -Alias $package.Alias -Update:$Update
    }
    if (-not $CoreOnly) {
        foreach ($package in $workstationPackages) {
            Install-WithWinget -AppId $package.AppId -Alias $package.Alias -Update:$Update
        }
    }
    else {
        Write-Host "Skipping workstation-only WinGet packages in core-only mode." -ForegroundColor Yellow
    }

    Refresh-Path
    foreach ($command in @("micro", "lsd", "bat", "fastfetch", "fzf", "fd", "delta", "jq", "rg", "mise")) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            throw "Core CLI tool '$command' is unavailable after WinGet provisioning."
        }
    }

    & mise which starship *> $null
    if ($LASTEXITCODE -ne 0) {
        & mise use -g starship@latest
        if ($LASTEXITCODE -ne 0) { throw "mise could not install starship." }
    }

    $allSigned = (Get-ExecutionPolicy) -eq "AllSigned"
    foreach ($module in $ManagedModules) {
        $installedModule = Get-Module -ListAvailable -Name $module | Select-Object -First 1
        $installedResource = $null
        if (-not $allSigned -and (Get-Command Get-InstalledPSResource -ErrorAction SilentlyContinue)) {
            $installedResource = Get-InstalledPSResource -Name $module -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if ($null -eq $installedModule) {
            Write-Host "Installing $module module..." -ForegroundColor Cyan
            if ($allSigned) {
                Save-ManagedModuleForAllSigned -Name $module
            }
            else {
                Install-Module -Name $module -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -AcceptLicense -Confirm:$false
            }
        }
        elseif ($Update -and -not $CoreOnly) {
            Write-Host "Updating $module module..." -ForegroundColor Yellow
            if ($allSigned) {
                Save-ManagedModuleForAllSigned -Name $module
            }
            elseif ($null -ne $installedResource -and (Get-Command Update-PSResource -ErrorAction SilentlyContinue)) {
                Update-PSResource -Name $module -Scope CurrentUser -Force
            }
            else {
                Update-Module -Name $module -Force
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
        Write-Host "Skipping optional installs in non-interactive mode..." -ForegroundColor Yellow
        return
    }

    $optionalApps = @(
        @{ name = "Google Chrome"; install = { Install-WithWinget -AppId "Google.Chrome" -Update:$Update } },
        @{ name = "KeepassXC"; install = { Install-WithWinget -AppId "KeePassXCTeam.KeePassXC" -Update:$Update } },
        @{ name = "DBeaver"; install = { Install-WithWinget -AppId "dbeaver.dbeaver" -Update:$Update } },
        @{ name = "Postman"; install = { Install-WithWinget -AppId "Postman.Postman" -Update:$Update } },
        @{ name = "Bruno"; install = { Install-WithWinget -AppId "Bruno.Bruno" -Update:$Update } },
        @{ name = "kubectl"; install = { Install-WithWinget -AppId "Kubernetes.kubectl" -Alias "kubectl" -Update:$Update } },
        @{ name = "GIMP"; install = { Install-WithWinget -AppId "GIMP.GIMP" -Update:$Update } },
        @{ name = "Android Studio"; install = { Install-WithWinget -AppId "Google.AndroidStudio" -Update:$Update } },
        @{ name = "Steam"; install = { Install-WithWinget -AppId "Valve.Steam" -Update:$Update } },
        @{ name = "Discord"; install = { Install-WithWinget -AppId "Discord.Discord" -Update:$Update } },
        @{ name = "npiperelay"; install = { Install-WithWinget -AppId "albertony.npiperelay" -Alias "npiperelay" -Update:$Update } }
    )
    Write-Host "             Optionals"
    Write-Host "-----------------------------------" -ForegroundColor Cyan
    for ($i = 0; $i -lt $optionalApps.Count; $i++) { Write-Host ("{0}. Install {1}" -f ($i + 1), $optionalApps[$i].name) }
    Write-Host "You can use ranges like 1-4 or individual numbers separated by commas" -ForegroundColor Yellow

    $rawOptions = Read-Host "Select options [e.g. 1-4,8,10]"
    $options = @()
    foreach ($option in $rawOptions -split ',') {
        $option = $option.Trim()
        if ($option -match '^(\d+)-(\d+)$' -and [int]$Matches[1] -le [int]$Matches[2]) {
            $options += [int]$Matches[1]..[int]$Matches[2]
        }
        elseif ($option -match '^\d+$') { $options += [int]$option }
    }
    $options = @($options | Where-Object { $_ -gt 0 -and $_ -le $optionalApps.Count } | Select-Object -Unique | Sort-Object)
    foreach ($index in $options) {
        Write-Host "Installing $($optionalApps[$index - 1].name)..." -ForegroundColor Cyan
        $app = $optionalApps[$index - 1]
        & $app.install
    }
    if ($options.Count -eq 0) { Write-Host "Skipping optional installs..." -ForegroundColor Yellow }
    Refresh-Path
}

function Download-Fonts {
    $fonts = Join-Path $RepoRoot "fonts"
    New-Item -ItemType Directory -Force -Path $fonts | Out-Null
    $cascadia = Join-Path $fonts "CascadiaCode"
    if (-not (Test-Path "${cascadia}.ttf")) {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/cascadia-code/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
        Invoke-WebRequest -Uri $release.assets[0].browser_download_url -OutFile "${cascadia}.zip"
        Expand-Archive "${cascadia}.zip" -DestinationPath $cascadia
        Remove-Item -Recurse -Force "${cascadia}\ttf\static" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "${cascadia}\*.ttf" -Recurse | Move-Item -Destination $fonts
        Remove-Item -Recurse -Force "${cascadia}.zip", $cascadia
    }
    foreach ($font in @(
        @{ folder = (Join-Path $fonts "CaskaydiaCoveNerdFont"); filename = "CascadiaCode" },
        @{ folder = (Join-Path $fonts "CaskaydiaMonoNerdFont"); filename = "CascadiaMono" }
    )) {
        if (-not (Test-Path "$($font.folder)-Regular.ttf")) {
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }
            $zip = "$($font.folder).zip"
            Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/download/$($release.tag_name)/$($font.filename).zip" -OutFile $zip
            Expand-Archive $zip -DestinationPath $font.folder
            Get-ChildItem -Path "$($font.folder)\*.ttf" -Recurse | Move-Item -Destination $fonts
            Remove-Item -Recurse -Force $zip, $font.folder
        }
    }
}

function Install-UserFonts {
    $sourceDir = Join-Path $RepoRoot "fonts"
    $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $fontRegistryKey = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) { throw "Font source directory not found: $sourceDir" }
    New-Item -ItemType Directory -Path $userFontsDir -Force | Out-Null
    $sourceFonts = @(Get-ChildItem -Path $sourceDir -Include *.otc,*.otf,*.ttc,*.ttf -Recurse -File)
    foreach ($font in $sourceFonts | Sort-Object Name -Unique) {
        $destination = Join-Path $userFontsDir $font.Name
        if (Test-Path -LiteralPath $destination) { continue }
        Copy-Item -LiteralPath $font.FullName -Destination $destination
        New-ItemProperty -Path $fontRegistryKey -Name "$($font.Name) (dotfiles)" -Value $destination -PropertyType String -Force | Out-Null
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
    if ($NonInteractive -or $CoreOnly) {
        Write-Host "Skipping WSL installation in non-interactive/core-only mode..." -ForegroundColor Yellow
        return
    }

    if (Get-Command wsl -ErrorAction SilentlyContinue) { Write-Host "Installing WSL..." -ForegroundColor Cyan; & wsl --install --no-distribution }
}

Refresh-Path
Check-RequiredApps
if (-not $CoreOnly) {
    Download-Fonts
    Install-UserFonts
}
Configure-Git
Install-MustHaveApps
if (-not $CoreOnly) { Configure-WindowsTerminal }
Install-OptionalApps
Configure-Wsl
