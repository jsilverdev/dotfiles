@echo off
setlocal EnableExtensions

where chezmoi.exe >nul 2>&1
if errorlevel 1 (
    echo Core tools are unavailable; running bootstrap.cmd...
    call "%~dp0bootstrap.cmd"
    exit /b %ERRORLEVEL%
)

chezmoi.exe update
if errorlevel 1 exit /b %ERRORLEVEL%

call :resolve_repo_root
if not defined REPO_ROOT (
    echo Unable to resolve the chezmoi working tree. 1>&2
    exit /b 1
)
call "%REPO_ROOT%\scripts\windows\invoke-ps-script.cmd" "%REPO_ROOT%\install.ps1" -Update -RepoRoot "%REPO_ROOT%"
exit /b %ERRORLEVEL%

:resolve_repo_root
set "REPO_ROOT="
for /f "delims=" %%R in ('chezmoi.exe execute-template "{{ .chezmoi.workingTree }}" 2^>nul') do set "REPO_ROOT=%%R"
if defined REPO_ROOT if exist "%REPO_ROOT%\install.ps1" exit /b 0
for /f "delims=" %%R in ('chezmoi.exe source-path 2^>nul') do set "SOURCE_ROOT=%%R"
if defined SOURCE_ROOT if exist "%SOURCE_ROOT%\install.ps1" (set "REPO_ROOT=%SOURCE_ROOT%"& exit /b 0)
if defined SOURCE_ROOT for %%P in ("%SOURCE_ROOT%\..") do if exist "%%~fP\install.ps1" (set "REPO_ROOT=%%~fP"& exit /b 0)
exit /b 1
