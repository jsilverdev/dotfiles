# Windows fonts

The Windows baseline installs these font families for the current user:

- Microsoft Cascadia Code
- Caskaydia Cove Nerd Font (Nerd Fonts patched Cascadia Code)
- Caskaydia Mono Nerd Font (Nerd Fonts patched Cascadia Mono)

Expected filename globs are declared in `scripts/windows/managed-fonts.txt`.

The installer downloads fonts into the chezmoi working tree's ignored `fonts/` directory, copies the resulting font files to `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, and maintains matching entries under `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`.

The Windows integration jobs validate the installed files and registry entries after both bootstrap and update, under the normal execution policy and `AllSigned`.
