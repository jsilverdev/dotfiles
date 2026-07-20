# Codex dotfiles

This directory contains only portable Codex defaults. Dotbot links stable
guidance and skills to `~/.codex`; mutable files are copied only when missing.

## Included

- `config.toml.example`: initial UI, sandbox, features, and default reasoning
  effort. The installer copies it to `~/.codex/config.toml` only when missing.
- `AGENTS.md`: personal working conventions that apply to every repository.
- `rules/default.rules.example`: initial narrowly scoped command approvals.
- `skills/*`: the individual files of every skill placed in this directory are
  linked to `~/.codex/skills`, including the bundled `mule-munit` workflow.

## Deliberately excluded

- `model`: Codex automatically selects an available model.
- `[projects.*]`: machine-specific trusted paths.
- MCP servers, tokens, account identifiers, and company endpoints.
- `auth.json`, history, sessions, logs, caches, databases, and installed-skill or plugin caches.

Codex writes trusted project paths to `~/.codex/config.toml` and can append
approved command rules to `~/.codex/rules/default.rules`. Keeping both local
prevents those machine-specific changes from modifying this repository.

Use a profile such as `~/.codex/work.config.toml` later for work-only MCP
servers, model overrides, and machine-specific settings. Select it with
`codex --profile work`.

Use a repository's `.codex/config.toml` and `AGENTS.md` for settings that
belong only to that repository.
