zsh_dir="${ZDOTDIR:-$HOME/.config/zsh}"

source "${zsh_dir}/lib/aliases.zsh"
source "${zsh_dir}/lib/key-bindings.zsh"
source "${zsh_dir}/lib/envs.zsh"

source "${zsh_dir}/lib/zinit.zsh"
source "${zsh_dir}/lib/completions.zsh"
source "${zsh_dir}/lib/utilities.zsh"

# WSL
if grep -qi microsoft /proc/version; then
    source "${zsh_dir}/lib/wsl.zsh"
fi