#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$repo_root"

validate_shell() {
    local shell_files=(
        bootstrap.sh
        install.sh
        update.sh
        tests/linux/assert-state.sh
        tests/linux/run-ci.sh
        tests/static/validate-source.sh
    )
    bash -n "${shell_files[@]}"
    shellcheck -x -S error "${shell_files[@]}"
}

validate_chezmoi() {
    chezmoi --source "$repo_root" managed >/dev/null
    while IFS= read -r -d '' template; do
        chezmoi --source "$repo_root" execute-template < "$template" >/dev/null
    done < <(find "$repo_root" -type f -name '*.tmpl' -print0)
}

validate_paths() {
    [[ "$(tr -d '\r\n' < .chezmoiroot)" == "home" ]] || {
        echo '.chezmoiroot must contain home' >&2
        exit 1
    }

    local required_paths=(
        home
        scripts/linux/packages-debian.txt
        scripts/linux/packages-arch.txt
        scripts/linux/required-commands.txt
        scripts/windows/managed-apps.csv
        scripts/windows/managed-modules.txt
        scripts/windows/invoke-ps-script.cmd
        scripts/windows/invoke-ps-script-bridge.ps1
        scripts/windows/signing.ps1
        scripts/windows/deploy-pwsh.ps1
        home/.chezmoiscripts/run_after_90-deploy-pwsh.cmd.tmpl
    )
    local path
    for path in "${required_paths[@]}"; do
        [[ -e "$path" ]] || { printf 'required path is missing: %s\n' "$path" >&2; exit 1; }
    done
}

validate_legacy() {
    if git grep -n -E 'DOTFILES_CORE_ONLY|CoreOnly|--core-only' -- ':!tests/static/validate-source.sh'; then
        echo 'obsolete core-only mode is still referenced' >&2
        exit 1
    fi
    if git ls-files | grep -E '(^|/)symlink_[^/]*$'; then
        echo 'chezmoi symlink source state is not allowed' >&2
        exit 1
    fi
    if git grep -n -i dotbot -- ':!.github/workflows/validate.yml'; then
        echo 'obsolete Dotbot dependency/reference found' >&2
        exit 1
    fi
    if git grep -n -E 'https://github\.com/jsilverdev/dotfiles\.git.*master|raw\.githubusercontent\.com/jsilverdev/dotfiles/master'; then
        echo 'obsolete master bootstrap URL found' >&2
        exit 1
    fi
}

validate_policy() {
    if git grep -n -E 'Set-ExecutionPolicy.*(Bypass|Unrestricted)|-ExecutionPolicy[[:space:]]+(Bypass|Unrestricted)' -- ':!.github/workflows/validate.yml'; then
        echo 'production execution-policy weakening found' >&2
        exit 1
    fi
    if git grep -n -E 'PowerShellCore\\ShellIds|Software\\Microsoft\\PowerShell\\1\\ShellIds' -- '*.ps1' '*.psm1' '*.cmd'; then
        echo 'implementation-specific execution-policy registry probing found' >&2
        exit 1
    fi
}

validate_signatures() {
    if git grep -n '^# SIG # Begin signature block' -- '*.ps1' '*.psm1'; then
        echo 'signed PowerShell source was committed' >&2
        exit 1
    fi
}

case "${1:-all}" in
    shell) validate_shell ;;
    chezmoi) validate_chezmoi ;;
    paths) validate_paths ;;
    legacy) validate_legacy ;;
    policy) validate_policy ;;
    signatures) validate_signatures ;;
    all)
        validate_shell
        validate_chezmoi
        validate_paths
        validate_legacy
        validate_policy
        validate_signatures
        ;;
    *)
        printf 'usage: %s [shell|chezmoi|paths|legacy|policy|signatures|all]\n' "$0" >&2
        exit 2
        ;;
esac
