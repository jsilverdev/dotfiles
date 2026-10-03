#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
command -v chezmoi >/dev/null 2>&1 || { printf 'chezmoi is required; run bootstrap.sh first.\n' >&2; exit 1; }
chezmoi update

resolve_repo_root() {
    local candidate parent
    for candidate in "$(chezmoi execute-template '{{ .chezmoi.workingTree }}' 2>/dev/null || true)" "$(chezmoi source-path)"; do
        [[ -n "$candidate" ]] || continue
        if [[ -f "$candidate/install.sh" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        parent="$(dirname "$candidate")"
        if [[ -f "$parent/install.sh" ]]; then
            printf '%s\n' "$parent"
            return 0
        fi
    done
    return 1
}

REPO_ROOT="$(resolve_repo_root)" || { printf 'Unable to resolve the chezmoi working tree.\n' >&2; exit 1; }
exec "$REPO_ROOT/install.sh" --update
