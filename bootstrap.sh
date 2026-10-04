#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/jsilverdev/dotfiles.git}"
export PATH="$HOME/.local/bin:$PATH"
DISTRO=""

remove_legacy_links() {
    local path target
    local paths=(
        "$HOME/.gitconfig"
        "$HOME/.fdignore"
        "$HOME/.npmrc"
        "$HOME/.vimrc"
        "$HOME/.zshenv"
        "$HOME/.wslconfig"
        "$HOME/.ssh/jsilverdev.pub"
        "$HOME/.config/starship/config.toml"
        "$HOME/.config/starship/lean.config.toml"
        "$HOME/.config/sheldon/plugins.toml"
        "$HOME/.config/zsh/.zshrc"
        "$HOME/.codex/AGENTS.md"
        "$HOME/.codex/skills/mule-munit/SKILL.md"
        "$HOME/.codex/skills/mule-munit/agents/openai.yaml"
    )

    for path in "${paths[@]}"; do
        if [[ -L "$path" ]]; then
            target="$(readlink -f -- "$path" 2>/dev/null || true)"
            if [[ "$target" == "$HOME/.dotfiles/"* ]]; then
                rm -f -- "$path"
            fi
        fi
    done
}

remove_legacy_links

configure_local_chezmoi_source() {
    local config_dir config_path
    config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
    config_path="$config_dir/chezmoi.toml"

    if [[ ! -e "$config_path" ]]; then
        mkdir -p "$config_dir"
        printf 'sourceDir = "%s"\n' "$PWD" > "$config_path"
    fi
}

if [[ -f /etc/debian_version ]] && command -v apt-get >/dev/null 2>&1; then
    DISTRO="debian"
    sudo apt-get update
    sudo apt-get install --yes git curl zsh
elif [[ -f /etc/arch-release ]] && command -v pacman >/dev/null 2>&1; then
    DISTRO="arch"
    sudo pacman -Syu --noconfirm --needed git curl zsh chezmoi
else
    printf 'Unsupported Linux distribution. Debian and Arch Linux are supported.\n' >&2
    exit 1
fi

command -v git >/dev/null 2>&1 || { printf 'Git is required but unavailable.\n' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf 'curl is required but unavailable.\n' >&2; exit 1; }
command -v wget >/dev/null 2>&1 || { printf 'wget is required but unavailable.\n' >&2; exit 1; }
command -v zsh >/dev/null 2>&1 || { printf 'zsh is required but unavailable.\n' >&2; exit 1; }

if [[ "$DISTRO" == "debian" ]] && ! command -v chezmoi >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi
export PATH="$HOME/.local/bin:$PATH"
command -v chezmoi >/dev/null 2>&1 || { printf 'chezmoi installation failed.\n' >&2; exit 1; }

if [[ -f "$PWD/.chezmoiroot" ]]; then
    configure_local_chezmoi_source
    chezmoi --source "$PWD" apply
else
    SOURCE_ROOT="$(chezmoi source-path 2>/dev/null || true)"
    if [[ -f "$SOURCE_ROOT/.chezmoiroot" || -f "$(dirname "$SOURCE_ROOT")/.chezmoiroot" ]]; then
        chezmoi update
    else
        chezmoi init --apply "$REPO_URL"
    fi
fi

resolve_repo_root() {
    local candidate parent
    if [[ -f "$PWD/.chezmoiroot" && -f "$PWD/install.sh" ]]; then
        printf '%s\n' "$PWD"
        return 0
    fi
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
exec "$REPO_ROOT/install.sh"
