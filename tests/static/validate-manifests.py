#!/usr/bin/env python3
import csv
import pathlib

root = pathlib.Path(__file__).resolve().parents[2]
with (root / "scripts/windows/managed-apps.csv").open(newline="", encoding="utf-8") as handle:
    apps = list(csv.DictReader(handle))

required_columns = {"Category", "Name", "AppId", "Alias", "Scope"}
if not apps or set(apps[0]) != required_columns:
    raise SystemExit("managed-apps.csv has an invalid schema")

ids = [row["AppId"] for row in apps]
if len(ids) != len(set(ids)):
    raise SystemExit("managed-apps.csv contains duplicate AppId values")

core = [row for row in apps if row["Category"] == "core"]
if not core or any(not row["Alias"] for row in core):
    raise SystemExit("every core WinGet app must define an Alias")
if any(row["Scope"] != "user" for row in core):
    raise SystemExit("every core WinGet app must use user scope")
if any(row["Category"] not in {"core", "workstation", "optional"} for row in apps):
    raise SystemExit("managed-apps.csv contains an unknown category")

for name in ("packages-debian.txt", "packages-arch.txt", "required-commands.txt"):
    path = root / "scripts/linux" / name
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip() and not line.lstrip().startswith("#")]
    if not lines:
        raise SystemExit(f"{name} is empty")
    if len(lines) != len(set(lines)):
        raise SystemExit(f"{name} contains duplicates")

print("manifest-validation-ok")
