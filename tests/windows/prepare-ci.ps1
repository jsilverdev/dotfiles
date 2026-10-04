$ErrorActionPreference = "Stop"

function Ensure-WinGet {
    cmd /c where winget.exe
    if ($LASTEXITCODE -eq 0) { return }

    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Import-Module Microsoft.WinGet.Client -Force
    Repair-WinGetPackageManager -Force -Latest

    cmd /c where winget.exe
    if ($LASTEXITCODE -ne 0) { throw "winget.exe is unavailable after repair." }
}

function Add-CiUserPaths {
    @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft.PowerShell"),
        (Join-Path $env:LOCALAPPDATA "Programs\chezmoi")
    ) | ForEach-Object { Add-Content -Path $env:GITHUB_PATH -Value $_ }
}

function New-ExactCommitRemote {
    $remote = Join-Path $env:RUNNER_TEMP "dotfiles-remote-$env:GITHUB_RUN_ID.git"
    git init --bare $remote
    if ($LASTEXITCODE -ne 0) { throw "Unable to create the local bare Git remote." }

    $head = (git -C $env:GITHUB_WORKSPACE rev-parse HEAD).Trim()
    if ($head -ne $env:GITHUB_SHA) { throw "Checkout $head does not match GITHUB_SHA $env:GITHUB_SHA." }

    $uri = "file:///" + $remote.Replace("\", "/")
    git -C $env:GITHUB_WORKSPACE push $uri "$($env:GITHUB_SHA):refs/heads/main"
    if ($LASTEXITCODE -ne 0) { throw "Unable to push the checked-out commit to the local remote." }

    git --git-dir=$remote symbolic-ref HEAD refs/heads/main
    if ($LASTEXITCODE -ne 0) { throw "Unable to set the local remote HEAD." }

    Add-Content -Path $env:GITHUB_ENV -Value "DOTFILES_REPO=$uri"
}

Ensure-WinGet
Add-CiUserPaths
New-ExactCommitRemote
