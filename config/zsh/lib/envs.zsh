# Append adb to PATH from Android Studio
# [ -d "$HOME/Android/Sdk/platform-tools" ] PATH="$HOME/Android/Sdk/platform-tools:$PATH"

if [ -d "$HOME/.puro" ]; then
    export PATH="$PATH:$HOME/.puro/bin" # Added by Puro
    export PATH="$PATH:$HOME/.puro/shared/pub_cache/bin" # Added by Puro
    export PATH="$PATH:$HOME/.puro/envs/default/flutter/bin" # Added by Puro
    export PURO_ROOT="$HOME/.puro" # Added by Puro
    export PUB_CACHE="$HOME/.puro/shared/pub_cache" # Added by Puro
fi

# Append composer vendor to PATH
[ -d "$HOME/.config/composer/vendor/bin" ] && export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# Append dagger to PATH
[ -d "$HOME/dagger/bin" ] && export PATH="$HOME/dagger/bin:$PATH"

# Define Chrome executable
if [ -x "$(command -v google-chrome)" ]; then
  export CHROME_EXECUTABLE="google-chrome"
elif [ -x "$(command -v google-chrome-stable)" ]; then
  export CHROME_EXECUTABLE="google-chrome-stable"
fi

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/lean.config.toml"
else
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/config.toml"
fi

if hash "fnm" 2> /dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi