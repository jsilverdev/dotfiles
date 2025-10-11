#  ~/.zshenv
# Core envionmental variables
# Locations configured here are requred for all other files to be correctly imported

# Set XDG directories
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"

# Set default applications
export EDITOR="vim"
export PAGER="less"

## Respect XDG directories
export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"

# export GIT_CONFIG="${XDG_CONFIG_HOME}/git/.gitconfig"

export LESSHISTFILE="-" # Disable less history.

export PIP_CONFIG_FILE="${XDG_CONFIG_HOME}/pip/pip.conf"
export PIP_LOG_FILE="${XDG_DATA_HOME}/pip/log"
export PYENV_ROOT="$HOME/.pyenv"

export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"

export FNM_DIR="${XDG_DATA_HOME}/fnm"

# local bin
export PATH="$PATH:$HOME/.local/bin"
if [ -f "/etc/debian_version" ]; then
    # cargo bin
    export PATH="$PATH:$CARGO_HOME/bin"
    # fnm bin
    export PATH="$PATH:$FNM_DIR"
    # biome bin
    export PATH="$PATH:$HOME/.biome/bin"
    # mvn
    export PATH="$PATH:$HOME/.apache-maven/bin"
fi
# Encodings, languges and misc settings
export PYTHONIOENCODING='UTF-8';

export PATH="$PATH:$HOME/.puro/bin" # Added by Puro
export PATH="$PATH:$HOME/.puro/shared/pub_cache/bin" # Added by Puro
export PATH="$PATH:$HOME/.puro/envs/default/flutter/bin" # Added by Puro
export PURO_ROOT="$HOME/.puro" # Added by Puro
export PUB_CACHE="$HOME/.puro/shared/pub_cache" # Added by Puro