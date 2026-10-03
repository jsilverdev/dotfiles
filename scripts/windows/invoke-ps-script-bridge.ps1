$ErrorActionPreference = 'Stop'
$scriptPath = $env:DOTFILES_PS_SCRIPT
$argumentCount = [int]$env:DOTFILES_PS_ARGC
$scriptArgs = @()
for ($i = 1; $i -le $argumentCount; $i++) {
    $scriptArgs += [Environment]::GetEnvironmentVariable("DOTFILES_PS_ARG$i")
}

$temporaryScript = $null
$publicCertificate = $null
$failed = $false

try {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "PowerShell script not found: $scriptPath"
    }

    if ((Get-ExecutionPolicy) -eq 'AllSigned') {
        $subject = 'CN=jsilverdev Dotfiles Code Signing'
        $codeSigningOid = '1.3.6.1.5.5.7.3.3'
        $certificate = Get-ChildItem Cert:\CurrentUser\My |
            Where-Object {
                $_.Subject -eq $subject -and
                $_.HasPrivateKey -and
                $_.NotAfter -gt (Get-Date) -and
                @($_.EnhancedKeyUsageList | Where-Object { $_.ObjectId.Value -eq $codeSigningOid }).Count -gt 0
            } |
            Sort-Object NotAfter -Descending |
            Select-Object -First 1

        if ($null -eq $certificate) {
            $certificate = New-SelfSignedCertificate `
                -Type CodeSigningCert `
                -Subject $subject `
                -CertStoreLocation Cert:\CurrentUser\My `
                -NotAfter (Get-Date).AddYears(10) `
                -HashAlgorithm SHA256
        }

        $publicCertificate = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), '.cer')
        Export-Certificate -Cert $certificate -FilePath $publicCertificate -Type CERT -Force | Out-Null
        foreach ($storeName in @('Root', 'TrustedPublisher')) {
            if (-not (Get-ChildItem "Cert:\CurrentUser\$storeName" | Where-Object Thumbprint -eq $certificate.Thumbprint)) {
                Import-Certificate -FilePath $publicCertificate -CertStoreLocation "Cert:\CurrentUser\$storeName" | Out-Null
            }
        }

        $temporaryScript = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), '.ps1')
        Copy-Item -LiteralPath $scriptPath -Destination $temporaryScript -Force
        Set-AuthenticodeSignature -FilePath $temporaryScript -Certificate $certificate -HashAlgorithm SHA256 | Out-Null
        $signature = Get-AuthenticodeSignature -FilePath $temporaryScript
        if ($signature.Status -ne 'Valid') {
            throw "Temporary script signature is not Valid: $($signature.Status)"
        }
        $scriptPath = $temporaryScript
    }

    # Launch a child pwsh process so tokens such as -RepoRoot and -Action
    # are parsed as named script parameters. Array splatting directly into a
    # PowerShell script treats these values positionally.
    $pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
    & $pwsh -NoProfile -File $scriptPath @scriptArgs
    if ($LASTEXITCODE -ne 0) {
        $failed = $true
    }
}
catch {
    Write-Error $_
    $failed = $true
}
finally {
    if ($temporaryScript) {
        Remove-Item -LiteralPath $temporaryScript -Force -ErrorAction SilentlyContinue
    }
    if ($publicCertificate) {
        Remove-Item -LiteralPath $publicCertificate -Force -ErrorAction SilentlyContinue
    }
}

if ($failed) { exit 1 }
