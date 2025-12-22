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
[ -x "$(command -v fdfind)" ] && FD_COMMAND='fdfind'

# Add fd customizations for fzf
if [ -x "$(command -v $FD_COMMAND)" ]; then
  # Commands
  export FZF_DEFAULT_COMMAND="$FD_COMMAND --ignore-file $HOME/.fdignore --type f --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="$FD_COMMAND --ignore-file $HOME/.fdignore --type d"

  # Options
  export FZF_DEFAULT_OPTS="--extended --border --info=inline --height 80% --layout=default
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
    --preview 'lsd --tree -I ".**" --depth 3 --color=always --icon=always --sort=none {}'"
fi


fzf_content_search() {
  rm -f /tmp/rg-fzf-{r,f}
  local RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  local INITIAL_QUERY="${*:-}"
  fzf --ansi --disabled --query "$INITIAL_QUERY" \
      --bind "start:reload($RG_PREFIX {q})+unbind(ctrl-r)" \
      --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
      --bind "ctrl-f:unbind(change,ctrl-f)+change-prompt(2. fzf> )+enable-search+rebind(ctrl-r)+transform-query(echo {q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f)" \
      --bind "ctrl-r:unbind(ctrl-r)+change-prompt(1. ripgrep> )+disable-search+reload($RG_PREFIX {q} || true)+rebind(change,ctrl-f)+transform-query(echo {q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r)" \
      --color "hl:-1:underline,hl+:-1:underline:reverse" \
      --prompt '1. ripgrep> ' \
      --delimiter : \
      --header '╱ CTRL-R (ripgrep mode) ╱ CTRL-F (fzf mode) ╱' \
      --preview "$BAT_COMMAND --color=always {1} --highlight-line {2}" \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
      --bind 'enter:become(micro {1} +{2})'
}

if [[ $- == *i* ]] && command -v zle >/dev/null; then
  fzf_content_search_widget() {
    fzf_content_search "${(z)LBUFFER}"
    zle reset-prompt
  }
  zle -N fzf_content_search_widget
  # Bind Alt+X (Meta-x) to the widget
  bindkey '\ex' fzf_content_search_widget
fi


### End fzf

### Starship
eval "$(starship init zsh)"

### mise-en-place
hash "mise" 2> /dev/null && eval "$(mise activate zsh)"