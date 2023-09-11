zhistory_file="${zsh_dir}/.zhistory"
[[ ! -f "$zhistory_file" ]] && touch "$zhistory_file"
export HISTSIZE=2000
export HISTFILE="$zhistory_file"
export SAVEHIST=$HISTSIZE
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS