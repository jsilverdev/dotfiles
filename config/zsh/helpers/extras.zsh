# Modify LS_COLORS with vivid (https://github.com/sharkdp/vivid)
[ -x "$(command -v vivid)" ] && export LS_COLORS="$(vivid generate snazzy)"

# Add fzf autocompletions
if [ -f "/etc/arch-release" ]; then
  [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
  [ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
fi

# Add fd customizatons for fzf
if [ -x "$(command -v fd)" ]; then
 export FZF_DEFAULT_COMMAND='fd --ignore-file ~/.fdignore --type f --follow --exclude .git'
 export FZF_DEFAULT_OPS='--extended --border --info=inline --height 80%'
 export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
 export FZF_CTRL_T_OPTS="--bind='ctrl-y:reload(fd --hidden --no-ignore --follow --exclude .git),ctrl-t:reload($FZF_DEFAULT_COMMAND)' $FZF_DEFAULT_OPS --preview '(bat --style=numbers --color=always --line-range :500 {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
 export FZF_ALT_C_COMMAND="fd --ignore-file ~/.fdignore --type d"
 export FZF_ALT_C_OPTS="--bind='alt-v:reload(fd --type d --hidden --no-ignore --exclude .git),alt-c:reload($FZF_ALT_C_COMMAND)' $FZF_DEFAULT_OPS --preview 'tree -C {} | head -200'"
fi

# Add forgit option for git stash
FORGIT_STASH_FZF_OPTS='
--bind="ctrl-d:reload(git stash drop $(cut -d: -f1 <<<{}) 1>/dev/null && git stash list),ctrl-space:reload(git stash pop $(cut -d: -f1 <<<{}) 1>/dev/null && git stash list)"
'

# Define Chrome executable
if [ -x "$(command -v google-chrome)" ]; then
  export CHROME_EXECUTABLE="google-chrome"
elif [ -x "$(command -v google-chrome-stable)" ]; then
  export CHROME_EXECUTABLE="google-chrome-stable"
fi