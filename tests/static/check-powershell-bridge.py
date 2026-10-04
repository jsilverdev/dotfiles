#!/usr/bin/env python3
import base64,pathlib,re
root=pathlib.Path(__file__).resolve().parents[2]
cmd=(root/"scripts/windows/invoke-ps-script.cmd").read_text()
src=(root/"scripts/windows/invoke-ps-script-bridge.ps1").read_text()
m=re.search(r'(?m)^"%SystemRoot%\\System32\\WindowsPowerShell\\v1\.0\\powershell\.exe" -NoProfile -EncodedCommand ([A-Za-z0-9+/=]+)\s*$',cmd)
if not m: raise SystemExit("encoded bridge payload is missing")
if base64.b64decode(m.group(1)).decode("utf-16le")!=src: raise SystemExit("encoded bridge payload does not match source")
if len(m.group(1))>=8000: raise SystemExit("encoded bridge payload is too close to cmd.exe limits")
print(f"bridge-source-ok: encoded length={len(m.group(1))}")
