#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/jsilverdev/dotfiles.git}"
export PATH="$HOME/.local/bin:$PATH"
DISTRO=""

configure_local_chezmoi_source() {
    local config_dir config_path
    config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
    config_path="$config_dir/chezmoi.toml"
    if [[ ! -e "$config_path" ]]; then
        mkdir -p "$config_dir"
        printf 'sourceDir = "%s"\n' "$PWD" > "$config_path"
    fi
}

resolve_repo_root() {
    local candidate parent
    if [[ -f "$PWD/.chezmoiroot" && -f "$PWD/install.sh" ]]; then
        printf '%s\n' "$PWD"
        return 0
    fi

    for candidate in "$(chezmoi execute-template '{{ .chezmoi.workingTree }}' 2>/dev/null || true)" "$(chezmoi source-path 2>/dev/null || true)"; do
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

if [[ -f /etc/debian_version ]] && command -v apt-get >/dev/null 2>&1; then
    DISTRO="debian"
    missing=()
    command -v git >/dev/null 2>&1 || missing+=(git)
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    if (( ${#missing[@]} > 0 )); then
        sudo apt-get update
        sudo apt-get install --yes "${missing[@]}"
        export DOTFILES_PACKAGE_INDEX_READY=1
    fi
elif [[ -f /etc/arch-release ]] && command -v pacman >/dev/null 2>&1; then
    DISTRO="arch"
    missing=()
    command -v git >/dev/null 2>&1 || missing+=(git)
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    command -v chezmoi >/dev/null 2>&1 || missing+=(chezmoi)
    if (( ${#missing[@]} > 0 )); then
        sudo pacman -Syu --noconfirm --needed "${missing[@]}"
        export DOTFILES_PACKAGE_INDEX_READY=1
    fi
else
    printf 'Unsupported Linux distribution. Debian and Arch Linux are supported.\n' >&2
    exit 1
fi

command -v git >/dev/null 2>&1 || { printf 'Git is required but unavailable.\n' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf 'curl is required but unavailable.\n' >&2; exit 1; }

if [[ "$DISTRO" == "debian" ]] && ! command -v chezmoi >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi

export PATH="$HOME/.local/bin:$PATH"
command -v chezmoi >/dev/null 2>&1 || { printf 'chezmoi installation failed.\n' >&2; exit 1; }

existing_source=false
if [[ -f "$PWD/.chezmoiroot" ]]; then
    configure_local_chezmoi_source
else
    SOURCE_ROOT="$(chezmoi source-path 2>/dev/null || true)"
    if [[ -f "$SOURCE_ROOT/.chezmoiroot" || -f "$(dirname "$SOURCE_ROOT")/.chezmoiroot" ]]; then
        existing_source=true
    else
        chezmoi --source "$HOME/.dotfiles" init "$REPO_URL"
    fi
fi

REPO_ROOT="$(resolve_repo_root)" || { printf 'Unable to resolve the chezmoi working tree.\n' >&2; exit 1; }

if [[ "$existing_source" == true ]]; then
    git -C "$REPO_ROOT" pull --autostash --rebase
fi

"$REPO_ROOT/scripts/linux/cleanup-broken-managed-links.sh" "$REPO_ROOT"
chezmoi --source "$REPO_ROOT" apply

exec "$REPO_ROOT/install.sh"
