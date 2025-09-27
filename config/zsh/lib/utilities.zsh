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

# Add fzf autocompletion
if [ -f "/etc/arch-release" ]; then
  [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
  [ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
elif [ -f "/etc/debian_version" ]; then
  [ -d "$HOME/.config/fzf/bin" ] && export PATH="$PATH:$HOME/.config/fzf/bin" && eval "$(fzf --zsh)"
fi

# fd command
FD_COMMAND='fd'
[ -f "/etc/debian_version" ] && FD_COMMAND='fdfind'

# Add fd customizations for fzf
if [ -x "$(command -v $FD_COMMAND)" ]; then
  # Commands
  export FZF_DEFAULT_COMMAND="$FD_COMMAND --ignore-file $HOME/.fdignore --type f --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="$FD_COMMAND --ignore-file $HOME/.fdignore --type d"

  # Options
  export FZF_DEFAULT_OPTS="--extended --border --info=inline --height 80% --layout=reverse
    --color=border:#808080,spinner:#fede5d,hl:#7E8E91,fg:#E3E5E5,header:#7E8E91,info:#1d99f3,pointer:#1d99f3,marker:#03edf9,fg+:#E3E5E5,prompt:#03edf9,hl+:#03edf9"

  BAT_COMMAND='bat'
  [ -x "$(command -v batcat)" ] && BAT_COMMAND='batcat'

  FZF_CTRL_T_TOGGLE='ctrl-a:transform:[[ $FZF_PROMPT =~ Default ]] &&
      echo "change-prompt(All> )+reload('$FD_COMMAND' --hidden --no-ignore --follow --exclude .git)" ||
      echo "change-prompt(Default> )+reload('$FZF_CTRL_T_COMMAND')"'
  export FZF_CTRL_T_OPTS="
    --scheme=path
    --prompt 'Default> '
    --bind '$FZF_CTRL_T_TOGGLE'
    --header 'CTRL-A: Toggle Show'
    --preview '$BAT_COMMAND -n --color=always --line-range :200 {}'"

  FZF_ALT_C_TOGGLE='ctrl-a:transform:[[ $FZF_PROMPT =~ Default ]] &&
      echo "change-prompt(All> )+reload('$FD_COMMAND' --type d --hidden --no-ignore --exclude .git)" ||
      echo "change-prompt(Default> )+reload('$FZF_ALT_C_COMMAND')"'
  export FZF_ALT_C_OPTS="
    --scheme=path
    --prompt 'Default> '
    --bind='$FZF_ALT_C_TOGGLE'
    --header 'CTRL-A: Toggle Show'
    --preview 'tree -C {} | head -200'"
fi

### End fzf

### Starship
eval "$(starship init zsh)"

### FNM (Fast Node Manager)
[ -d "$FNM_DIR" ] && export PATH="$FNM_DIR:$PATH" && hash "fnm" 2> /dev/null && eval "$(fnm env --use-on-cd --shell zsh)"

