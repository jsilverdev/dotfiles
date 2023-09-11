alias zshrc="vim ${zsh_dir}/.zshrc"
alias reloadzsh="source ${zsh_dir}/.zshrc"

# Explorer it
[ -x "$(command -v dolphin)" ] && alias exploreit="dolphin ."

# Getting outa directories
alias c.='cd ..'
alias c..='cd ../../'
alias c...='cd ../../../'
alias c....='cd ../../../../'
alias c.....='cd ../../../../'
alias cg='cd `git rev-parse --show-toplevel`' # Base of git project

# bat
[ -x "$(command -v bat)" ] && alias cat="bat"

# lsd
if [ -x "$(command -v lsd)" ];
then
    alias ls="lsd"
    alias l="lsd -l"
    alias ll="lsd -lAFh"
    alias lb="lsd -lhSA" # List all files sorted by biggest
    alias lm="lsd -tA -1" # List files sorted by last modified
else
    alias ls="ls --color=auto -p"
    alias l="ls -l"
    alias ll="ls -lAFh" # List all files, with full details
    alias lb="ls -lhSA" # List all files sorted by biggest
    alias lm="ls -tA -1" # List files sorted by last modified
fi