$ErrorActionPreference="Stop"
$errors=@()
Get-ChildItem (Join-Path $PSScriptRoot "..\..") -Recurse -File -Include *.ps1,*.psm1 | ForEach-Object {
  $tokens=$null; $parseErrors=$null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$parseErrors)|Out-Null
  if($parseErrors.Count){$errors += "$($_.FullName): $($parseErrors -join '; ')"}
}
if($errors.Count){$errors|ForEach-Object{Write-Error $_};exit 1}
Write-Host "powershell-syntax-ok"
