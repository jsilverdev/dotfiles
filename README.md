# Dotfiles

This repository uses [chezmoi](https://www.chezmoi.io/) to deploy regular dotfiles on Windows and Linux. Repository support files stay outside the `home/` source state.

## Quick installation

### Windows

Open **Windows PowerShell 5.1** and run:

```powershell
$bootstrap = Join-Path $env:TEMP 'dotfiles-bootstrap.cmd'
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/jsilverdev/dotfiles/main/bootstrap.cmd' -OutFile $bootstrap
& $env:ComSpec /d /c "call `"$bootstrap`""
```

Windows PowerShell 5.1 is only used to download and launch the CMD bootstrap. The bootstrap itself provisions and uses PowerShell 7 where required.

The Windows bootstrap requires WinGet. Before applying chezmoi, it removes only broken links or reparse points that block a currently managed destination path. Parent components under the user profile are checked as well, but valid links are never traversed and unrelated broken links are left untouched. If App Installer exists but WinGet is not registered for the current user, it attempts current-user App Installer registration. If corporate policy disables WinGet, it stops with an error. Bootstrap installs only Git, PowerShell 7, and chezmoi when they are missing; the platform installer owns the remaining application catalog.

Baseline CLI packages are declared in `scripts/windows/managed-apps.csv` and are installed with WinGet in user scope. Cascadia Code plus the Cascadia Code and Cascadia Mono Nerd Font variants are installed for the current user as part of the Windows baseline, including non-interactive runs. An interactive run additionally installs workstation applications, configures Windows Terminal, and offers optional applications. `DOTFILES_NONINTERACTIVE=1` installs the complete CLI/font baseline while skipping those interactive/workstation customizations.

The bootstrap does not require administrator rights or Developer Mode. It invokes PowerShell 7 with `-NoProfile`; an effective `AllSigned` policy is supported automatically. Each machine reuses or creates its own current-user Code Signing certificate and trusts its public certificate locally. No private key, PFX, or KeePass dependency is used.

### Linux

On Debian or Arch Linux, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jsilverdev/dotfiles/main/bootstrap.sh)
```

The bootstrap installs only the prerequisites required to obtain/apply the repository, installs chezmoi in `~/.local/bin` when needed, removes only broken symlinks that block currently managed destination paths, and then applies the source state before running the package installer. Parent components under `$HOME` are checked without traversing valid symlinks, and unrelated broken links are left untouched. Linux package catalogs are declared under `scripts/linux/`. Non-interactive mode still installs and validates the complete baseline; it only skips shell changes, WSL system configuration, and optional-package prompts. Arch continues to install and manage `yay`.

## Updates

For dotfiles-only updates, use:

```text
chezmoi update
```

For dotfiles plus installer-managed package/application/module updates, use `update.cmd` on Windows or `./update.sh` on Linux. Those wrappers run `chezmoi update` first and then rerun the platform installer in update mode. Starship and managed PowerShell modules participate in update mode as well.

## State details

- `home/.chezmoiroot` is represented by the repository-level `.chezmoiroot`, pointing to `home`.
- Windows-only `.wslconfig` and Linux-only Zsh/Sheldon state are filtered by `home/.chezmoiignore`.
- `~/.gitconfig.local`, `~/.codex/config.toml`, and `~/.codex/rules/default.rules` use chezmoi create-only semantics and are not overwritten after creation.
- Codex guidance and skills are managed normally; repository documentation is kept outside `~/.codex`.
- PowerShell source files are unsigned templates. The post-apply hook deploys copies and signs only the runtime files when `AllSigned` is effective, so Authenticode signatures never dirty chezmoi source state.
- Managed PowerShell modules are declared in `scripts/windows/managed-modules.txt`. Under `AllSigned`, managed PowerShell files are re-signed with the locally trusted dotfiles certificate unless they already carry a valid signature from that same certificate. This deliberately normalizes the publisher used by the non-interactive AllSigned path.

## CI and testing

The `Validate dotfiles` workflow exercises Debian, Arch Linux, Windows with its normal execution policy, and Windows with a simulated current-user `AllSigned` policy. GitHub Actions only orchestrates the scenarios; reusable fixture and assertion logic lives under `tests/`.

Integration jobs bootstrap from a temporary local bare Git remote containing the exact commit under test. They run the real non-interactive baseline, validate installed CLI tools and current-user fonts, exercise create-only Codex files and update wrappers, check idempotent chezmoi apply, and verify clean source/checkout state. Windows font assertions verify both the files under `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and their matching `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` entries. Static validation includes ShellCheck, PowerShell parsing, manifest checks, chezmoi template evaluation, bridge-payload synchronization, and pinned `actionlint` validation of the workflow.

The Windows AllSigned job validates current-user certificate creation and reuse, Authenticode signing, the CMD execution bridge, PowerShell profile startup, and managed module loading. When PowerShell 7 requires signed scripts, the bridge uses inbox Windows PowerShell only for Authenticode signing and executes the resulting signed script with PowerShell 7 under the effective policy. The hosted runner is an administrator with UAC disabled, so CI trusts the test certificate through `LocalMachine\Root` plus `CurrentUser\TrustedPublisher`; runtime helpers also accept `CurrentUser\Root` for the real non-admin path. Corporate GPO/MDM/AppLocker/WDAC policy, enterprise App Installer policy, and a true non-admin corporate Windows 11 token still require validation on a managed machine.


## Acknowledgments

This dotfiles repository is inspired by:
- [Lissy93's dotfiles](https://github.com/Lissy93/dotfiles)
- [KEVINNITRO DOTFILES](https://github.com/KevinNitroG/dotfiles).
