#!/usr/bin/bash

RED='\033[0;31m'          # Red
GREEN='\033[0;32m'        # Green
YELLOW='\033[0;33m'       # Yellow
BLUE='\033[0;34m'         # Blue
CYAN='\033[0;36m'         # Cyan
LIGHT='\x1b[2m'
RESET='\033[0m'


SRC_DIR=$(dirname "${0}")
DOTFILES_DIR="${DOTFILES_DIR:-${SRC_DIR:-$HOME/.dotfiles}}"
UPDATE_PACKAGES="${UPDATE_PACKAGES:-false}"

function usage () {
    echo "Usage: $0 [--update|-u]"
    echo
    echo "Options:"
    echo "  -u, --update    Re-run package installers even when commands already exist"
    echo "  -h, --help      Show this help message"
}

function parse_args () {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -u|--update)
                UPDATE_PACKAGES=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${RESET}"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

function updates_enabled () {
    case "${UPDATE_PACKAGES}" in
        1|true|TRUE|yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

function pre_setup_tasks() {
    if [ ! -d "$DOTFILES_DIR" ]; then
        echo -e "${RED}The folder '$DOTFILES_DIR' not exists exiting...";
        exit 1;
    fi

    source "${DOTFILES_DIR}/config/zsh/.zshenv"

    detect_arch

    if updates_enabled; then
        echo -e "${CYAN}Update mode enabled. Existing packages will be refreshed when possible.${RESET}"
    fi
}

detect_arch() {

  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"

  case "${arch}" in
    x86_64) arch="amd64" ;;
    arm64) arch="aarch64" ;;
  esac

  # `uname -m` in some cases mis-reports 32-bit OS as 64-bit, so double check
  if [ "${arch}" = "amd64" ] && [ "$(getconf LONG_BIT)" -eq 32 ]; then
    arch=i686
  elif [ "${arch}" = "aarch64" ] && [ "$(getconf LONG_BIT)" -eq 32 ]; then
    arch=arm
  fi

  if [ "${arch}" != "amd64" ] && [ "${arch}" != "aarch64" ]; then
    echo -e "${RED}Only amd64 and aarch64 supported";
    exit 1
  fi

  echo -e "${GREEN}Current arch is '${arch}'${RESET}"
}

function install_with_apt () {
    local app=$1

    if hash "${app}" 2> /dev/null && ! updates_enabled; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed${RESET}"
    elif dpkg -s "${app}" &> /dev/null && ! updates_enabled; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via APT${RESET}"
    elif hash flatpak 2> /dev/null && [[ ! -z $(echo $(flatpak list --columns=ref | grep $app)) ]]; then
        echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via Flatpak${RESET}"
    else
        if updates_enabled && { hash "${app}" 2> /dev/null || dpkg -s "${app}" &> /dev/null; }; then
            echo -e "${CYAN}[Updating]${LIGHT} ${app}...${RESET}"
        else
            echo -e "${CYAN}[Installing]${LIGHT} Downloading ${app}...${RESET}"
        fi
        sudo apt install "${app}" --assume-yes
    fi
}

function check_package_or_run () {
    local app=$1
    local installer=$2

    if hash "$app" 2> /dev/null && ! updates_enabled; then
        echo -e "${YELLOW}[Skipping]${LIGHT} $app is already installed${RESET}"
    else
        if hash "$app" 2> /dev/null; then
            echo -e "${CYAN}[Updating]${LIGHT} $app...${RESET}"
        else
            echo -e "${CYAN}[Installing]${LIGHT} Downloading $app...${RESET}"
        fi
        "$installer"
    fi
}

function github_release_json () {
    local repo=$1
    local release
    local releases

    if release=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null); then
        printf '%s\n' "$release"
        return 0
    fi

    releases=$(curl -fsSL "https://api.github.com/repos/${repo}/releases?per_page=10" 2>/dev/null) || return 1
    jq -e 'map(select((.draft | not) and (.prerelease | not))) | .[0]' <<< "$releases"
}

function github_release_asset_url () {
    local repo=$1
    local asset_regex=$2
    local release

    release=$(github_release_json "$repo") || return 1

    jq -er --arg asset_regex "$asset_regex" '
        first(.assets[]?.browser_download_url | select(test($asset_regex)))
    ' <<< "$release"
}

function install_github_deb_asset () {
    local repo=$1
    local asset_regex=$2
    local asset_url
    local deb_file
    local install_status

    asset_url=$(github_release_asset_url "$repo" "$asset_regex") || {
        echo -e "${RED}Could not find a matching release asset for ${repo}.${RESET}"
        return 1
    }

    deb_file="${asset_url##*/}"

    wget -O "$deb_file" "$asset_url" || return 1
    sudo dpkg -i "$deb_file"
    install_status=$?
    rm -f "$deb_file"

    return "$install_status"
}

function debian_release_arch () {
    case "$arch" in
        aarch64) printf 'arm64\n' ;;
        *) printf '%s\n' "$arch" ;;
    esac
}

function install_fastfetch () {
    if apt-cache show fastfetch &>/dev/null; then
        sudo apt install -y fastfetch
    else
        install_github_deb_asset "fastfetch-cli/fastfetch" "fastfetch-linux-${arch}\\.deb$"
    fi
}

function install_lsd () {
    if apt-cache show lsd &>/dev/null; then
        sudo apt install -y lsd
    else
        local lsd_arch
        lsd_arch=$(debian_release_arch)
        install_github_deb_asset "lsd-rs/lsd" "lsd_.*_${lsd_arch}_xz\\.deb$"
    fi
}

function install_fzf () {
    local fzf_dir="$HOME/.config/fzf"

    if [ -d "$fzf_dir/.git" ]; then
        git -C "$fzf_dir" pull --ff-only
    else
        git clone https://github.com/junegunn/fzf.git "$fzf_dir"
    fi

    "$fzf_dir/install" --bin
}

function install_vivid () {
    local vivid_arch
    vivid_arch=$(debian_release_arch)
    install_github_deb_asset "sharkdp/vivid" "vivid_.*_${vivid_arch}\\.deb$"
}

function install_delta () {
    local delta_arch
    delta_arch=$(debian_release_arch)
    install_github_deb_asset "dandavison/delta" "git-delta_.*_${delta_arch}\\.deb$"
}

function install_starship () {
    curl -sS https://starship.rs/install.sh | sh
}

function install_sheldon () {
    local install_args=(
        --repo rossmacarthur/sheldon
        --to "$HOME/.local/bin"
    )

    if updates_enabled; then
        install_args+=(--force)
    fi

    curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
        | bash -s -- "${install_args[@]}"
}

function install_debian_packages () {

    debian_apps=(
        "git"
        "curl"
        "wget"
        "zsh"
        "micro"
        "jq"
        "tree"
        "python3"
        "ufw"
        "rsync"
        "zip"
        "unzip"
        "less"
        "socat"
        "bat"
        "fd-find" # fd
        "binutils" # strings
        "ripgrep"
    )

    for app in ${debian_apps[@]}; do
        install_with_apt $app
    done

    check_package_or_run "fastfetch" "install_fastfetch"
    check_package_or_run "lsd" "install_lsd"
    check_package_or_run "fzf" "install_fzf"
    check_package_or_run "vivid" "install_vivid"
    check_package_or_run "delta" "install_delta"
    check_package_or_run "starship" "install_starship"
    check_package_or_run "sheldon" "install_sheldon"
}

function install_with_pacman () {
    local app=$1
    local pacman_app
    local pacman_status

    pacman_app=$(printf '%s' "$app" | tr 'A-Z' 'a-z')
    pacman_status=$(pacman -Qk "$pacman_app" 2> /dev/null)

    if hash "${app}" 2> /dev/null && ! updates_enabled; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed${RESET}"
        elif [[ "$pacman_status" == *"total files"* ]] && ! updates_enabled; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via Pacman${RESET}"
        elif hash flatpak 2> /dev/null && [[ ! -z $(echo $(flatpak list --columns=ref | grep $app)) ]]; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via Flatpak${RESET}"
        else
            if updates_enabled && { hash "${app}" 2> /dev/null || [[ "$pacman_status" == *"total files"* ]]; }; then
                echo -e "${CYAN}[Updating]${LIGHT} ${app}...${RESET}"
            else
                echo -e "${CYAN}[Installing]${LIGHT} Downloading ${app}...${RESET}"
            fi
            sudo pacman -S "${app}" --needed --noconfirm
    fi
}

function install_arch_packages () {
    pacman_apps=(
        "git"
        "curl"
        "wget"
        "zsh"
        "micro"
        "fastfetch"
        "tree"
        "jq"
        "lsd"
        "fd"
        "fzf"
        "vivid"
        "git-delta"
        "starship"
        "sheldon"
        "bat"
        "python"
        "ufw"
        "rsync"
        "zip"
        "unzip"
        "less"
        "socat"
        "binutils"
        "ripgrep"
    )

    for app in ${pacman_apps[@]}; do
        install_with_pacman $app
    done

    # Install yay
    if hash "yay" 2> /dev/null; then
        echo -e "${YELLOW}[Skipping]${LIGHT} yay is already installed${RESET}"
    else
        sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git ~/.yay && (cd ~/.yay && makepkg -si) && rm -rf ~/.yay
    fi
}

function install_must_have_packages() {
    echo -e "${CYAN}Installing must have packages...${RESET}"

    if [ -f "/etc/debian_version" ]; then
        sudo apt update && \
        install_debian_packages
    elif [ -f "/etc/arch-release" ]; then
        sudo pacman -Syy --noconfirm && \
        install_arch_packages
    fi

}

function setup_dot_files () {

    DOTBOT_BIN="bin/dotbot"
    DOTBOT_DIR="lib/dotbot"
    DOTBOT_CONF_FILE="install.conf.yaml"
    DOTBOT_FULL_PATH_BIN="${DOTFILES_DIR}/${DOTBOT_DIR}/bin/dotbot"

    BASE_CONFIG="base"
    CONFIG_SUFFIX=".yaml"
    META_DIR="meta"
    CONFIG_DIR="configs"

    $DOTBOT_FULL_PATH_BIN -d "$DOTFILES_DIR" -c "${META_DIR}/${BASE_CONFIG}${CONFIG_SUFFIX}"

    CONFIGS="zsh"

    for config in $CONFIGS; do
        $DOTBOT_FULL_PATH_BIN -d "$DOTFILES_DIR" -c "${META_DIR}/${CONFIG_DIR}/${config}${CONFIG_SUFFIX}"
    done
}

function setup_sheldon_plugins () {
    if hash "sheldon" 2> /dev/null; then
        sheldon lock
    fi
}

function setup_default_shell() {

    current_shell=$(getent passwd "$USER" | cut -d: -f7)

    if [ "$current_shell" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)"
        echo -e "${GREEN}Default shell changed to zsh.${RESET}"
    else
        echo -e "${YELLOW}zsh is already the default shell for $USER. No changes made.${RESET}"
    fi
}

function configure_git () {
    [ ! -e ~/.gitconfig.local ] && touch ~/.gitconfig.local
    git submodule sync --quiet --recursive
    git submodule update --init --recursive
    echo -e "${GREEN}Git successfully configured!${RESET}"
}

function configure_wsl() {
    if grep -qi microsoft /proc/version && [[ ! -e /etc/wsl.conf ]]; then
        sudo cp "${DOTFILES_DIR}/config/wsl/wsl.conf" /etc/wsl.conf
        echo -e "${GREEN}wsl.conf configured successfully!${RESET}"
    fi
}

function install_mise_en_place () {
    local mise_arch=$arch
    case "${mise_arch}" in
        aarch64) mise_arch="arm64" ;;
    esac

    if apt-cache show mise &>/dev/null; then
        sudo apt install -y mise
    else
        sudo apt install -y curl
        sudo install -dm 755 /etc/apt/keyrings
        curl -fSs https://mise.jdx.dev/gpg-key.pub | sudo tee /etc/apt/keyrings/mise-archive-keyring.pub 1> /dev/null
        echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.pub arch=$mise_arch] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
        sudo apt update -y
        sudo apt install -y mise
    fi
}

function install_docker () {
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh ./get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
}

function install_dagger () {
    curl -fsSL https://dl.dagger.io/dagger/install.sh | BIN_DIR=$HOME/.local/bin sh
}

function install_optional_packages () {
    local packages=(
        "mise-en-place|deb:check_package_or_run mise install_mise_en_place|arch:install_with_pacman mise"
        "docker|deb:check_package_or_run docker install_docker|arch:install_with_pacman docker"
        "dagger|deb:check_package_or_run dagger install_dagger|arch:install_with_pacman dagger"
    )

    echo -e "\n${CYAN}Choose optional packages to install:${RESET}"
    for i in "${!packages[@]}"; do
        IFS='|' read -ra pkg_info <<< "${packages[i]}"
        pkg_name="${pkg_info[0]}"
        echo -e "${CYAN}$((i+1)). ${pkg_name}${RESET}"
    done
    echo -e "${CYAN}You can use ranges like 1-4 or individual numbers separated by commas:${RESET}"
    read -p "Enter your choices (or press Enter to skip): " user_input
    if [ -z "$user_input" ]; then
        echo -e "${YELLOW}No optional packages selected for installation.${RESET}"
        return
    fi
    # Parse user input to get selected indices and trim spaces
    IFS=',' read -ra selections <<< "$(echo $user_input | tr -d ' ')"
    selected_indices=()
    for sel in "${selections[@]}"; do
        if [[ $sel =~ ^[0-9]+-[0-9]+$ ]]; then
            IFS='-' read -ra range <<< "$sel"
            start=${range[0]}
            end=${range[1]}
            for ((i=start; i<=end; i++)); do
                if (( i >= 1 && i <= ${#packages[@]} )); then
                    selected_indices+=("$i")
                fi
            done

        elif [[ $sel =~ ^[0-9]+$ ]]; then
            if (( sel >= 1 && sel <= ${#packages[@]} )); then
                selected_indices+=("$sel")
            fi
        fi
    done
    # Remove duplicates
    IFS=$'\n' selected_indices=($(sort -u <<<"${selected_indices[*]}"))
    unset IFS
    # If no valid selections, exit
    if [ ${#selected_indices[@]} -eq 0 ]; then
        echo -e "${YELLOW}No valid optional packages selected for installation.${RESET}"
        return
    fi
    # Install selected packages
    for index in "${selected_indices[@]}"; do
        idx=$((index-1))
        IFS='|' read -ra pkg_info <<< "${packages[idx]}"
        pkg_name="${pkg_info[0]}"
        deb_func="${pkg_info[1]#deb:}"
        arch_func="${pkg_info[2]#arch:}"
        echo -e "${CYAN}[Installing]${LIGHT} ${pkg_name}...${RESET}"
        if [ -f "/etc/debian_version" ]; then
            $deb_func
        elif [ -f "/etc/arch-release" ]; then
            $arch_func
        fi
    done
}


parse_args "$@"
pre_setup_tasks
configure_git
configure_wsl
install_must_have_packages
setup_dot_files
setup_sheldon_plugins
setup_default_shell
install_optional_packages
