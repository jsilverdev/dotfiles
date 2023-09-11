zinit load zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting

if [ -f "/etc/arch-release" ]; then
zinit ice wait lucid
zinit snippet OMZP::archlinux
fi

zinit ice wait lucid
zinit snippet OMZP::sudo

zinit ice wait lucid
zinit snippet OMZP::git

if [ "$EUID" -ne 0 ]; then
zinit ice wait lucid
zinit load lukechilds/zsh-nvm
fi

zinit ice wait lucid
zinit load wfxr/forgit

# Equivalent to "autoload -Uz compinit && compinit" on zinit
zinit wait lucid atload"zicompinit" blockf for \
     zsh-users/zsh-completions