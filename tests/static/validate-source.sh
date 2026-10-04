#!/usr/bin/env bash
set -euo pipefail
cd "${GITHUB_WORKSPACE:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
files=(bootstrap.sh install.sh update.sh tests/linux/assert-state.sh tests/linux/run-ci.sh tests/static/validate-source.sh)
bash -n "${files[@]}"
shellcheck -x -S error "${files[@]}"
chezmoi --source "$PWD" managed >/dev/null
while IFS= read -r -d '' f; do chezmoi --source "$PWD" execute-template < "$f" >/dev/null; done < <(find "$PWD" -type f -name '*.tmpl' -print0)
[[ "$(tr -d '\r\n' < .chezmoiroot)" == home ]]
for p in home scripts/windows/invoke-ps-script.cmd scripts/windows/invoke-ps-script-bridge.ps1 scripts/windows/signing.ps1 scripts/windows/deploy-pwsh.ps1 scripts/windows/managed-modules.txt home/.chezmoiscripts/run_after_90-deploy-pwsh.cmd.tmpl; do [[ -e "$p" ]] || { echo "missing: $p" >&2; exit 1; }; done
! git ls-files | grep -E '(^|/)symlink_[^/]*$'
! git grep -n -i dotbot -- ':!.github/workflows/validate.yml'
! git grep -n -E 'https://github\.com/jsilverdev/dotfiles\.git.*master|raw\.githubusercontent\.com/jsilverdev/dotfiles/master'
! git grep -n -E 'Set-ExecutionPolicy.*(Bypass|Unrestricted)|-ExecutionPolicy[[:space:]]+(Bypass|Unrestricted)' -- ':!.github/workflows/validate.yml'
! git grep -n -E 'PowerShellCore\\ShellIds|Software\\Microsoft\\PowerShell\\1\\ShellIds' -- '*.ps1' '*.psm1' '*.cmd'
! git grep -n '^# SIG # Begin signature block' -- '*.ps1' '*.psm1'
echo source-validation-ok
