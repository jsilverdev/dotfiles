#!/usr/bin/env bash

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

function configure_ssh_key() {
    key_path="$HOME/.ssh/jsilverdev_key"

    if [ ! -f "$key_path" ]; then
        echo -e "${YELLOW}SSH key not found at '$key_path'. Generate..${RESET}"
        ssh-keygen -t ed25519 -C "jsilverdev" -f "$key_path" -N ""
    fi
    eval "$(ssh-agent -s)"
    ssh-add $key_path
}

function install_debian_packages () {

    debian_apps=(
        "zsh"
        "micro"
        "jq"
        "tree"
    )

    for app in ${debian_apps[@]}; do
        if hash "${app}" 2> /dev/null; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed${RESET}"
        elif hash flatpak 2> /dev/null && [[ ! -z $(echo $(flatpak list --columns=ref | grep $app)) ]]; then
            echo -e "${YELLOW}[Skipping]${LIGHT} ${app} is already installed via Flatpak${RESET}"
        else
            echo -e "${CYAN}[Installing]${LIGHT} Downloading ${app}...${RESET}"
            sudo apt install ${app} --assume-yes
        fi
    done
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
        lsd_version=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest | grep -Po '"tag_name": "v\K[0-9.]+')
        wget "https://github.com/lsd-rs/lsd/releases/download/v${lsd_version}/lsd_${lsd_version}_${lsd_arch}.deb"
        sudo dpkg -i lsd_${lsd_version}_${lsd_arch}.deb
        rm lsd_${lsd_version}_${lsd_arch}.deb
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

function install_custom_debian_packages () {
    check_package_or_run "fastfetch" "install_fastfetch"
    check_package_or_run "lsd" "install_lsd"
    check_package_or_run "batcat" "sudo apt install bat --assume-yes"
    check_package_or_run "fdfind" "sudo apt install fd-find --assume-yes" # fd
    check_package_or_run "fzf" "install_fzf"
    check_package_or_run "vivid" "install_vivid"
    check_package_or_run "delta" "install_delta"
    check_package_or_run "starship" "install_starship"
}

function install_arch_packages () {
    pacman_apps=(
        "zsh"
        "micro"
        "fastfetch"
        "tree"
        "jq"
        "lsd"
        "fd"
        "fzf"
        "unzip"
        "vivid"
        "git-delta"
        "starship"
    )

    for app in ${pacman_apps[@]}; do
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
    done
}

function install_aur_packages () {
    # Install yay first
    sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

    # Packages:
    # visual-studio-code-bin

}

function install_must_have_packages() {
    echo -e "${CYAN}Installing must have packages...${RESET}"

    if [ -f "/etc/debian_version" ]; then
        sudo apt update && \
        install_debian_packages && \
        install_custom_debian_packages
    elif [ -f "/etc/arch-release" ]; then
        sudo pacman -Syy --noconfirm && \
        sudo pacman -Syu --noconfirm && \
        install_arch_packages && \
        install_aur_packages
    fi

}

function setup_dot_files () {

    DOTBOT_DIR="lib/dotbot"
    DOTBOT_CONF_FILE="install.conf.yaml"
    DOTBOT_CROSSPLATFORM="lib/dotbot-plugins/dotbot-crossplatform/crossplatform.py"

    cd "$DOTFILES_DIR" && \
        git submodule sync --quiet --recursive && \
        git submodule update --init --recursive && \
        "${DOTFILES_DIR}/${DOTBOT_DIR}/bin/dotbot" -d "$DOTFILES_DIR" -c "$DOTBOT_CONF_FILE" -p $DOTBOT_CROSSPLATFORM "${@}"
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

function configure_git_local () {
    [ ! -e ~/.gitconfig.local ] && touch ~/.gitconfig.local
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
setup_dot_files
configure_ssh_key
configure_git_local
setup_default_shell
install_must_have_packages
# install_optional_packages