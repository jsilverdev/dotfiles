$ErrorActionPreference = "Stop"

$smoke = Join-Path $env:RUNNER_TEMP "allsigned-bridge-smoke.ps1"
@'
param([string]$Value)
if ($Value -ne "bridge-ok") { throw "unexpected bridge value: $Value" }
'@ | Set-Content -LiteralPath $smoke

$subject = "CN=jsilverdev Dotfiles Code Signing"
$certificate = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -eq $subject -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if ($null -eq $certificate) {
    $certificate = New-SelfSignedCertificate -Type CodeSigningCert -Subject $subject -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(10) -HashAlgorithm SHA256
}

$certificatePath = Join-Path $env:RUNNER_TEMP "dotfiles-signing.cer"
$thumbprintPath = Join-Path $env:RUNNER_TEMP "dotfiles-cert-thumbprint.txt"
Set-Content -LiteralPath $thumbprintPath -Value $certificate.Thumbprint -NoNewline
Export-Certificate -Cert $certificate -FilePath $certificatePath -Type CERT -Force | Out-Null

foreach ($store in @("Cert:\LocalMachine\Root", "Cert:\CurrentUser\TrustedPublisher")) {
    if (-not (Get-ChildItem $store | Where-Object Thumbprint -eq $certificate.Thumbprint | Select-Object -First 1)) {
        Import-Certificate -FilePath $certificatePath -CertStoreLocation $store -Confirm:$false | Out-Null
    }
}

Set-AuthenticodeSignature -FilePath $smoke -Certificate $certificate -HashAlgorithm SHA256 | Out-Null
if ((Get-AuthenticodeSignature -FilePath $smoke).Status -ne "Valid") { throw "The AllSigned smoke script signature is invalid." }

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy AllSigned -Force
if ((Get-ExecutionPolicy) -ne "AllSigned") { throw "AllSigned is not the effective execution policy." }
