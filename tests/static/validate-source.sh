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
        scripts/linux/cleanup-broken-managed-links.sh
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

case "${1:-all}" in
    shell) validate_shell ;;
    chezmoi) validate_chezmoi ;;
    all)
        validate_shell
        validate_chezmoi
        ;;
    *)
        printf 'usage: %s [shell|chezmoi|all]\n' "$0" >&2
        exit 2
        ;;
esac
