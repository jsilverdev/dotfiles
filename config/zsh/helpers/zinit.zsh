### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk


### Plugins

zinit ice depth=1; zinit light romkatv/powerlevel10k

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
# nvm deactivate && nvm uninstall
zinit ice wait lucid
zinit for \
    as'completion' \
    atclone"./fnm completions --shell zsh > _fnm.zsh" \
    atload'eval "$(fnm env --use-on-cd --shell zsh)"' \
    atpull'%atclone' \
    blockf \
    from'gh-r' \
    nocompile \
    sbin'fnm' \
  @Schniz/fnm
fi

zinit ice wait lucid
zinit load wfxr/forgit

# Equivalent to "autoload -Uz compinit && compinit" on zinit
zinit wait lucid atload"zicompinit" blockf for \
     zsh-users/zsh-completions

### End of Plugins