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