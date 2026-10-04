[CmdletBinding()]
param(
    [ValidateSet("ProtectFiles", "ProtectModule")]
    [string]$Action = "ProtectFiles",

    [string[]]$Path,

    [string]$ModuleName
)

$ErrorActionPreference = "Stop"
$certificateSubject = "CN=jsilverdev Dotfiles Code Signing"
$codeSigningOid = "1.3.6.1.5.5.7.3.3"
$enhancedKeyUsageOid = "2.5.29.37"

function Test-CodeSigningCertificate {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)

    if ($null -eq $Certificate -or -not $Certificate.HasPrivateKey -or $Certificate.NotAfter -le (Get-Date)) {
        return $false
    }

    # Read the X.509 EKU extension directly instead of relying on the
    # PowerShell certificate provider's EnhancedKeyUsageList projection.
    # This behaves consistently in PowerShell 7 and Windows PowerShell 5.1.
    $ekuExtension = $Certificate.Extensions |
        Where-Object { $_.Oid.Value -eq $enhancedKeyUsageOid } |
        Select-Object -First 1
    if ($null -eq $ekuExtension) {
        return $false
    }

    try {
        $eku = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension
        $eku.CopyFrom($ekuExtension)
    }
    catch {
        return $false
    }

    return @($eku.EnhancedKeyUsages | Where-Object { $_.Value -eq $codeSigningOid }).Count -gt 0
}

function Get-DotfilesSigningCertificate {
    $certificate = Get-ChildItem -Path Cert:\CurrentUser\My |
        Where-Object { $_.Subject -eq $certificateSubject -and (Test-CodeSigningCertificate $_) } |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1

    if ($null -eq $certificate) {
        try {
            $certificate = New-SelfSignedCertificate `
                -Type CodeSigningCert `
                -Subject $certificateSubject `
                -CertStoreLocation Cert:\CurrentUser\My `
                -NotAfter (Get-Date).AddYears(10) `
                -HashAlgorithm SHA256
        }
        catch {
            throw "Unable to create the current-user code-signing certificate. Corporate certificate-store policy may prevent this operation. $($_.Exception.Message)"
        }
    }

    if (-not (Test-CodeSigningCertificate $certificate)) {
        throw "The managed dotfiles certificate is missing a private key, is expired, or lacks the Code Signing EKU."
    }

    $publicCertificatePath = $null
    try {
        $publicCertificatePath = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".cer")
        Export-Certificate -Cert $certificate -FilePath $publicCertificatePath -Type CERT -Force | Out-Null

        $trustedRoot = @(
            Get-ChildItem -Path Cert:\CurrentUser\Root | Where-Object Thumbprint -eq $certificate.Thumbprint
            Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object Thumbprint -eq $certificate.Thumbprint
        )
        if ($trustedRoot.Count -eq 0) {
            & certutil.exe -user -f -addstore Root $publicCertificatePath | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "certutil could not trust CurrentUser\\Root." }
        }

        $trustedPublisher = Get-ChildItem -Path Cert:\CurrentUser\TrustedPublisher |
            Where-Object Thumbprint -eq $certificate.Thumbprint
        if ($null -eq $trustedPublisher) {
            & certutil.exe -user -f -addstore TrustedPublisher $publicCertificatePath | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "certutil could not trust CurrentUser\\TrustedPublisher." }
        }
    }
    catch {
        throw "Unable to trust the current-user dotfiles certificate in Root and TrustedPublisher. Corporate certificate-store policy may prevent this operation. $($_.Exception.Message)"
    }
    finally {
        if ($publicCertificatePath) {
            Remove-Item -LiteralPath $publicCertificatePath -Force -ErrorAction SilentlyContinue
        }
    }

    return $certificate
}

function Protect-PowerShellFile {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "PowerShell file not found: $FilePath"
    }

    $signature = Get-AuthenticodeSignature -FilePath $FilePath
    if ($signature.Status -eq "Valid") {
        return
    }

    Set-AuthenticodeSignature -FilePath $FilePath -Certificate $Certificate -HashAlgorithm SHA256 | Out-Null
    $signature = Get-AuthenticodeSignature -FilePath $FilePath
    if ($signature.Status -ne "Valid") {
        throw "Authenticode signature verification failed for ${FilePath}: $($signature.Status) $($signature.StatusMessage)"
    }
}

function Get-ManagedModuleFiles {
    param([Parameter(Mandatory)][string]$Name)

    $userRoots = @(
        (Join-Path $HOME "Documents\PowerShell\Modules"),
        (Join-Path $HOME ".local\share\powershell\Modules")
    )
    $moduleDirectories = @($userRoots | ForEach-Object {
        $candidate = Join-Path $_ $Name
        if (Test-Path -LiteralPath $candidate -PathType Container) { $candidate }
    } | Select-Object -Unique)

    if ($moduleDirectories.Count -eq 0) {
        throw "Managed PowerShell module '$Name' was not found in a current-user PowerShell module root."
    }

    $extensions = @("*.ps1", "*.psm1", "*.psd1", "*.ps1xml", "*.cdxml", "*.xaml")
    return @($moduleDirectories | ForEach-Object {
        foreach ($extension in $extensions) {
            Get-ChildItem -LiteralPath $_ -Filter $extension -File -Recurse -ErrorAction Stop
        }
    } | Select-Object -ExpandProperty FullName -Unique)
}

# The bridge sets DOTFILES_SIGNING_REQUIRED after PowerShell 7 proves that
# unsigned scripts are blocked. Direct/manual calls still use the effective policy.
if ($env:DOTFILES_SIGNING_REQUIRED -ne "1" -and (Get-ExecutionPolicy) -ne "AllSigned") {
    return
}

$certificate = Get-DotfilesSigningCertificate

switch ($Action) {
    "ProtectFiles" {
        if ($null -eq $Path -or $Path.Count -eq 0) {
            throw "ProtectFiles requires at least one -Path."
        }
        foreach ($file in $Path) {
            Protect-PowerShellFile -FilePath $file -Certificate $certificate
        }
    }
    "ProtectModule" {
        if ([string]::IsNullOrWhiteSpace($ModuleName)) {
            throw "ProtectModule requires -ModuleName."
        }
        foreach ($file in (Get-ManagedModuleFiles -Name $ModuleName)) {
            Protect-PowerShellFile -FilePath $file -Certificate $certificate
        }
    }
}
