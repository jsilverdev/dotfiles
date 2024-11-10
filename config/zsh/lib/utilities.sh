# Modify LS_COLORS with vivid (https://github.com/sharkdp/vivid)
[ -x "$(command -v vivid)" ] && export LS_COLORS="$(vivid generate snazzy)"

### Start zhistory
zhistory_file="${zsh_dir}/.zhistory"
[[ ! -f "$zhistory_file" ]] && touch "$zhistory_file"
export HISTSIZE=2000
export HISTFILE="$zhistory_file"
export SAVEHIST=$HISTSIZE
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
### End zhistory

### Start fzf
if [ -x "$(command -v fzf)" ]; then
  # DEBIAN: git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install
  source <(fzf --zsh)
fi

# fd command
FD_COMMAND='fd'
[ -f "/etc/debian_version" ] && FD_COMMAND='fdfind'

# Add fd customizations for fzf
if [ -x "$(command -v $FD_COMMAND)" ]; then
 export FZF_DEFAULT_COMMAND="$FD_COMMAND --ignore-file ~/.fdignore --type f --follow --exclude .git"
 export FZF_DEFAULT_OPS='--extended --border --info=inline --height 80%'
 export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
 export FZF_CTRL_T_OPTS="--bind='ctrl-y:reload($FD_COMMAND --hidden --no-ignore --follow --exclude .git),ctrl-t:reload($FZF_DEFAULT_COMMAND)' $FZF_DEFAULT_OPS --preview '(bat --style=numbers --color=always --line-range :500 {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
 export FZF_ALT_C_COMMAND="$FD_COMMAND --ignore-file ~/.fdignore --type d"
 export FZF_ALT_C_OPTS="--bind='alt-v:reload($FD_COMMAND --type d --hidden --no-ignore --exclude .git),alt-c:reload($FZF_ALT_C_COMMAND)' $FZF_DEFAULT_OPS --preview 'tree -C {} | head -200'"
fi
### End fzf

### Starship
eval "$(starship init zsh)"