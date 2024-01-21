# Append adb to PATH from Android Studio
# [ -d "$HOME/Android/Sdk/platform-tools" ] PATH="$HOME/Android/Sdk/platform-tools:$PATH"

# Append flutter sdk to PATH
[ -d "$HOME/flutter-sdk/bin" ] && export PATH="$HOME/flutter-sdk/bin:$PATH"

# Append composer vendor to PATH
[ -d "$HOME/.config/composer/vendor/bin" ] && export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# Append dagger to PATH
[ -d "$HOME/dagger/bin" ] && export PATH="$HOME/dagger/bin:$PATH"