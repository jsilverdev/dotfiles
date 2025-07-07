# Append adb to PATH from Android Studio
# [ -d "$HOME/Android/Sdk/platform-tools" ] PATH="$HOME/Android/Sdk/platform-tools:$PATH"

# Define Chrome executable
if hash "google-chrome" 2> /dev/null; then
  export CHROME_EXECUTABLE="google-chrome"
elif hash "google-chrome-stable" 2> /dev/null; then
  export CHROME_EXECUTABLE="google-chrome-stable"
fi

if grep -qi microsoft /proc/version || pgrep -x "Xorg" > /dev/null || pgrep -x "Wayland" > /dev/null; then
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/config.toml"
else
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/lean.config.toml"
fi