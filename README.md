# Dotfiles

Welcome to my dotfiles! This repository contains configurations and scripts to quickly set up a development environment on Windows and Linux.

## Quick Installation

### 🖥️ Windows

To set up your environment on Windows, run the following command in PowerShell:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jsilverdev/dotfiles/master/lets-go.ps1" -OutFile ".\lets-go.ps1"; Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned; .\lets-go.ps1
```

### 🐧 Linux

To set up your environment on Linux, use this command:

```bash
bash <(curl -s https://raw.githubusercontent.com/jsilverdev/dotfiles/master/lets-go.sh)
```

## Requirements

### 🖥️ Windows
- PowerShell 5.0 or newer (This script install the last version of Powershell)
- [Dev Mode](https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development) is enabled

### 🐧 Linux
- Debian / Arch Linux
- curl

## Acknowledgments

This dotfiles repository is inspired by:
- [Lissy93's dotfiles](https://github.com/Lissy93/dotfiles)
- [KEVINNITRO DOTFILES](https://github.com/KevinNitroG/dotfiles).
