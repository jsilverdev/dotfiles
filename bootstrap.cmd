@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO_URL=https://github.com/jsilverdev/dotfiles.git"

call :remove_legacy_broken_links
if errorlevel 1 exit /b 1

where winget.exe >nul 2>&1
if errorlevel 1 (
    echo WinGet is not registered for this user. Attempting App Installer registration...
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
    if errorlevel 1 (
        echo App Installer registration failed. WinGet may be disabled by corporate policy. 1>&2
        exit /b 1
    )
)
where winget.exe >nul 2>&1
if errorlevel 1 (
    echo WinGet is unavailable after App Installer registration. Check corporate policy or App Installer registration. 1>&2
    exit /b 1
)

call :ensure_package Git.Git git
if errorlevel 1 exit /b 1
call :ensure_package Microsoft.PowerShell pwsh
if errorlevel 1 exit /b 1
call :ensure_package jdx.mise mise
if errorlevel 1 exit /b 1
call :ensure_package twpayne.chezmoi chezmoi
if errorlevel 1 exit /b 1

call :refresh_path
where git.exe >nul 2>&1 || (echo Git is still unavailable after installation. 1>&2 & exit /b 1)
where pwsh.exe >nul 2>&1 || (echo PowerShell 7 is still unavailable after installation. 1>&2 & exit /b 1)
where mise.exe >nul 2>&1 || (echo mise is still unavailable after installation. 1>&2 & exit /b 1)
where chezmoi.exe >nul 2>&1 || (echo chezmoi is still unavailable after installation. 1>&2 & exit /b 1)

call :initialize_chezmoi
if errorlevel 1 (
    echo chezmoi initialization/update failed. 1>&2
    exit /b 1
)

call :resolve_repo_root
if not defined REPO_ROOT (
    echo Unable to resolve the chezmoi working tree. 1>&2
    exit /b 1
)
if not exist "%REPO_ROOT%\scripts\windows\invoke-ps-script.cmd" (
    echo Resolved chezmoi working tree does not contain the dotfiles scripts: "%REPO_ROOT%" 1>&2
    exit /b 1
)

call "%REPO_ROOT%\scripts\windows\invoke-ps-script.cmd" "%REPO_ROOT%\install.ps1" -RepoRoot "%REPO_ROOT%"
exit /b %ERRORLEVEL%

:ensure_package
set "PACKAGE_ID=%~1"
set "PACKAGE_COMMAND=%~2"
where "%PACKAGE_COMMAND%.exe" >nul 2>&1
if not errorlevel 1 exit /b 0
echo Installing %PACKAGE_ID% for the current user...
winget.exe install --id "%PACKAGE_ID%" --exact --source winget --scope user --silent --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
    echo Unable to install %PACKAGE_ID% without administrator rights. No machine-scope or portable fallback will be attempted. 1>&2
    exit /b 1
)
exit /b 0

:remove_legacy_broken_links
rem Remove only broken legacy links so Git and chezmoi can migrate them
rem to regular files. Existing valid links and unrelated junctions are kept.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "$paths = @('%USERPROFILE%\.gitconfig','%USERPROFILE%\.gitconfig.local','%USERPROFILE%\.fdignore','%USERPROFILE%\.npmrc','%USERPROFILE%\.vimrc','%USERPROFILE%\.zshenv','%USERPROFILE%\.wslconfig','%USERPROFILE%\.ssh\jsilverdev.pub','%USERPROFILE%\.config\starship\config.toml','%USERPROFILE%\.config\starship\lean.config.toml','%USERPROFILE%\.codex\AGENTS.md','%USERPROFILE%\.codex\skills\mule-munit\SKILL.md','%USERPROFILE%\.codex\skills\mule-munit\agents\openai.yaml','%USERPROFILE%\Documents\PowerShell\profile.ps1'); foreach ($path in $paths) { if (Test-Path -LiteralPath $path) { $item = Get-Item -LiteralPath $path -Force; if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -and -not (Test-Path -LiteralPath $item.Target)) { Remove-Item -LiteralPath $path -Force } } }"
if errorlevel 1 (
    echo Unable to clean broken legacy dotfile links. 1>&2
    exit /b 1
)
exit /b 0

:refresh_path
set "PATH=%PATH%;%LOCALAPPDATA%\Microsoft\WinGet\Links;%LOCALAPPDATA%\Programs\Microsoft.PowerShell;%LOCALAPPDATA%\Programs\mise;%LOCALAPPDATA%\Programs\chezmoi"
for /f "tokens=2,*" %%A in ('reg query HKCU\Environment /v Path 2^>nul ^| findstr /i "Path"') do set "PATH=!PATH!;%%B"
exit /b 0

:resolve_repo_root
set "REPO_ROOT="
if exist "%CD%\.chezmoiroot" if exist "%CD%\install.ps1" (set "REPO_ROOT=%CD%"& exit /b 0)
for /f "delims=" %%R in ('chezmoi.exe execute-template "{{ .chezmoi.workingTree }}" 2^>nul') do set "REPO_ROOT=%%R"
if defined REPO_ROOT if exist "%REPO_ROOT%\install.ps1" exit /b 0
for /f "delims=" %%R in ('chezmoi.exe source-path 2^>nul') do set "SOURCE_ROOT=%%R"
if defined SOURCE_ROOT if exist "%SOURCE_ROOT%\install.ps1" (set "REPO_ROOT=%SOURCE_ROOT%"& exit /b 0)
if defined SOURCE_ROOT for %%P in ("%SOURCE_ROOT%\..") do if exist "%%~fP\install.ps1" (set "REPO_ROOT=%%~fP"& exit /b 0)
exit /b 1

:initialize_chezmoi
if exist "%CD%\.chezmoiroot" (
    chezmoi.exe --source "%CD%" apply
    exit /b %ERRORLEVEL%
)
set "SOURCE_ROOT="
for /f "delims=" %%R in ('chezmoi.exe source-path 2^>nul') do set "SOURCE_ROOT=%%R"
if defined SOURCE_ROOT if exist "%SOURCE_ROOT%\.chezmoiroot" goto existing_chezmoi
if defined SOURCE_ROOT for %%P in ("%SOURCE_ROOT%\..") do if exist "%%~fP\.chezmoiroot" goto existing_chezmoi
chezmoi.exe init --apply "%REPO_URL%"
exit /b %ERRORLEVEL%

:existing_chezmoi
chezmoi.exe update
exit /b %ERRORLEVEL%
