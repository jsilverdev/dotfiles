@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "D=%RUNNER_TEMP%\dotfiles-update-%GITHUB_RUN_ID%"
if exist "%D%" rmdir /s /q "%D%"
git clone "%DOTFILES_REPO%" "%D%" || exit /b 1
git -C "%D%" config user.name ci
git -C "%D%" config user.email ci@example.invalid
set "UPDATE_MARKER=ci-update-marker-%GITHUB_RUN_ID%"
>>"%D%\home\dot_fdignore" echo %UPDATE_MARKER%
git -C "%D%" add home/dot_fdignore
git -c commit.gpgsign=false -C "%D%" commit -m "CI update fixture" || exit /b 1
git -C "%D%" push origin HEAD:refs/heads/main || exit /b 1
>>"%GITHUB_ENV%" echo UPDATE_MARKER=%UPDATE_MARKER%
