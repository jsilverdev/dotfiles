# Dotfiles

Personal dotfiles for Windows, Debian, and Arch Linux, managed with [chezmoi](https://www.chezmoi.io/).

Fresh installations use `~/.dotfiles` as the chezmoi working tree.

## Installation

### Windows

Open **Windows PowerShell 5.1** and run:

```powershell
$bootstrap="$env:TEMP\dotfiles-bootstrap.cmd"; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/jsilverdev/dotfiles/main/bootstrap.cmd' -OutFile $bootstrap; & $env:ComSpec /d /c "`"$bootstrap`""
```

WinGet is required. The installer provisions the baseline tools and applies the chezmoi configuration.

Interactive runs also configure Windows Terminal and offer optional applications, including WSL.

### Linux

Debian and Arch Linux are supported:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jsilverdev/dotfiles/main/bootstrap.sh)
```

The installer provisions the baseline CLI tools and Zsh environment. Interactive runs also offer optional tools such as mise, Docker, and Dagger.

## Updates

Update dotfiles only:

```text
chezmoi update
```

Update dotfiles and installer-managed packages:

**Windows**

```text
update.cmd
```

**Linux**

```text
./update.sh
```

## CI

GitHub Actions validates bootstrap and update flows on Debian, Arch Linux, Windows, and Windows with `AllSigned`. README-only changes do not trigger the validation workflow.

## Acknowledgments

Inspired by:

- [Lissy93's dotfiles](https://github.com/Lissy93/dotfiles)
- [KEVINNITRO DOTFILES](https://github.com/KevinNitroG/dotfiles)
