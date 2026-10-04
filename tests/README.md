# Test suite

GitHub Actions intentionally contains orchestration only. Reusable fixture and assertion logic lives under this directory.

- `static/` validates source structure, manifests, shell code, PowerShell syntax, chezmoi templates, the encoded AllSigned bridge, and the workflow with actionlint.
- `linux/` runs the real non-interactive Debian and Arch baseline, including package installation, `yay` on Arch, broken-managed-link recovery, unrelated-link preservation, update behavior, and post-bootstrap assertions.
- `windows/` owns WinGet fixture setup, broken-link migration fixtures, normal-policy assertions, AllSigned assertions, and update fixtures.

`DOTFILES_NONINTERACTIVE=1` is the only CI execution mode. It is also a supported real-world mode: baseline dependencies are installed normally while prompts, GUI/workstation customization, shell changes, and WSL setup are skipped.
