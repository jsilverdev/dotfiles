# Global Codex guidance

- Reproduce the reported behavior before changing files when practical.
- Treat the current repository configuration, contracts, and tests as the source of truth.
- Keep changes scoped to the request and preserve existing behavior unless a redesign is requested.
- Inspect the final diff and run the narrowest relevant validation after an edit.
- Report the validation command and its result; do not claim checks that did not run.
- Never commit credentials, tokens, local sessions, logs, caches, or machine-specific paths.
- Prefer a repository-level `AGENTS.md` or `.codex/config.toml` for rules that only apply to that repository.
