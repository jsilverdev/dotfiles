#!/usr/bin/env bash
set -euo pipefail

expected_distro="${1:?expected distribution (debian or arch) is required}"
expected_commit="${2:-}"
repo_root="${GITHUB_WORKSPACE:-$(pwd)}"

fail() { printf 'ASSERTION FAILED: %s\n' "$1" >&2; exit 1; }

printf 'distribution: %s\n' "$(tr '\n' ' ' < /etc/os-release)"
printf 'uname: %s\n' "$(uname -a)"
printf 'user: %s (%s)\n' "$(id -un)" "$(id -u)"
printf 'HOME: %s\n' "$HOME"
printf 'chezmoi: %s\n' "$(chezmoi --version)"
printf 'chezmoi source-path: %s\n' "$(chezmoi source-path)"

source_path="$(chezmoi source-path)"
[[ "$source_path" == "$HOME/.dotfiles" ]] || fail "chezmoi source path is $source_path, expected $HOME/.dotfiles"

case "$expected_distro" in
    debian) [[ -f /etc/debian_version ]] || fail "Debian detection marker is missing" ;;
    arch) [[ -f /etc/arch-release ]] || fail "Arch detection marker is missing" ;;
    *) fail "unknown expected distribution: $expected_distro" ;;
esac

sudo -n true || fail "the CI user does not have passwordless sudo"

required_files=(
    "$HOME/.gitconfig" "$HOME/.gitconfig.local" "$HOME/.fdignore" "$HOME/.zshenv"
    "$HOME/.config/zsh/.zshrc" "$HOME/.config/zsh/lib/aliases.zsh"
    "$HOME/.config/zsh/lib/completions.zsh" "$HOME/.config/zsh/lib/key-bindings.zsh"
    "$HOME/.config/zsh/lib/sheldon.zsh" "$HOME/.config/starship/config.toml"
    "$HOME/.config/starship/lean.config.toml" "$HOME/.config/sheldon/plugins.toml"
    "$HOME/.codex/AGENTS.md" "$HOME/.codex/skills/mule-munit/SKILL.md"
    "$HOME/.codex/skills/mule-munit/agents/openai.yaml"
)
for path in "${required_files[@]}"; do [[ -f "$path" ]] || fail "expected deployed file is missing: $path"; done

while IFS= read -r requirement; do
    [[ -n "$requirement" && "$requirement" != \#* ]] || continue
    found=false
    IFS='|' read -r -a candidates <<< "$requirement"
    for command_name in "${candidates[@]}"; do
        if command -v "$command_name" >/dev/null 2>&1; then found=true; break; fi
    done
    [[ "$found" == true ]] || fail "required baseline command is unavailable: $requirement"
done < "$repo_root/scripts/linux/required-commands.txt"

if [[ "$expected_distro" == "arch" ]]; then command -v yay >/dev/null 2>&1 || fail "yay is unavailable on Arch"; fi

assert_clean() {
    local status
    status="$(chezmoi status)"
    [[ -z "$status" ]] || fail "chezmoi status is not clean: $status"
}

chezmoi apply
chezmoi apply
assert_clean

if [[ -n "$expected_commit" ]]; then
    source_path="$(chezmoi source-path)"
    source_commit="$(git -C "$source_path" rev-parse HEAD)"
    [[ "$source_commit" == "$expected_commit" ]] || fail "source commit $source_commit is not expected commit $expected_commit"
fi

config_marker="ci-create-only-$(date +%s)"
rules_marker="ci-create-only-rule-$(date +%s)"
printf '\n%s\n' "$config_marker" >> "$HOME/.codex/config.toml"
printf '\n%s\n' "$rules_marker" >> "$HOME/.codex/rules/default.rules"
chezmoi apply
grep -Fqx "$config_marker" "$HOME/.codex/config.toml" || fail "chezmoi overwrote create-only config.toml"
grep -Fqx "$rules_marker" "$HOME/.codex/rules/default.rules" || fail "chezmoi overwrote create-only default.rules"
assert_clean

source_path="$(chezmoi source-path)"
[[ -z "$(git -C "$source_path" status --porcelain)" ]] || fail "chezmoi source Git tree is dirty"
[[ -z "$(git -C "$repo_root" status --porcelain)" ]] || fail "Actions checkout Git tree is dirty"

printf 'Linux state assertions passed for %s.\n' "$expected_distro"
