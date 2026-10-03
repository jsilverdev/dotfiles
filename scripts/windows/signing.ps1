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

function Test-AllSignedPolicy {
    $locations = @(
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; Path = "Software\Policies\Microsoft\Windows\PowerShell" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; Path = "Software\Policies\Microsoft\Windows\PowerShell" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; Path = "Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; Path = "Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" }
    )
    foreach ($location in $locations) {
        $baseKey = $null
        $key = $null
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($location.Hive, [Microsoft.Win32.RegistryView]::Default)
            $key = $baseKey.OpenSubKey($location.Path)
            if ($null -ne $key) {
                $policy = $key.GetValue("ExecutionPolicy", $null)
                if (-not [string]::IsNullOrWhiteSpace($policy)) { return $policy -eq "AllSigned" }
            }
        }
        finally {
            if ($key) { $key.Dispose() }
            if ($baseKey) { $baseKey.Dispose() }
        }
    }
    return $false
}

function Test-CodeSigningCertificate {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)

    if ($null -eq $Certificate -or -not $Certificate.HasPrivateKey -or $Certificate.NotAfter -le (Get-Date)) {
        return $false
    }

    return @($Certificate.EnhancedKeyUsageList | Where-Object { $_.ObjectId.Value -eq $codeSigningOid }).Count -gt 0
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

        foreach ($storeName in @("Root", "TrustedPublisher")) {
            $storePath = "Cert:\CurrentUser\$storeName"
            $trusted = Get-ChildItem -Path $storePath | Where-Object Thumbprint -eq $certificate.Thumbprint
            if ($null -eq $trusted) {
                Import-Certificate -FilePath $publicCertificatePath -CertStoreLocation $storePath | Out-Null
            }
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

function Test-UserModulePath {
    param([string]$ModulePath)

    $fullPath = [IO.Path]::GetFullPath($ModulePath).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $userRoots = @(
        (Join-Path $HOME "Documents\PowerShell\Modules"),
        (Join-Path $HOME ".local\share\powershell\Modules")
    ) + @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ -and $_ -like "$HOME*" })

    foreach ($root in ($userRoots | Select-Object -Unique)) {
        $fullRoot = [IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar)
        if ($fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $fullPath.StartsWith($fullRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Get-ManagedModuleFiles {
    param([Parameter(Mandatory)][string]$Name)

    $moduleDirectories = @(Get-Module -ListAvailable -Name $Name |
        Where-Object { $_.ModuleBase -and (Test-UserModulePath $_.ModuleBase) } |
        Select-Object -ExpandProperty ModuleBase -Unique)

    if ($moduleDirectories.Count -eq 0) {
        throw "Managed PowerShell module '$Name' was not found in a current-user module path."
    }

    $extensions = @("*.ps1", "*.psm1", "*.psd1", "*.ps1xml", "*.cdxml", "*.xaml")
    return @($moduleDirectories | ForEach-Object {
        foreach ($extension in $extensions) {
            Get-ChildItem -LiteralPath $_ -Filter $extension -File -Recurse -ErrorAction Stop
        }
    } | Select-Object -ExpandProperty FullName -Unique)
}

if (-not (Test-AllSignedPolicy)) {
    exit 0
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
