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
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$PATH:$HOME/.local/bin" ;;
esac

# Define Chrome executable
if command -v "google-chrome" > /dev/null 2>&1; then
  export CHROME_EXECUTABLE="google-chrome"
elif command -v "google-chrome-stable" > /dev/null 2>&1; then
  export CHROME_EXECUTABLE="google-chrome-stable"
fi

if { [ -r /proc/version ] && grep -qi microsoft /proc/version; } || [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/config.toml"
else
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/lean.config.toml"
fi

# Encodings, languges and misc settings
export PYTHONIOENCODING='UTF-8';
