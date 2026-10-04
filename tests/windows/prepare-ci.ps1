$ErrorActionPreference="Stop"
cmd /c where winget.exe
if($LASTEXITCODE-ne0){Install-PackageProvider NuGet -Force|Out-Null;Install-Module Microsoft.WinGet.Client -Force -Repository PSGallery|Out-Null;Import-Module Microsoft.WinGet.Client -Force;Repair-WinGetPackageManager -Force -Latest}
cmd /c where winget.exe
if($LASTEXITCODE-ne0){throw "winget unavailable"}
@((Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),(Join-Path $env:LOCALAPPDATA "Programs\Microsoft.PowerShell"),(Join-Path $env:LOCALAPPDATA "Programs\mise"),(Join-Path $env:LOCALAPPDATA "Programs\chezmoi"))|%{Add-Content $env:GITHUB_PATH $_}
$remote=Join-Path $env:RUNNER_TEMP "dotfiles-remote-$env:GITHUB_RUN_ID.git";git init --bare $remote
$head=(git -C $env:GITHUB_WORKSPACE rev-parse HEAD).Trim();if($head-ne$env:GITHUB_SHA){throw "checkout mismatch"}
$uri="file:///"+$remote.Replace("\","/");git -C $env:GITHUB_WORKSPACE push $uri "$($env:GITHUB_SHA):refs/heads/main";if($LASTEXITCODE-ne0){throw "push failed"}
git --git-dir=$remote symbolic-ref HEAD refs/heads/main;Add-Content $env:GITHUB_ENV "DOTFILES_REPO=$uri"
