#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
LIGHT='\x1b[2m'
RESET='\033[0m'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPDATE=false
NON_INTERACTIVE=false
DISTRO=""
arch=""

usage() {
    cat <<'EOF'
Usage: install.sh [--update|-u] [--non-interactive]

Options:
  -u, --update             Refresh packages and tools managed by this installer
      --non-interactive    Install the baseline without prompts or workstation customization
  -h, --help               Show this help message
EOF
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -u|--update) UPDATE=true ;;
            --non-interactive) NON_INTERACTIVE=true ;;
            -h|--help) usage; exit 0 ;;
            *) printf '%bUnknown option: %s%b\n' "$RED" "$1" "$RESET" >&2; usage >&2; exit 1 ;;
        esac
        shift
    done
    if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
        NON_INTERACTIVE=true
    fi
}

updates_enabled() { [[ "$UPDATE" == true ]]; }
noninteractive_enabled() { [[ "$NON_INTERACTIVE" == true ]]; }

read_manifest() {
    local path=$1
    [[ -f "$path" ]] || { printf 'Manifest not found: %s\n' "$path" >&2; return 1; }
    grep -Ev '^[[:space:]]*(#|$)' "$path"
}

detect_distro() {
    if [[ -f /etc/debian_version ]] && command -v apt-get >/dev/null 2>&1; then
        DISTRO="debian"
    elif [[ -f /etc/arch-release ]] && command -v pacman >/dev/null 2>&1; then
        DISTRO="arch"
    else
        printf '%bUnsupported Linux distribution. Debian and Arch Linux are supported.%b\n' "$RED" "$RESET" >&2
        exit 1
    fi
}

detect_arch() {
    arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
    case "$arch" in x86_64) arch="amd64" ;; arm64) arch="aarch64" ;; esac
    if [[ "$arch" == "amd64" && "$(getconf LONG_BIT)" -eq 32 ]]; then
        arch="i686"
    elif [[ "$arch" == "aarch64" && "$(getconf LONG_BIT)" -eq 32 ]]; then
        arch="arm"
    fi
    if [[ "$arch" != "amd64" && "$arch" != "aarch64" ]]; then
        printf '%bOnly amd64 and aarch64 are supported.%b\n' "$RED" "$RESET" >&2
        exit 1
    fi
    printf '%bCurrent arch is %s%b\n' "$GREEN" "$arch" "$RESET"
}

pre_setup_tasks() {
    [[ -d "$REPO_ROOT" ]] || { printf '%bRepository folder not found: %s%b\n' "$RED" "$REPO_ROOT" "$RESET" >&2; exit 1; }
    mkdir -p "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    detect_distro
    detect_arch
    updates_enabled && printf '%bUpdate mode enabled.%b\n' "$CYAN" "$RESET"
}

refresh_package_index() {
    [[ "${DOTFILES_PACKAGE_INDEX_READY:-0}" == "1" ]] && return
    case "$DISTRO" in
        debian) sudo apt-get update ;;
        arch) sudo pacman -Syu --noconfirm ;;
    esac
    export DOTFILES_PACKAGE_INDEX_READY=1
}

install_debian_manifest() {
    local manifest="$REPO_ROOT/scripts/linux/packages-debian.txt"
    local -a packages selected=()
    mapfile -t packages < <(read_manifest "$manifest")
    if updates_enabled; then
        selected=("${packages[@]}")
    else
        local package
        for package in "${packages[@]}"; do
            dpkg -s "$package" >/dev/null 2>&1 || selected+=("$package")
        done
    fi
    if (( ${#selected[@]} > 0 )); then
        sudo apt-get install --yes "${selected[@]}"
    else
        printf '%bAPT baseline already installed.%b\n' "$YELLOW" "$RESET"
    fi
}

install_arch_manifest() {
    local manifest="$REPO_ROOT/scripts/linux/packages-arch.txt"
    local -a packages selected=()
    mapfile -t packages < <(read_manifest "$manifest")
    if updates_enabled; then
        selected=("${packages[@]}")
    else
        local package
        for package in "${packages[@]}"; do
            pacman -Q "$package" >/dev/null 2>&1 || selected+=("$package")
        done
    fi
    if (( ${#selected[@]} > 0 )); then
        sudo pacman -S --needed --noconfirm "${selected[@]}"
    else
        printf '%bPacman baseline already installed.%b\n' "$YELLOW" "$RESET"
    fi
}

check_package_or_run() {
    local command_name=$1 installer=$2
    if command -v "$command_name" >/dev/null 2>&1 && ! updates_enabled; then
        printf '%b[Skipping]%b %s is already installed%b\n' "$YELLOW" "$LIGHT" "$command_name" "$RESET"
        return
    fi
    "$installer"
}

github_release_json() {
    local repo=$1 release releases
    if release="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null)"; then
        printf '%s\n' "$release"
        return
    fi
    releases="$(curl -fsSL "https://api.github.com/repos/${repo}/releases?per_page=10")"
    jq -e 'map(select((.draft | not) and (.prerelease | not))) | .[0]' <<< "$releases"
}

github_release_asset_url() {
    local repo=$1 asset_regex=$2 release
    release="$(github_release_json "$repo")"
    jq -er --arg asset_regex "$asset_regex" 'first(.assets[]?.browser_download_url | select(test($asset_regex)))' <<< "$release"
}

install_github_deb_asset() {
    local repo=$1 asset_regex=$2 asset_url tmp_dir deb_file
    asset_url="$(github_release_asset_url "$repo" "$asset_regex")" || {
        printf '%bCould not find a matching release asset for %s.%b\n' "$RED" "$repo" "$RESET" >&2
        return 1
    }
    tmp_dir="$(mktemp -d)"
    deb_file="$tmp_dir/${asset_url##*/}"
    if ! curl -fL "$asset_url" -o "$deb_file"; then rm -rf "$tmp_dir"; return 1; fi
    if ! sudo dpkg -i "$deb_file"; then rm -rf "$tmp_dir"; return 1; fi
    rm -rf "$tmp_dir"
}

debian_release_arch() { [[ "$arch" == "aarch64" ]] && printf 'arm64\n' || printf '%s\n' "$arch"; }

install_fastfetch() {
    if apt-cache show fastfetch >/dev/null 2>&1; then sudo apt-get install --yes fastfetch
    else install_github_deb_asset "fastfetch-cli/fastfetch" "fastfetch-linux-${arch}\\.deb$"; fi
}
install_lsd() {
    if apt-cache show lsd >/dev/null 2>&1; then sudo apt-get install --yes lsd
    else local a; a="$(debian_release_arch)"; install_github_deb_asset "lsd-rs/lsd" "lsd_.*_${a}_xz\\.deb$"; fi
}
install_fzf() {
    local dir="$HOME/.config/fzf"
    if [[ -d "$dir/.git" ]]; then git -c safe.directory="$dir" -C "$dir" pull --ff-only
    else git clone https://github.com/junegunn/fzf.git "$dir"; fi
    "$dir/install" --bin
    ln -sfn "$dir/bin/fzf" "$HOME/.local/bin/fzf"
}
install_vivid() { local a; a="$(debian_release_arch)"; install_github_deb_asset "sharkdp/vivid" "vivid_.*_${a}\\.deb$"; }
install_delta() { local a; a="$(debian_release_arch)"; install_github_deb_asset "dandavison/delta" "git-delta_.*_${a}\\.deb$"; }
install_starship() { curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; }
install_sheldon() {
    local -a args=(--repo rossmacarthur/sheldon --to "$HOME/.local/bin")
    updates_enabled && args+=(--force)
    curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- "${args[@]}"
}

install_debian_packages() {
    install_debian_manifest
    check_package_or_run fastfetch install_fastfetch
    check_package_or_run lsd install_lsd
    check_package_or_run fzf install_fzf
    check_package_or_run vivid install_vivid
    check_package_or_run delta install_delta
    check_package_or_run starship install_starship
    check_package_or_run sheldon install_sheldon
}

install_yay() {
    if command -v yay >/dev/null 2>&1 && ! updates_enabled; then
        printf '%b[Skipping]%b yay is already installed%b\n' "$YELLOW" "$LIGHT" "$RESET"
        return
    fi
    sudo pacman -S --needed --noconfirm git base-devel
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
    (cd "$tmp_dir/yay" && makepkg -si --noconfirm --needed)
    rm -rf "$tmp_dir"
}

install_arch_packages() { install_arch_manifest; install_yay; }

install_must_have_packages() {
    printf '%bInstalling baseline packages...%b\n' "$CYAN" "$RESET"
    refresh_package_index
    case "$DISTRO" in debian) install_debian_packages ;; arch) install_arch_packages ;; esac
}

setup_sheldon_plugins() { command -v sheldon >/dev/null 2>&1 && sheldon lock; }

setup_default_shell() {
    local target_user="${USER:-$(id -un)}" current_shell target_shell
    current_shell="$(getent passwd "$target_user" | cut -d: -f7)"
    target_shell="$(command -v zsh)"
    if [[ "$current_shell" != "$target_shell" ]]; then
        chsh -s "$target_shell" "$target_user"
        printf '%bDefault shell changed to zsh for %s.%b\n' "$GREEN" "$target_user" "$RESET"
    else
        printf '%bzsh is already the default shell for %s.%b\n' "$YELLOW" "$target_user" "$RESET"
    fi
}

configure_git() { [[ -e "$HOME/.gitconfig.local" ]] || touch "$HOME/.gitconfig.local"; }

configure_wsl() {
    if noninteractive_enabled; then
        printf '%bSkipping WSL system configuration in non-interactive mode.%b\n' "$YELLOW" "$RESET"
        return
    fi
    local desired="$REPO_ROOT/assets/wsl/wsl.conf"
    if grep -qi microsoft /proc/version 2>/dev/null && [[ -f "$desired" ]]; then
        if [[ ! -f /etc/wsl.conf ]] || ! cmp -s "$desired" /etc/wsl.conf; then
            sudo install -m 0644 "$desired" /etc/wsl.conf
        fi
    fi
}

install_with_apt() {
    local package=$1
    refresh_package_index
    if dpkg -s "$package" >/dev/null 2>&1 && ! updates_enabled; then
        printf '%b[Skipping]%b %s is already installed%b\n' "$YELLOW" "$LIGHT" "$package" "$RESET"
    else
        sudo apt-get install --yes "$package"
    fi
}

install_with_pacman() {
    local package=$1
    refresh_package_index
    if pacman -Q "$package" >/dev/null 2>&1 && ! updates_enabled; then
        printf '%b[Skipping]%b %s is already installed%b\n' "$YELLOW" "$LIGHT" "$package" "$RESET"
    else
        sudo pacman -S --needed --noconfirm "$package"
    fi
}

install_mise_en_place() {
    local mise_arch="$arch"
    [[ "$mise_arch" == "aarch64" ]] && mise_arch="arm64"
    if apt-cache show mise >/dev/null 2>&1; then
        sudo apt-get install --yes mise
        return
    fi
    sudo install -dm 755 /etc/apt/keyrings
    curl -fSs https://mise.jdx.dev/gpg-key.pub | sudo tee /etc/apt/keyrings/mise-archive-keyring.pub >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.pub arch=$mise_arch] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
    sudo apt-get update
    sudo apt-get install --yes mise
}

install_docker() {
    local script
    script="$(mktemp)"
    curl -fsSL https://get.docker.com -o "$script"
    sudo sh "$script"
    rm -f "$script"
    sudo usermod -aG docker "${USER:-$(id -un)}"
}
install_dagger() { curl -fsSL https://dl.dagger.io/dagger/install.sh | BIN_DIR="$HOME/.local/bin" sh; }

install_optional_packages() {
    if noninteractive_enabled; then
        printf '%bSkipping optional package selection in non-interactive mode.%b\n' "$YELLOW" "$RESET"
        return
    fi
    local packages=(
        "mise-en-place|deb:check_package_or_run mise install_mise_en_place|arch:install_with_pacman mise"
        "docker|deb:check_package_or_run docker install_docker|arch:install_with_pacman docker"
        "dagger|deb:check_package_or_run dagger install_dagger|arch:install_with_pacman dagger"
    )
    printf '\n%bChoose optional packages to install:%b\n' "$CYAN" "$RESET"
    local i
    for i in "${!packages[@]}"; do
        IFS='|' read -r -a pkg_info <<< "${packages[i]}"
        printf '%b%d. %s%b\n' "$CYAN" "$((i + 1))" "${pkg_info[0]}" "$RESET"
    done
    read -r -p "Enter choices (e.g. 1-3,5) or press Enter to skip: " user_input
    [[ -n "$user_input" ]] || return
    local -a selected_indices=()
    local sel start end
    IFS=',' read -r -a selections <<< "${user_input// /}"
    for sel in "${selections[@]}"; do
        if [[ "$sel" =~ ^[0-9]+-[0-9]+$ ]]; then
            IFS='-' read -r start end <<< "$sel"
            for ((i=start; i<=end; i++)); do (( i >= 1 && i <= ${#packages[@]} )) && selected_indices+=("$i"); done
        elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#packages[@]} )); then
            selected_indices+=("$sel")
        fi
    done
    (( ${#selected_indices[@]} > 0 )) || { printf '%bNo valid selection.%b\n' "$YELLOW" "$RESET"; return; }
    mapfile -t selected_indices < <(printf '%s\n' "${selected_indices[@]}" | sort -nu)
    local index idx deb_func arch_func
    for index in "${selected_indices[@]}"; do
        idx=$((index - 1))
        IFS='|' read -r -a pkg_info <<< "${packages[idx]}"
        deb_func="${pkg_info[1]#deb:}"
        arch_func="${pkg_info[2]#arch:}"
        case "$DISTRO" in debian) eval "$deb_func" ;; arch) eval "$arch_func" ;; esac
    done
}

parse_args "$@"
pre_setup_tasks
configure_git
install_must_have_packages
setup_sheldon_plugins

if noninteractive_enabled; then
    printf '%bSkipping shell and WSL customization in non-interactive mode.%b\n' "$YELLOW" "$RESET"
else
    setup_default_shell
    configure_wsl
fi

install_optional_packages
