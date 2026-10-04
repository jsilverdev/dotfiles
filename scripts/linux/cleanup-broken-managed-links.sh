#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repository root is required}"
home_root="${HOME%/}"

cleanup_managed_target() {
    local managed_path=$1 relative current component

    case "$managed_path" in
        "$home_root") return 0 ;;
        "$home_root"/*) relative=${managed_path#"$home_root"/} ;;
        *) return 0 ;;
    esac

    current="$home_root"
    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != "." ]] || continue
        [[ "$component" != ".." ]] || return 0

        current="$current/$component"

        if [[ -L "$current" ]]; then
            if [[ ! -e "$current" ]]; then
                printf 'Removing broken managed symlink: %s\n' "$current"
                rm -- "$current"
            fi

            # Never traverse through a symlink, whether valid or broken.
            return 0
        fi

        [[ -e "$current" ]] || return 0
    done
}

while IFS= read -r -d '' managed_path; do
    cleanup_managed_target "$managed_path"
done < <(
    chezmoi --source "$repo_root" managed         --path-style absolute         --nul-path-separator
)
