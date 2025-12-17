### Start Utils
function RefreshPath() {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function CheckRequiredApps() {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "This script requires PowerShell 7 or newer. Exiting..." -ForegroundColor Red
        exit
    }
    if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Please install Git before running this script." -ForegroundColor Red
        exit
    }
}

function EnsureDevModeIsEnabled() {
    try {
        if ((Get-WindowsDeveloperLicense).IsValid) {
            Write-Host "Developer Mode is Enabled" -ForegroundColor Green
        }
        else {
            Write-Host "Please enable the Developer Mode and RESTART!!! before continue" -ForegroundColor Red
            exit
        }
    }
    catch {
        Write-Host "An error occurred while checking the developer license: $_" -ForegroundColor Red
        exit
    }
}

function CheckWinget() {
    if ($null -eq (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
        Write-Output "Enable winget..."
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        RefreshPath
    }
}

function InstallWithWinget() {
    param(
        [string]$appId,
        [string]$alias,
        [switch]$update
    )

    if (-not ([string]::IsNullOrEmpty($alias))) {
        Get-Command -Name $alias -ErrorAction SilentlyContinue | Out-Null
    }
    else {
        winget list --accept-source-agreements -e --id $appId -n 1 | Out-Null
    }

    if (-not $?) {
        Write-Host "$appId is not installed. Installing..." -ForegroundColor Yellow
        winget install -e --accept-source-agreements --accept-package-agreements --id $appId
    }
    elseif ($update) {
        Write-Host "Updating $appId..." -ForegroundColor Yellow
        winget upgrade --accept-source-agreements --id $appId
    }
    else {
        Write-Host "$appId is already installed" -ForegroundColor Green
    }
}

function InstallPuroFVM {
    param(
        [switch]$update
    )
    if (Get-Command -Name puro -ErrorAction SilentlyContinue) {
        Write-Host "puro is already installed" -ForegroundColor Green
        if ($update) {
            puro upgrade-puro
        }
        return
    }
    Write-Host "Installing Puro FVM..." -ForegroundColor Cyan
    $apiUrl = "https://api.github.com/repos/pingbird/puro/releases/latest"
    $latestGitInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }
    $tagName = $latestGitInfo.tag_name
    Write-Host "version to install: $tagName" -ForegroundColor Cyan
    $puroBinary = "$env:temp\puro.exe"
    Invoke-WebRequest -Uri "https://puro.dev/builds/$tagName/windows-x64/puro.exe" -OutFile $puroBinary

    if ((Test-Path -Path $puroBinary)) {
        &"$puroBinary" install-puro --promote
    }
    else {
        Write-Host "puro cannot be downloaded" -ForegroundColor Red
    }

}

function FindPython3 {
    return Get-Command -Name python -ErrorAction SilentlyContinue |
    Where-Object { & $_.Source --version 2>&1 | Select-String -Pattern "^Python 3\.\d+\.\d+" } |
    Select-Object -First 1 -ExpandProperty Source
}
function InstallPython3 {
    $wingetPython3 = winget search "python.python.3" | Select-String "Python.Python" | ForEach-Object {
        # Extract both the Id (package name) and Version using regex
        if ($_ -match '(\S+)\s+(\S+)\s+(\d+\.\d+\.\d+)') {
            # Return both Id and Version as an object
            [PSCustomObject]@{
                Id      = $Matches[2]
                Version = [Version]$Matches[3]
            }
        }
    } | Sort-Object Version -Descending | Select-Object -First 1
    winget install -e --id $wingetPython3.Id
    RefreshPath
}

$updateFlag = $false
function InstallMustHaveApps {
    ### Start Installing must-have apps
    Write-Host "Installing must-have apps..." -ForegroundColor Cyan

    # Pregunta si deseas actualizar las aplicaciones existentes
    $updateChoice = Read-Host "Do you want to update existing apps? (Y/N)"
    if ($updateChoice -match "^[Yy]$") {
        $updateFlag = $true
    }

    $installs = @(
        $(InstallWithWinget -appId "7zip.7zip" -update:$updateFlag),
        $(InstallWithWinget -appId "Microsoft.PowerToys" -update:$updateFlag),
        $(InstallWithWinget -appId "Starship.Starship" -alias "starship" -update:$updateFlag),
        $(InstallWithWinget -appId "zyedidia.micro" -alias "micro" -update:$updateFlag),
        $(InstallWithWinget -appId "lsd-rs.lsd" -alias "lsd" -update:$updateFlag),
        $(InstallWithWinget -appId "sharkdp.bat" -alias "bat" -update:$updateFlag),
        $(InstallWithWinget -appId "Fastfetch-cli.Fastfetch" -alias "fastfetch" -update:$updateFlag),
        $(InstallWithWinget -appId "junegunn.fzf" -alias "fzf" -update:$updateFlag),
        $(InstallWithWinget -appId "sharkdp.fd" -alias "fd" -update:$updateFlag),
        $(InstallWithWinget -appId "dandavison.delta" -alias "delta" -update:$updateFlag),
        $(InstallWithWinget -appId "jqlang.jq" -alias "jq" -update:$updateFlag),
        $(InstallWithWinget -appId "Microsoft.VisualStudioCode" -alias "code" -update:$updateFlag),
        $(InstallWithWinget -appId "BiomeJS.Biome" -alias "biome" -update:$updateFlag)
    )

    foreach ($install in $installs) {
        $install
    }

    # Install must-have modules
    $modules = @(
        "PSFzf",
        "git-aliases"
    )
    foreach ($module in $modules) {
        if (Get-InstalledPSResource -Name $module -ErrorAction SilentlyContinue) {
            Write-Host "$module module is already installed" -ForegroundColor Green

            if ($updateFlag) {
                Write-Host "Updating $module module..." -ForegroundColor Yellow
                Update-PSResource -Name $module -Scope CurrentUser -Force
            }
            continue
        }

        Write-Host "Installing $module module..." -ForegroundColor Cyan
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
    }
    ### End Installing must-have apps
}

function SetupDotFiles {

    $BASEDIR = $PSScriptRoot

    ### Start DotBot
    $DOTBOT_BIN = "bin/dotbot"
    $DOTBOT_DIR = "lib/dotbot"

    Set-Location $BASEDIR

    $PYTHON = FindPython3
    if ([string]::IsNullOrEmpty($PYTHON)) {
        Write-Host "Cannot find Python 3. Installing..." -ForegroundColor Yellow
        InstallPython3
        $PYTHON = FindPython3

        if ([string]::IsNullOrEmpty($PYTHON)) {
            Write-Host "Error: Python can't not be found. Aborting..." -ForegroundColor Red
            exit
        }
    }
    Write-Host "Running Dotbot..." -ForegroundColor Cyan
    $env:PROFILE_LOCATION = $profile.CurrentUserAllHosts ## PROFILE_LOCATION

    $DOTBOT_FULL_PATH_BIN = Join-Path $BASEDIR -ChildPath $DOTBOT_DIR | Join-Path -ChildPath $DOTBOT_BIN

    $BASE_CONFIG = "base"
    $CONFIG_SUFFIX = ".yaml"
    $META_DIR = "meta"
    $CONFIG_DIR = "configs"

    &$PYTHON $DOTBOT_FULL_PATH_BIN -d $BASEDIR -c "${META_DIR}/${BASE_CONFIG}${CONFIG_SUFFIX}"

    $CONFIGS = @(
        "pwsh",
        "windows"
    )

    foreach ($CONFIG in $CONFIGS) {
        &$PYTHON $DOTBOT_FULL_PATH_BIN -d $BASEDIR -c "${META_DIR}/${CONFIG_DIR}/${CONFIG}${CONFIG_SUFFIX}"
    }
    ### End DotBot
}

function InstallOptionalApps {
    ### Start Installing optional apps

    $optionalApps = @(
        @{ name = "Google Chrome" ; install = { InstallWithWinget -appId "Google.Chrome" -update:$updateFlag } },
        @{ name = "KeepassXC" ; install = { InstallWithWinget -appId "KeePassXCTeam.KeePassXC" -update:$updateFlag } },
        @{ name = "mise-en-place" ; install = { InstallWithWinget -appId "jdx.mise" -alias "mise" -update:$updateFlag } },
        @{ name = "puro"; install = { InstallPuroFVM -update:$updateFlag } },
        @{ name = "DBeaver"; install = { InstallWithWinget -appId "dbeaver.dbeaver" -update:$updateFlag } },
        @{ name = "Postman"; install = { InstallWithWinget -appId "Postman.Postman" -update:$updateFlag } },
        @{ name = "Bruno"; install = { InstallWithWinget -appId "Bruno.Bruno" -update:$updateFlag } },
        @{ name = "kubectl"; install = { InstallWithWinget -appId "Kubernetes.kubectl" -alias "kubectl" -update:$updateFlag } },
        @{ name = "GIMP"; install = { InstallWithWinget -appId "GIMP.GIMP" -update:$updateFlag } },
        @{ name = "Android Studio"; install = { InstallWithWinget -appId "Google.AndroidStudio" -update:$updateFlag } },
        @{ name = "RustDesk"; install = { InstallWithWinget -appId "RustDesk.RustDesk" -update:$updateFlag } },
        @{ name = "npiperelay" ; install = { InstallWithWinget -appId "albertony.npiperelay" -alias "npiperelay" -update:$updateFlag } }
    )

    Write-Host "             Optionals"
    Write-Host "-----------------------------------" -ForegroundColor Cyan
    Write-Host "         Choose to Install"
    Write-Host "-----------------------------------" -ForegroundColor Cyan
    $optionalApps | ForEach-Object -Begin { $i = 1 } -Process { "$i. Install $($_.name)"; $i++ }
    Write-Host "-----------------------------------" -ForegroundColor Cyan
    Write-Host "You can use ranges like 1-4 or individual numbers separated by commas" -ForegroundColor Yellow

    $rawOptions = Read-Host ("Select options [e.g. 1-4,8,10]" )
    $options = @()

    foreach ($option in $rawOptions -split ',') {
        $option = $option.Trim()
        if ($option -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -le $end) {
                $options += $start..$end
            }
        }
        elseif ($option -match '^\d+$') {
            $options += [int]$option
        }
    }

    $options = $options | Where-Object { $_ -gt 0 -and $_ -le $optionalApps.Count } | Select-Object -Unique | Sort-Object

    if ($options.Count -eq 0) {
        Write-Host "Skipping optional installs..." -ForegroundColor Yellow
    }
    else {
        foreach ($index in $options) {
            $app = $optionalApps[$index - 1]
            Write-Host "Installing $($app.name)..." -ForegroundColor Cyan
            & $app.install
        }
        ## Refresh Path
        RefreshPath
    }
    ### End Installing optional apps
}

function DownloadFonts {
    $BASEDIR = $PSScriptRoot
    $FONTS = "$BASEDIR\fonts"

    if (!(Test-Path -Path "$FONTS")) {
        New-Item -ItemType Directory -Force -Path "$FONTS"
    }

    $CASCADIA_CODE = "$FONTS\CascadiaCode"

    if (!(Test-Path -Path "${CASCADIA_CODE}.ttf")) {
        $apiUrl = "https://api.github.com/repos/microsoft/cascadia-code/releases/latest"
        $latestGitInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }
        $browser_download_url = $latestGitInfo.assets[0].browser_download_url
        Invoke-WebRequest -Uri $browser_download_url -OutFile "${CASCADIA_CODE}.zip"
        Expand-Archive "${CASCADIA_CODE}.zip" -DestinationPath $CASCADIA_CODE
        Remove-Item -r -force "${CASCADIA_CODE}\ttf\static"
        Get-ChildItem -Path "${CASCADIA_CODE}\*.ttf" -Recurse | Move-Item -Destination $FONTS
        Remove-Item -r -force "${CASCADIA_CODE}.zip"
        Remove-Item -r -force "${CASCADIA_CODE}"
    }

    $apiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"

    $nFonts = @(
        @{ folder = "$FONTS\CaskaydiaCoveNerdFont"; filename = "CascadiaCode" },
        @{ folder = "$FONTS\CaskaydiaMonoNerdFont"; filename = "CascadiaMono" }
    )

    foreach ($nf in $nFonts) {
        $NF_FONT = $nf.folder
        $NF_FILENAME = $nf.filename

        if (!(Test-Path -Path "${NF_FONT}-Regular.ttf")) {
            $latestGitInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }
            $NF_VERSION = $latestGitInfo.tag_name
            $browser_download_url = "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/${NF_FILENAME}.zip"
            Invoke-WebRequest -Uri $browser_download_url -OutFile "${NF_FONT}.zip"
            Expand-Archive "${NF_FONT}.zip" -DestinationPath $NF_FONT
            Get-ChildItem -Path "${NF_FONT}\*.ttf" -Recurse | Move-Item -Destination $FONTS
            Remove-Item -r -force "${NF_FONT}.zip"
            Remove-Item -r -force "${NF_FONT}"
        }
    }


}

function ConfigureGit {
    # Create .gitconfig.local if not exists
    if (-not (Test-Path "$HOME\.gitconfig.local")) { New-Item -Path "$HOME\.gitconfig.local" -ItemType File }
    git submodule sync --quiet --recursive
    git submodule update --init --recursive
    Write-Host "Git successfully configured!" -ForegroundColor Green
}

function SettingsForWindowsTerminal {
    $source = "$PSScriptRoot\config\win-terminal\config.json"
    $destination = "$($env:LOCALAPPDATA)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    if (-not (Test-Path $destination)) {
        Write-Host "Windows Terminal settings file not found. Skipping configuration." -ForegroundColor Yellow
        return
    }

    jq --indent 4 --slurpfile src "$source" '
        . as $original |
        $src[0] |
        to_entries |
        map(select(.key != "profiles")) |
        reduce .[] as $item ($original;
            . * {($item.key): $item.value}
        ) |
        . * {"profiles": {"defaults": $src[0].profiles.defaults}}
    ' "$destination" | Set-Content -Path $destination
}

### End Utils

RefreshPath
CheckRequiredApps
EnsureDevModeIsEnabled
CheckWinget
DownloadFonts
ConfigureGit
InstallMustHaveApps
SetupDotFiles
SettingsForWindowsTerminal
InstallOptionalApps
