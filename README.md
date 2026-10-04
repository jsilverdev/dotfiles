# Dotfiles

This repository uses [chezmoi](https://www.chezmoi.io/) to deploy regular dotfiles on Windows and Linux. Repository support files stay outside the `home/` source state.

## Quick installation

### Windows

Run this from a normal `cmd.exe` prompt:

```cmd
curl.exe -fsSLo "%TEMP%\dotfiles-bootstrap.cmd" https://raw.githubusercontent.com/jsilverdev/dotfiles/main/bootstrap.cmd && call "%TEMP%\dotfiles-bootstrap.cmd"
```

The Windows bootstrap requires WinGet. If App Installer exists but WinGet is not registered for the current user, it attempts current-user App Installer registration. If corporate policy disables WinGet, it stops with an error. Core packages are installed with WinGet in user scope and the bootstrap does not silently fall back to machine-scope or portable packages. Core mode includes the CLI toolchain (`micro`, `lsd`, `bat`, `fastfetch`, `fzf`, `fd`, `delta`, `jq`, `rg`, and `mise`); workstation-only packages such as 7-Zip, PowerToys, and VS Code are installed only outside core mode.

The bootstrap does not require administrator rights or Developer Mode. It invokes PowerShell 7 with `-NoProfile`; an effective `AllSigned` policy is supported automatically. Each machine reuses or creates its own current-user Code Signing certificate and trusts its public certificate locally. No private key, PFX, or KeePass dependency is used.

### Linux

On Debian or Arch Linux, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jsilverdev/dotfiles/main/bootstrap.sh)
```

The bootstrap installs the minimal tools, installs chezmoi in `~/.local/bin` when needed, applies the home state, and then runs the package/application installer. WSL-specific system configuration is applied only when the installer is running inside WSL.

## Updates

For dotfiles-only updates, use:

```text
chezmoi update
```

For dotfiles plus package/application and module updates, use `update.cmd` on Windows or `./update.sh` on Linux. Those wrappers run `chezmoi update` first and then the platform installer in update mode.

## State details

- `home/.chezmoiroot` is represented by the repository-level `.chezmoiroot`, pointing to `home`.
- Windows-only `.wslconfig` and Linux-only Zsh/Sheldon state are filtered by `home/.chezmoiignore`.
- `~/.gitconfig.local`, `~/.codex/config.toml`, and `~/.codex/rules/default.rules` use chezmoi create-only semantics and are not overwritten after creation.
- Codex guidance and skills are managed normally; repository documentation is kept outside `~/.codex`.
- PowerShell source files are unsigned templates. The post-apply hook deploys copies and signs only the runtime files when `AllSigned` is effective, so Authenticode signatures never dirty chezmoi source state.
- Managed PowerShell modules currently include `PSFzf` and `git-aliases`. Under `AllSigned`, only their user-scoped PowerShell content is inspected and unsigned/invalid files are signed; valid publisher signatures are preserved.

## CI and testing

The `Validate dotfiles` workflow exercises the current chezmoi/bootstrap architecture on Debian, Arch Linux, Windows with its normal execution policy, and Windows with a simulated current-user `AllSigned` policy. Integration jobs bootstrap from a temporary local bare Git remote containing the exact commit under test, then check deployment, create-only Codex files, update wrappers, idempotent apply, signatures, module loading, and clean chezmoi/source Git state.

The Windows AllSigned job validates the hosted Windows Server behavior that can be reproduced in CI: current-user certificate creation and reuse, Authenticode signing, the CMD execution bridge, PowerShell profile startup, and managed module loading. When PowerShell 7 requires signed scripts, the bridge uses inbox Windows PowerShell only for Authenticode signing and executes the resulting signed script with PowerShell 7 under the effective policy. The hosted runner is an administrator with UAC disabled, so CI trusts the test certificate through `LocalMachine\\Root` plus `CurrentUser\\TrustedPublisher`; the runtime helpers also accept `CurrentUser\\Root` for the real non-admin path. Corporate GPO/MDM/AppLocker/WDAC policy, enterprise App Installer policy, and a true non-admin corporate Windows 11 token still require validation on a managed machine.
