#!/usr/bin/env bash

core_packages=(
  'git'
  'zsh'
  'wget'
)

function install_debian () {
  echo -e "${PURPLE}Installing ${1} via apt-get${RESET}"
  sudo apt install $1
}
function install_arch () {
  echo -e "${PURPLE}Installing ${1} via Pacman${RESET}"
  sudo pacman -S $1
}

function multi_system_install () {
  app=$1
  if [ -f "/etc/arch-release" ] && hash pacman 2> /dev/null; then
    install_arch $app # Arch Linux via Pacman
  elif [ -f "/etc/debian_version" ] && hash apt 2> /dev/null; then
    install_debian $app # Debian via apt-get
  else
    echo -e "${YELLOW}Skipping ${app}, as couldn't detect system type ${RESET}"
  fi
}

# If not already set, specify dotfiles destination directory and source repo
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/jsilverdev/dotfiles.git}"

# For each app, check if not present and install
for app in ${core_packages[@]}; do
  if ! hash "${app}" 2> /dev/null; then
    multi_system_install $app
  else
    echo -e "${YELLOW}${app} is already installed, skipping${RESET}"
  fi
done

# If dotfiles not yet present then clone
if [[ ! -d "$DOTFILES_DIR" ]]; then
  mkdir -p "${DOTFILES_DIR}" && \
  git clone --recursive ${DOTFILES_REPO} ${DOTFILES_DIR}
fi

# Execute setup or update script
cd "${DOTFILES_DIR}" && \
chmod +x ./install.sh && \
./install.sh
