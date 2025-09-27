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

function pre_setup_tasks() {
    if [ ! -d "$DOTFILES_DIR" ]; then
        echo -e "${RED}The folder '$DOTFILES_DIR' not exists exiting...";
        exit 1;
    fi

    source "${DOTFILES_DIR}/config/zsh/.zshenv"

    detect_arch
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

    if hash "${app}" 2> /dev/null; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed${RESET}"
    elif hash flatpak 2> /dev/null && [[ ! -z $(echo $(flatpak list --columns=ref | grep $app)) ]]; then
        echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via Flatpak${RESET}"
    else
        echo -e "${CYAN}[Installing]${LIGHT} Downloading ${app}...${RESET}"
        sudo apt install ${app} --assume-yes
    fi
}

function check_package_or_run () {
    if hash "$1" 2> /dev/null; then
        echo -e "${YELLOW}[Skipping]${LIGHT} $1 is already installed${RESET}"
    else
        echo -e "${CYAN}[Installing]${LIGHT} Downloading $1...${RESET}"
        $2
    fi
}

function install_fastfetch () {
    if apt-cache show fastfetch &>/dev/null; then
        sudo apt install -y fastfetch
    else
        fastfetch_version=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep -Po '"tag_name": "\K[0-9.]+')
        wget "https://github.com/fastfetch-cli/fastfetch/releases/download/${fastfetch_version}/fastfetch-linux-${arch}.deb"
        sudo dpkg -i fastfetch-linux-${arch}.deb
        rm fastfetch-linux-${arch}.deb
    fi
}

function install_lsd () {
    if apt-cache show lsd &>/dev/null; then
        sudo apt install -y lsd
    else
        local lsd_arch=$arch
        case "${lsd_arch}" in
            aarch64) lsd_arch="arm64" ;;
        esac
        lsd_extra="_xz"
        lsd_version=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest | grep -Po '"tag_name": "v\K[0-9.]+')
        wget "https://github.com/lsd-rs/lsd/releases/download/v${lsd_version}/lsd_${lsd_version}_${lsd_arch}${lsd_extra}.deb"
        sudo dpkg -i lsd_${lsd_version}_${lsd_arch}${lsd_extra}.deb
        rm lsd_${lsd_version}_${lsd_arch}${lsd_extra}.deb
    fi
}

function install_fzf () {
    git clone https://github.com/junegunn/fzf.git ~/.config/fzf && ~/.config/fzf/install --bin
}

function install_vivid () {
    local vivid_arch=$arch
    case "${vivid_arch}" in
        aarch64) vivid_arch="arm64" ;;
    esac
    vivid_version=$(curl -s https://api.github.com/repos/sharkdp/vivid/releases/latest | grep -Po '"tag_name": "v\K[0-9.]+')
    wget "https://github.com/sharkdp/vivid/releases/download/v${vivid_version}/vivid_${vivid_version}_${vivid_arch}.deb"
    sudo dpkg -i vivid_${vivid_version}_${vivid_arch}.deb
    rm vivid_${vivid_version}_${vivid_arch}.deb
}

function install_delta () {
    local delta_arch=$arch
    case "${delta_arch}" in
        aarch64) delta_arch="arm64" ;;
    esac
    delta_version=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | grep -Po '"tag_name": "\K[0-9.]+')
    wget "https://github.com/dandavison/delta/releases/download/${delta_version}/git-delta_${delta_version}_${delta_arch}.deb"
    sudo dpkg -i git-delta_${delta_version}_${delta_arch}.deb
    rm git-delta_${delta_version}_${delta_arch}.deb
}

function install_starship () {
    curl -sS https://starship.rs/install.sh | sh
}

function install_biome () {
    local biome_arch=$arch
    case "${biome_arch}" in
        aarch64) biome_arch="arm64" ;;
        amd64) biome_arch="x64" ;;
    esac

    download_url=$(
        curl -s https://api.github.com/repos/biomejs/biome/releases/latest | \
        sed -n 's/.*"browser_download_url": "\([^"]*linux-'${biome_arch}'[^"]*\)".*/\1/p' | \
        head -n1
    )
    [ -z "$download_url" ] && {
        echo -e "${RED}Failed to get download URL for biome${RESET}" && return 1;
    }
    (mkdir -p "$HOME/.biome/bin" && wget -q "${download_url}" -O "$HOME/.biome/bin/biome" && chmod +x "$HOME/.biome/bin/biome") || {
        echo -e "${RED}Failed to download biome from ${download_url}${RESET}" && \
        rm -rf "$HOME/.biome/bin" && \
        return 1;
    }
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
    )

    for app in ${debian_apps[@]}; do
        install_with_apt $app
    done

    check_package_or_run "fastfetch" "install_fastfetch"
    check_package_or_run "lsd" "install_lsd"
    check_package_or_run "batcat" "sudo apt install bat --assume-yes"
    check_package_or_run "fdfind" "sudo apt install fd-find --assume-yes" # fd
    check_package_or_run "strings" "sudo apt install binutils --assume-yes" # strings
    check_package_or_run "fzf" "install_fzf"
    check_package_or_run "vivid" "install_vivid"
    check_package_or_run "delta" "install_delta"
    check_package_or_run "starship" "install_starship"
    check_package_or_run "biome" "install_biome"
}

function install_with_pacman () {
    local app=$1

    if hash "${app}" 2> /dev/null; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed${RESET}"
        elif [[ $(echo $(pacman -Qk $(echo $app | tr 'A-Z' 'a-z') 2> /dev/null )) == *"total files"* ]]; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via Pacman${RESET}"
        elif hash flatpak 2> /dev/null && [[ ! -z $(echo $(flatpak list --columns=ref | grep $app)) ]]; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via Flatpak${RESET}"
        else
            echo -e "${CYAN}[Installing]${LIGHT} Downloading ${app}...${RESET}"
            sudo pacman -S ${app} --needed --noconfirm
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
        "bat"
        "python"
        "ufw"
        "rsync"
        "zip"
        "unzip"
        "less"
        "socat"
        "binutils"
        "biome"
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

function install_optional_packages () {
    local packages=(
        "fnm"
        "puro"
        "composer"
        "DBeaver"
        "Postman"
        "Bruno"
        "kubectl"
        "dagger"
        "docker"
    )
}


pre_setup_tasks
configure_git
configure_wsl
install_must_have_packages
setup_dot_files
setup_default_shell
# install_optional_packages