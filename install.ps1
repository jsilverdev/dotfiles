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

function Test-DotfilesAllSignedPolicy {
    $locations = @(
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; Path = "Software\Policies\Microsoft\Windows\PowerShell" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; Path = "Software\Policies\Microsoft\Windows\PowerShell" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; Path = "Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; Path = "Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" }
    )
    foreach ($location in $locations) {
        $baseKey = $null
        $key = $null
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($location.Hive, [Microsoft.Win32.RegistryView]::Default)
            $key = $baseKey.OpenSubKey($location.Path)
            if ($null -ne $key) {
                $policy = $key.GetValue("ExecutionPolicy", $null)
                if (-not [string]::IsNullOrWhiteSpace($policy)) { return $policy -eq "AllSigned" }
            }
        }
        finally {
            if ($key) { $key.Dispose() }
            if ($baseKey) { $baseKey.Dispose() }
        }
    }
    return $false
}
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
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = @($machinePath, $userPath) -join ";"
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

    if (-not (Test-DotfilesAllSignedPolicy)) {
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
        & winget install --id $AppId --exact --source winget --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { throw "WinGet could not install $AppId." }
    }
    elseif ($Update) {
        Write-Host "Updating $AppId..." -ForegroundColor Yellow
        & winget upgrade --id $AppId --exact --source winget --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { throw "WinGet could not update $AppId." }
    }
    else {
        Write-Host "$AppId is already installed" -ForegroundColor Green
    }
}

function Install-MustHaveApps {
    Write-Host "Installing must-have apps..." -ForegroundColor Cyan
    $packageUpdate = $Update -and -not $CoreOnly
    $installs = if ($CoreOnly) {
        @(
            { Install-WithWinget -AppId "junegunn.fzf" -Alias "fzf" -Update:$packageUpdate },
            { Install-WithWinget -AppId "sharkdp.fd" -Alias "fd" -Update:$packageUpdate },
            { Install-WithWinget -AppId "lsd-rs.lsd" -Alias "lsd" -Update:$packageUpdate },
            { Install-WithWinget -AppId "sharkdp.bat" -Alias "bat" -Update:$packageUpdate },
            { Install-WithWinget -AppId "jdx.mise" -Alias "mise" -Update:$packageUpdate }
        )
    }
    else {
        @(
            { Install-WithWinget -AppId "7zip.7zip" -Update:$Update },
            { Install-WithWinget -AppId "Microsoft.PowerToys" -Update:$Update },
            { Install-WithWinget -AppId "zyedidia.micro" -Alias "micro" -Update:$Update },
            { Install-WithWinget -AppId "lsd-rs.lsd" -Alias "lsd" -Update:$Update },
            { Install-WithWinget -AppId "sharkdp.bat" -Alias "bat" -Update:$Update },
            { Install-WithWinget -AppId "Fastfetch-cli.Fastfetch" -Alias "fastfetch" -Update:$Update },
            { Install-WithWinget -AppId "junegunn.fzf" -Alias "fzf" -Update:$Update },
            { Install-WithWinget -AppId "sharkdp.fd" -Alias "fd" -Update:$Update },
            { Install-WithWinget -AppId "dandavison.delta" -Alias "delta" -Update:$Update },
            { Install-WithWinget -AppId "jqlang.jq" -Alias "jq" -Update:$Update },
            { Install-WithWinget -AppId "Microsoft.VisualStudioCode" -Alias "code" -Update:$Update },
            { Install-WithWinget -AppId "BurntSushi.ripgrep.MSVC" -Alias "rg" -Update:$Update },
            { Install-WithWinget -AppId "jdx.mise" -Alias "mise" -Update:$Update }
        )
    }
    foreach ($install in $installs) { & $install }

    Refresh-Path
    if (Get-Command mise -ErrorAction SilentlyContinue) {
        & mise use -g starship@latest
        if ($LASTEXITCODE -ne 0) { throw "mise could not install starship." }
    }

    foreach ($module in $ManagedModules) {
        $installedModule = Get-Module -ListAvailable -Name $module | Select-Object -First 1
        $installedResource = if (Get-Command Get-InstalledPSResource -ErrorAction SilentlyContinue) {
            Get-InstalledPSResource -Name $module -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($null -eq $installedModule) {
            Write-Host "Installing $module module..." -ForegroundColor Cyan
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
        }
        elseif ($Update -and -not $CoreOnly) {
            Write-Host "Updating $module module..." -ForegroundColor Yellow
            if ($null -ne $installedResource -and (Get-Command Update-PSResource -ErrorAction SilentlyContinue)) {
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
