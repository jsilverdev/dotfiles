$ErrorActionPreference='Stop'
$scriptPath=$env:DOTFILES_PS_SCRIPT
$scriptArgs=@()
for($i=1;$i -le [int]$env:DOTFILES_PS_ARGC;$i++){
    $scriptArgs += [Environment]::GetEnvironmentVariable("DOTFILES_PS_ARG$i")
}
$temp=$null
$cer=$null
$failed=$false
try {
    if(-not(Test-Path -LiteralPath $scriptPath -PathType Leaf)){throw "PowerShell script not found: $scriptPath"}
    if((Get-ExecutionPolicy)-eq 'AllSigned'){
        $subject='CN=jsilverdev Dotfiles Code Signing'
        $oid='1.3.6.1.5.5.7.3.3'
        $cert=Get-ChildItem Cert:\CurrentUser\My |
            Where-Object {$_.Subject -eq $subject -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) -and @($_.EnhancedKeyUsageList | Where-Object {$_.ObjectId.Value -eq $oid}).Count -gt 0} |
            Sort-Object NotAfter -Descending |
            Select-Object -First 1
        if($null -eq $cert){
            $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject $subject -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(10) -HashAlgorithm SHA256
        }
        $cer=[IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(),'.cer')
        Export-Certificate -Cert $cert -FilePath $cer -Type CERT -Force | Out-Null
        $thumb=$cert.Thumbprint
        if(-not(Get-ChildItem -Path Cert:\CurrentUser\Root,Cert:\LocalMachine\Root | Where-Object Thumbprint -eq $thumb)){
            & certutil.exe -user -f -addstore Root $cer | Out-Null
            if($LASTEXITCODE){throw 'certutil failed for Root'}
        }
        if(-not(Get-ChildItem Cert:\CurrentUser\TrustedPublisher | Where-Object Thumbprint -eq $thumb)){
            & certutil.exe -user -f -addstore TrustedPublisher $cer | Out-Null
            if($LASTEXITCODE){throw 'certutil failed for TrustedPublisher'}
        }
        $temp=[IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(),'.ps1')
        Copy-Item -LiteralPath $scriptPath -Destination $temp -Force
        Set-AuthenticodeSignature -FilePath $temp -Certificate $cert -HashAlgorithm SHA256 | Out-Null
        $sig=Get-AuthenticodeSignature -FilePath $temp
        if($sig.Status -ne 'Valid'){throw "Temporary script signature is not Valid: $($sig.Status)"}
        $scriptPath=$temp
    }
    $pwsh=(Get-Command pwsh.exe -ErrorAction Stop).Source
    & $pwsh -NoProfile -File $scriptPath @scriptArgs
    if($LASTEXITCODE -ne 0){$failed=$true}
}
catch {
    Write-Error $_
    $failed=$true
}
finally {
    if($temp){Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
    if($cer){Remove-Item -LiteralPath $cer -Force -ErrorAction SilentlyContinue}
}
if($failed){exit 1}
