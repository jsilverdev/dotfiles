#!/usr/bin/env bash
set -euo pipefail

distro="${1:?distro required}"
commit="${2:?commit required}"
repo="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

git config --global --add safe.directory "$repo"
[[ "$(git -C "$repo" rev-parse HEAD)" == "$commit" ]]

remote_parent="$(mktemp -d)"
remote="$remote_parent/dotfiles.git"
git init --bare "$remote"
git -C "$repo" push "$remote" "$commit:refs/heads/main"
git --git-dir="$remote" symbolic-ref HEAD refs/heads/main
chmod -R a+rX "$repo"

useradd --create-home --shell /bin/bash dotfilesci
printf 'dotfilesci ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dotfilesci
chmod 0440 /etc/sudoers.d/dotfilesci
chown -R dotfilesci:dotfilesci "$remote_parent"

as_ci() {
    sudo -u dotfilesci -H env HOME=/home/dotfilesci USER=dotfilesci "$@"
}

as_ci bash -lc '
    mkdir -p "$HOME/.config"

    ln -s /nonexistent/legacy-fdignore "$HOME/.fdignore"
    ln -s /nonexistent/legacy-starship "$HOME/.config/starship"
    ln -s /nonexistent/unrelated-link "$HOME/.dotfiles-ci-unrelated-broken-link"
'

as_ci GITHUB_WORKSPACE="$repo" DOTFILES_REPO="file://$remote" DOTFILES_NONINTERACTIVE=1 bash -lc 'cd /tmp; bash "$GITHUB_WORKSPACE/bootstrap.sh"'

as_ci bash -lc '
    [[ -f "$HOME/.fdignore" && ! -L "$HOME/.fdignore" ]]
    [[ -d "$HOME/.config/starship" && ! -L "$HOME/.config/starship" ]]
    [[ -f "$HOME/.config/starship/config.toml" ]]
    [[ -L "$HOME/.dotfiles-ci-unrelated-broken-link" ]]
    [[ ! -e "$HOME/.dotfiles-ci-unrelated-broken-link" ]]
'

as_ci PATH="/home/dotfilesci/.local/bin:$PATH" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$repo" GITHUB_WORKSPACE="$repo" D="$distro" C="$commit" bash -lc 'bash "$GITHUB_WORKSPACE/tests/linux/assert-state.sh" "$D" "$C"'

marker="ci-update-marker-${GITHUB_RUN_ID:-local}"
as_ci DOTFILES_REPO="file://$remote" M="$marker" bash -lc '
    set -euo pipefail
    work="$(mktemp -d)"
    git clone "$DOTFILES_REPO" "$work/repo"
    git -C "$work/repo" config user.name ci
    git -C "$work/repo" config user.email ci@example.invalid
    printf "\n%s\n" "$M" >> "$work/repo/home/dot_fdignore"
    git -C "$work/repo" add home/dot_fdignore
    git -c commit.gpgsign=false -C "$work/repo" commit -m "CI update fixture"
    git -C "$work/repo" push origin HEAD:refs/heads/main
'

as_ci PATH="/home/dotfilesci/.local/bin:$PATH" GITHUB_WORKSPACE="$repo" DOTFILES_NONINTERACTIVE=1 bash -lc 'bash "$GITHUB_WORKSPACE/update.sh" --non-interactive'

as_ci PATH="/home/dotfilesci/.local/bin:$PATH" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$repo" GITHUB_WORKSPACE="$repo" D="$distro" M="$marker" bash -lc 'grep -Fqx "$M" "$HOME/.fdignore"; bash "$GITHUB_WORKSPACE/tests/linux/assert-state.sh" "$D"'
