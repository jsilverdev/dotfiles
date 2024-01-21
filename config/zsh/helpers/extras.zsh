# Modify LS_COLORS with vivid (https://github.com/sharkdp/vivid)
[ -x "$(command -v vivid)" ] && export LS_COLORS="$(vivid generate snazzy)"

# Add fzf autocompletions
if [ -f "/etc/arch-release" ]; then
  [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
  [ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
elif [ -f "/etc/debian_version" ]; then
  # git clone https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi

# fd command
FD_COMMAND='fd'
if [ -f "/etc/debian_version" ]; then
  FD_COMMAND='fdfind'
fi

# Add fd customizatons for fzf
if [ -x "$(command -v $FD_COMMAND)" ]; then
 export FZF_DEFAULT_COMMAND="$FD_COMMAND --ignore-file ~/.fdignore --type f --follow --exclude .git"
 export FZF_DEFAULT_OPS='--extended --border --info=inline --height 80%'
 export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
 export FZF_CTRL_T_OPTS="--bind='ctrl-y:reload($FD_COMMAND --hidden --no-ignore --follow --exclude .git),ctrl-t:reload($FZF_DEFAULT_COMMAND)' $FZF_DEFAULT_OPS --preview '(bat --style=numbers --color=always --line-range :500 {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
 export FZF_ALT_C_COMMAND="$FD_COMMAND --ignore-file ~/.fdignore --type d"
 export FZF_ALT_C_OPTS="--bind='alt-v:reload($FD_COMMAND --type d --hidden --no-ignore --exclude .git),alt-c:reload($FZF_ALT_C_COMMAND)' $FZF_DEFAULT_OPS --preview 'tree -C {} | head -200'"
fi


# Define Chrome executable
if [ -x "$(command -v google-chrome)" ]; then
  export CHROME_EXECUTABLE="google-chrome"
elif [ -x "$(command -v google-chrome-stable)" ]; then
  export CHROME_EXECUTABLE="google-chrome-stable"
fi