if command -v sheldon > /dev/null 2>&1; then
    : "${ZSH:=${SHELDON_DATA_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/sheldon}/repos/github.com/ohmyzsh/ohmyzsh}"
    export ZSH

    eval "$(sheldon source)"
else
    autoload -Uz compinit
    compinit
fi
