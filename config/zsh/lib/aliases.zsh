### Start General

# zsh
alias zshrc="vim ${zsh_dir}/.zshrc"
alias reloadzsh="source ${zsh_dir}/.zshrc"

# Explorer it
alias exploreit="xdg-open ."

# Directories
alias c.='cd ..'
alias c..='cd ../../'
alias c...='cd ../../../'
alias c....='cd ../../../../'
alias c.....='cd ../../../../'
alias cg='cd `git rev-parse --show-toplevel`' # Base of git project

# ls
alias ls="ls --color=auto -p"

# lsd
if [ -x "$(command -v lsd)" ];
then
    alias ll="lsd -lAFh"
    alias lb="lsd -lhSA" # List all files sorted by biggest
    alias lm="lsd -tA -1" # List files sorted by last modified
else
    alias ll="ls -lAFh" # List all files, with full details
    alias lb="ls -lhSA" # List all files sorted by biggest
    alias lm="ls -tA -1" # List files sorted by last modified
fi

### End General

# Laravel
alias laravelnew="composer create-project laravel/laravel"
alias sail='[ -f sail ] && sh sail || sh vendor/bin/sail'
alias php7composer="php7 $(which composer)"

# Flutter
alias fl-rebuild="flutter pub run build_runner build --delete-conflicting-outputs"