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

# local bin
typeset -U path PATH
path+=("$HOME/.local/bin")

# Define Chrome executable
if (( $+commands[google-chrome] )); then
  export CHROME_EXECUTABLE="google-chrome"
elif (( $+commands[google-chrome-stable] )); then
  export CHROME_EXECUTABLE="google-chrome-stable"
fi

if [[ -r /proc/version && "$(< /proc/version)" == *[Mm]icrosoft* ]] || [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/config.toml"
else
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/lean.config.toml"
fi

# Encodings, languges and misc settings
export PYTHONIOENCODING='UTF-8';
