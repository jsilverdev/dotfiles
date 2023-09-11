# Directory for all-things ZSH config
zsh_dir="${${ZDOTDIR}:-$HOME/.config/zsh}"
utils_dir="${XDG_CONFIG_HOME}/utils"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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

zinit ice depth=1; zinit light romkatv/powerlevel10k

source ${zsh_dir}/lib/completions.zsh

# Import P10k config for command prompt, run `p10k configure` or edit
[[ ! -f ${zsh_dir}/.p10k.zsh ]] || source ${zsh_dir}/.p10k.zsh

### Bind keys

# ctrl + left-key (XFree 4)
bindkey "^[[1;5D" backward-word
# ctrl + right-key (XFree 4)
bindkey "^[[1;5C" forward-word
# start (XFree 4)
bindkey  "^[[H"  beginning-of-line
# end (XFree 4)
bindkey  "^[[F"  end-of-line
# ctrl + space
bindkey "^ " autosuggest-accept
# shift + tab
bindkey "^[[Z" reverse-menu-complete
# up-arrow
bindkey '\e[A' history-search-backward
# down-arrow
bindkey '\e[B' history-search-forward

### End of Bind keys


### Personal plugins

zinit load zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting

zinit ice wait lucid
zinit snippet OMZP::archlinux

zinit ice wait lucid
zinit snippet OMZP::sudo

zinit ice wait lucid
zinit snippet OMZP::git

if [ "$EUID" -ne 0 ]; then
zinit ice wait lucid
zinit load lukechilds/zsh-nvm

export NVM_DIR=~/.nvm
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

zinit ice wait lucid
zinit load wfxr/forgit

# Equivalent to "autoload -Uz compinit && compinit" on zinit
zinit wait lucid atload"zicompinit" blockf for \
     zsh-users/zsh-completions


### End of Personal plugins


### Extensions

# forgit
FORGIT_STASH_FZF_OPTS='
--bind="ctrl-d:reload(git stash drop $(cut -d: -f1 <<<{}) 1>/dev/null && git stash list),ctrl-space:reload(git stash pop $(cut -d: -f1 <<<{}) 1>/dev/null && git stash list)"
'

# fzf
[ ! -x "$(command -v fzf)" ] && yes | sudo pacman -S fzf
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh


# fd
[ ! -x "$(command -v fd)" ] && yes | sudo pacman -S fd
if [ -x "$(command -v fd)" ]; then
 export FZF_DEFAULT_COMMAND='fd --ignore-file ~/.fdignore --type f --follow --exclude .git'

 export FZF_DEFAULT_OPS='--extended --border --info=inline --height 80%'

 export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

 export FZF_CTRL_T_OPTS="--bind='ctrl-y:reload(fd --hidden --no-ignore --follow --exclude .git),ctrl-t:reload($FZF_DEFAULT_COMMAND)' $FZF_DEFAULT_OPS --preview '(bat --style=numbers --color=always --line-range :500 {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"

 export FZF_ALT_C_COMMAND="fd --ignore-file ~/.fdignore --type d"
 export FZF_ALT_C_OPTS="--bind='alt-v:reload(fd --type d --hidden --no-ignore --exclude .git),alt-c:reload($FZF_ALT_C_COMMAND)' $FZF_DEFAULT_OPS --preview 'tree -C {} | head -200'"
fi

# vivid: https://github.com/sharkdp/vivid
[ ! -x "$(command -v vivid)" ] && yes | sudo pacman -S vivid
[ -x "$(command -v vivid)" ] && export LS_COLORS="$(vivid generate snazzy)"

### End of Extensions


### Custom aliases

# bat
[ ! -x "$(command -v bat)" ] && yes | sudo pacman -S bat
[ -x "$(command -v bat)" ] && alias cat="bat"

# lsd
[ ! -x "$(command -v lsd)" ] && yes | sudo pacman -S lsd
if [ -x "$(command -v lsd)" ];
then
    alias ls="lsd"
    alias l="lsd -l"
    alias ll="lsd -alh"
else
     alias ls="ls --color=auto -p"
     alias l="ls -l"
     alias ll="ls -alh"
fi

alias zshrc="vim  ~/.zshrc"

alias reloadzsh="source ~/.zshrc"

alias service="sudo systemctl"
alias clear-cache="sh -c 'echo 3 >  /proc/sys/vm/drop_caches'"
alias exploreit="dolphin ."
alias httpdconf="sudo vim /etc/httpd/conf/httpd.conf"
# Uncomment this on http.conf: "Include conf/extra/httpd-vhosts.conf"
alias vhostconf="sudo vim /etc/httpd/conf/extra/httpd-vhosts.conf"
alias phpini="sudo vim /etc/php/php.ini"

# docker
alias docker-clean="docker ps -qaf status=exited | xargs docker rm"

# laravel
alias laravelnew="composer create-project laravel/laravel"
alias sail="./vendor/bin/sail"
alias php7composer="php7 $(which composer)"

# flutter
alias fl-rebuild="flutter pub run build_runner build --delete-conflicting-outputs"

alias azuredatastudio-tls1="env OPENSSL_CONF=$HOME/.openssl-tlsv1.cnf azuredatastudio"

### End of Custom aliases


### History
[[ ! -f ~/.zhistory ]] && touch ~/.zhistory
export HISTSIZE=2000
export HISTFILE="$HOME/.zhistory"
export SAVEHIST=$HISTSIZE
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
### End of History


### Custom paths

# chrome
[ -x "$(command -v google-chrome-stable)" ] && export CHROME_EXECUTABLE="google-chrome-stable"

# adb
#PLATFORM_TOOLS_PATH="$HOME/Android/Sdk/platform-tools"
#if [  -d $PLATFORM_TOOLS_PATH ]; then
#  [[ "$(pacman -Q | grep -w android-tools | awk '{print $1}')" == 'android-tools' ]] && yes | sudo pacman -R android-tools
#  export PATH="$PATH:$PLATFORM_TOOLS_PATH"
#fi

# flutter
FLUTTER_PATH_TO_SDKBIN="$HOME/flutter-sdk/bin"
[ -d $FLUTTER_PATH_TO_SDKBIN ] && export PATH="$PATH:$FLUTTER_PATH_TO_SDKBIN"

# composer
COMPOSER_PATH_TO_BIN="$HOME/.config/composer/vendor/bin"
[ -d $COMPOSER_PATH_TO_BIN ] && export PATH="$PATH:$COMPOSER_PATH_TO_BIN"

# dagger
DAGGER_PATH_TO_BIN="$HOME/dagger/bin/"
[ -d $DAGGER_PATH_TO_BIN ] && export PATH="$PATH:$DAGGER_PATH_TO_BIN"

### End of Custom paths

### Custom Exports

export VISUAL=vim

### End of Custom Exports




