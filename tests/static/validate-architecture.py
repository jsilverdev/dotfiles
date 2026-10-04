#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
SELF = pathlib.Path(__file__).resolve().relative_to(ROOT).as_posix()


def fail(message: str) -> None:
    raise SystemExit(message)


def tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "-z"],
        check=True,
        capture_output=True,
    )
    return [item.decode() for item in result.stdout.split(b"\0") if item]


def read_text(path: str) -> str:
    try:
        return (ROOT / path).read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return ""


if (ROOT / ".chezmoiroot").read_text(encoding="utf-8").strip() != "home":
    fail(".chezmoiroot must contain 'home'")

required_paths = (
    "home",
    "scripts/linux/packages-debian.txt",
    "scripts/linux/cleanup-broken-managed-links.sh",
    "scripts/linux/packages-arch.txt",
    "scripts/linux/required-commands.txt",
    "scripts/windows/managed-apps.csv",
    "scripts/windows/cleanup-broken-managed-links.ps1",
    "scripts/windows/managed-modules.txt",
    "scripts/windows/invoke-ps-script.cmd",
    "scripts/windows/invoke-ps-script-bridge.ps1",
    "scripts/windows/signing.ps1",
    "scripts/windows/deploy-pwsh.ps1",
    "home/.chezmoiscripts/run_after_90-deploy-pwsh.cmd.tmpl",
    "tests/windows/assert-migration.ps1",
)
for relative in required_paths:
    if not (ROOT / relative).exists():
        fail(f"required path is missing: {relative}")

paths = tracked_files()
for path in paths:
    if pathlib.PurePosixPath(path).name.startswith("symlink_"):
        fail(f"chezmoi symlink source state is not allowed: {path}")

checks = (
    (
        re.compile(r"DOTFILES_CORE_ONLY|CoreOnly|--core-only"),
        {SELF},
        "obsolete core-only mode is still referenced",
    ),
    (
        re.compile(r"dotbot", re.IGNORECASE),
        {".github/workflows/validate.yml", SELF},
        "obsolete Dotbot dependency/reference found",
    ),
    (
        re.compile(
            r"https://github\.com/jsilverdev/dotfiles\.git.*master|"
            r"raw\.githubusercontent\.com/jsilverdev/dotfiles/master"
        ),
        {SELF},
        "obsolete master bootstrap URL found",
    ),
    (
        re.compile(
            r"Set-ExecutionPolicy.*(?:Bypass|Unrestricted)|"
            r"-ExecutionPolicy\s+(?:Bypass|Unrestricted)",
            re.IGNORECASE,
        ),
        {".github/workflows/validate.yml", SELF},
        "production execution-policy weakening found",
    ),
)

for pattern, exclusions, message in checks:
    for path in paths:
        if path in exclusions:
            continue
        text = read_text(path)
        match = pattern.search(text)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            fail(f"{message}: {path}:{line}")

registry_pattern = re.compile(
    r"PowerShellCore\\ShellIds|Software\\Microsoft\\PowerShell\\1\\ShellIds",
    re.IGNORECASE,
)
for path in paths:
    if pathlib.PurePosixPath(path).suffix.lower() not in {".ps1", ".psm1", ".cmd"}:
        continue
    text = read_text(path)
    match = registry_pattern.search(text)
    if match:
        line = text.count("\n", 0, match.start()) + 1
        fail(f"implementation-specific execution-policy registry probing found: {path}:{line}")

signature_marker = "# SIG # Begin signature block"
for path in paths:
    if pathlib.PurePosixPath(path).suffix.lower() not in {".ps1", ".psm1"}:
        continue
    text = read_text(path)
    if any(line.startswith(signature_marker) for line in text.splitlines()):
        fail(f"signed PowerShell source was committed: {path}")

print("architecture-validation-ok")
