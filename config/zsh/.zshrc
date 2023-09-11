zsh_dir="${${ZDOTDIR}:-$HOME/.config/zsh}"

source ${zsh_dir}/lib/completions.zsh
source ${zsh_dir}/lib/key-bindings.zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Import P10k config for command prompt, run `p10k configure` or edit
[[ ! -f ${zsh_dir}/.p10k.zsh ]] || source ${zsh_dir}/.p10k.zsh

source ${zsh_dir}/aliases/general.zsh
source ${zsh_dir}/aliases/flutter.zsh
source ${zsh_dir}/aliases/laravel.zsh

source ${zsh_dir}/helpers/setup-zinit.zsh
source ${zsh_dir}/helpers/import-plugins.zsh
source ${zsh_dir}/helpers/setup-zhistory.zsh
source ${zsh_dir}/helpers/extras.zsh

# Append adb to PATH from Android Studio
# [ -d "$HOME/Android/Sdk/platform-tools" ] PATH="$HOME/Android/Sdk/platform-tools:$PATH"

# Append flutter sdk to PATH
[ -d "$HOME/flutter-sdk/bin" ] && export PATH="$HOME/flutter-sdk/bin:$PATH"

# Append composer vendor to PATH
[ -d "$HOME/.config/composer/vendor/bin" ] && export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# Append dagger to PATH
[ -d "$HOME/dagger/bin" ] && export PATH="$HOME/dagger/bin:$PATH"