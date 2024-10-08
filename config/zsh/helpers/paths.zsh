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