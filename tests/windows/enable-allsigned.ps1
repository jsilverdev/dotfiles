$ErrorActionPreference="Stop"
$smoke=Join-Path $env:RUNNER_TEMP "allsigned-bridge-smoke.ps1";'param([string]$Value); if($Value -ne "bridge-ok"){throw "unexpected"}'|Set-Content $smoke
$signer=Join-Path $env:RUNNER_TEMP "allsigned-signer-smoke.ps1";'param([string]$Value); if($Value -ne "signer-ok"){throw "unexpected"}'|Set-Content $signer
$subject="CN=jsilverdev Dotfiles Code Signing";$cert=Get-ChildItem Cert:\CurrentUser\My|?{$_.Subject-eq$subject-and$_.HasPrivateKey-and$_.NotAfter-gt(Get-Date)}|sort NotAfter -Descending|select -First 1
if(!$cert){$cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject $subject -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(10) -HashAlgorithm SHA256}
$cer=Join-Path $env:RUNNER_TEMP "dotfiles-signing.cer";$thumb=Join-Path $env:RUNNER_TEMP "dotfiles-cert-thumbprint.txt";Set-Content $thumb $cert.Thumbprint -NoNewline;Export-Certificate -Cert $cert -FilePath $cer -Type CERT -Force|Out-Null
foreach($store in @("Cert:\LocalMachine\Root","Cert:\CurrentUser\TrustedPublisher")){if(!(Get-ChildItem $store|? Thumbprint -eq $cert.Thumbprint|select -First 1)){Import-Certificate -FilePath $cer -CertStoreLocation $store -Confirm:$false|Out-Null}}
Set-AuthenticodeSignature $smoke $cert -HashAlgorithm SHA256|Out-Null
if((Get-AuthenticodeSignature $smoke).Status-ne"Valid"){throw "signature invalid"}
Set-ExecutionPolicy -Scope CurrentUser AllSigned -Force
if((Get-ExecutionPolicy)-ne"AllSigned"){throw "AllSigned not effective"}
