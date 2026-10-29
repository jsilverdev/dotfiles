# Global Codex guidance

- Reproduce the reported behavior before changing files when practical.
- Treat the current repository configuration, contracts, and tests as the source of truth.
- Keep changes scoped to the request and preserve existing behavior unless a redesign is requested.
- Inspect the final diff and run the narrowest relevant validation after an edit.
- Report the validation command and its result; do not claim checks that did not run.
- Never commit credentials, tokens, local sessions, logs, caches, or machine-specific paths.
- Prefer a repository-level `AGENTS.md` or `.codex/config.toml` for rules that only apply to that repository.
- On Windows, run non-interactive PowerShell commands without loading the user profile. Prefer `shell: powershell` with `login: false`; when launching `pwsh` explicitly, use `-NoLogo -NoProfile -NonInteractive`. Resolve executables with `Get-Command` only when a command is not found, an absolute path is required, or multiple versions may exist. Load the profile only when the requested command depends on profile-defined state.
