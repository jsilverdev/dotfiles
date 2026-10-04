$ErrorActionPreference='Stop'
$s=$env:DOTFILES_PS_SCRIPT
$a=@()
for($i=1;$i-le[int]$env:DOTFILES_PS_ARGC;$i++){$a+=[Environment]::GetEnvironmentVariable("DOTFILES_PS_ARG$i")}
$t=$null
$f=$false
try{
 if(!(Test-Path -LiteralPath $s -PathType Leaf)){throw "PowerShell script not found: $s"}
 $pw=(Get-Command pwsh.exe -ErrorAction Stop).Source
 $h=Join-Path $env:DOTFILES_PS_BRIDGE_DIR 'signing.ps1'
 if(!(Test-Path -LiteralPath $h -PathType Leaf)){throw "Signing helper not found: $h"}
 $env:DOTFILES_SIGNING_REQUIRED='1'
 $sb=[scriptblock]::Create((Get-Content -LiteralPath $h -Raw))
 if([IO.Path]::GetFileName($s)-ieq 'signing.ps1'){
  & $sb @a
 }else{
  $t=[IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(),'.ps1')
  Copy-Item -LiteralPath $s -Destination $t -Force
  & $sb -Action ProtectFiles -Path $t
  & $pw -NoProfile -File $t @a
  if($LASTEXITCODE-ne0){$f=$true}
 }
}catch{Write-Error $_;$f=$true}
finally{
 if($t){Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue}
 Remove-Item Env:DOTFILES_SIGNING_REQUIRED -ErrorAction SilentlyContinue
}
if($f){exit 1}
