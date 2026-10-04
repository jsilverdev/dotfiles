[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ThumbprintFile,
    [string]$UpdateMarker
)

$ErrorActionPreference = "Stop"
$certificateSubject = "CN=jsilverdev Dotfiles Code Signing"
$codeSigningOid = "1.3.6.1.5.5.7.3.3"
$enhancedKeyUsageOid = "2.5.29.37"

function Fail([string]$Message) { throw "ASSERTION FAILED: $Message" }

function Test-CodeSigningCertificate {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)

    if ($null -eq $Certificate -or -not $Certificate.HasPrivateKey -or $Certificate.NotAfter -le (Get-Date)) {
        return $false
    }

    $ekuExtension = $Certificate.Extensions |
        Where-Object { $_.Oid.Value -eq $enhancedKeyUsageOid } |
        Select-Object -First 1
    if ($null -eq $ekuExtension) { return $false }

    try {
        $eku = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension
        $eku.CopyFrom($ekuExtension)
    }
    catch {
        return $false
    }

    return @($eku.EnhancedKeyUsages | Where-Object { $_.Value -eq $codeSigningOid }).Count -gt 0
}

function Get-StoreCertificates {
    param(
        [Parameter(Mandatory)][string]$StoreName,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation
    )

    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $StoreLocation)
    try {
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        return @($store.Certificates)
    }
    finally {
        $store.Close()
    }
}

function Test-CertificateInStore {
    param(
        [Parameter(Mandatory)][string]$StoreName,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation,
        [Parameter(Mandatory)][string]$Thumbprint
    )

    return @(Get-StoreCertificates -StoreName $StoreName -StoreLocation $StoreLocation |
        Where-Object Thumbprint -eq $Thumbprint).Count -gt 0
}

function Assert-AuthenticodeFiles {
    param(
        [Parameter(Mandatory)][string[]]$FilePath,
        [Parameter(Mandatory)][string]$ExpectedThumbprint
    )

    if ($FilePath.Count -eq 0) { return }

    $windowsPowerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
        Fail "Windows PowerShell is unavailable for Authenticode verification."
    }

    $manifest = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".json")
    $originalPSModulePath = $env:PSModulePath
    try {
        @($FilePath) | ConvertTo-Json -Compress | Set-Content -LiteralPath $manifest -Encoding UTF8
        $env:DOTFILES_SIGNATURE_MANIFEST = $manifest
        $env:DOTFILES_EXPECTED_THUMBPRINT = $ExpectedThumbprint
        $env:PSModulePath = @(
            (Join-Path $HOME "Documents\WindowsPowerShell\Modules")
            (Join-Path $env:ProgramFiles "WindowsPowerShell\Modules")
            (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\Modules")
        ) -join [IO.Path]::PathSeparator

        $command = @'
$ErrorActionPreference = 'Stop'
$paths = @(Get-Content -LiteralPath $env:DOTFILES_SIGNATURE_MANIFEST -Raw | ConvertFrom-Json)
foreach ($path in $paths) {
    $signature = Get-AuthenticodeSignature -LiteralPath $path
    if ($signature.Status -ne 'Valid') {
        throw "invalid Authenticode signature: $path ($($signature.Status))"
    }
    if ($null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $env:DOTFILES_EXPECTED_THUMBPRINT) {
        throw "unexpected Authenticode signer: $path"
    }
    Write-Output "Valid signature: $path"
}
'@
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

        & $windowsPowerShell -NoProfile -NonInteractive -EncodedCommand $encodedCommand
        if ($LASTEXITCODE -ne 0) {
            Fail "Windows PowerShell Authenticode verification failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        $env:PSModulePath = $originalPSModulePath
        Remove-Item Env:DOTFILES_SIGNATURE_MANIFEST -ErrorAction SilentlyContinue
        Remove-Item Env:DOTFILES_EXPECTED_THUMBPRINT -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $manifest -Force -ErrorAction SilentlyContinue
    }
}

# The bridge sets this variable only on the signed execution path. The assertion
# avoids autoloading Microsoft.PowerShell.Security inside pwsh under AllSigned.
if ($env:DOTFILES_SIGNING_REQUIRED -ne "1") {
    Fail "assert-allsigned.ps1 was not executed through the AllSigned signing path"
}
Write-Host "AllSigned bridge path confirmed."

$currentUser = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
$localMachine = [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
$certificate = @(Get-StoreCertificates -StoreName "My" -StoreLocation $currentUser | Where-Object {
    $_.Subject -eq $certificateSubject -and (Test-CodeSigningCertificate $_)
} | Sort-Object NotAfter -Descending | Select-Object -First 1)
if ($certificate.Count -ne 1) { Fail "usable dotfiles Code Signing certificate was not found in CurrentUser\\My" }

$thumbprint = $certificate[0].Thumbprint
if (-not (Test-CertificateInStore -StoreName "TrustedPublisher" -StoreLocation $currentUser -Thumbprint $thumbprint)) {
    Fail "certificate $thumbprint is missing from CurrentUser\\TrustedPublisher"
}
$trustedRoot =
    (Test-CertificateInStore -StoreName "Root" -StoreLocation $currentUser -Thumbprint $thumbprint) -or
    (Test-CertificateInStore -StoreName "Root" -StoreLocation $localMachine -Thumbprint $thumbprint)
if (-not $trustedRoot) { Fail "certificate $thumbprint is missing from both CurrentUser\\Root and LocalMachine\\Root" }
Write-Host "Certificate: $($certificate[0].Subject) thumbprint=$thumbprint expires=$($certificate[0].NotAfter)"

if (Test-Path -LiteralPath $ThumbprintFile) {
    $previous = (Get-Content -LiteralPath $ThumbprintFile -Raw).Trim()
    if ($previous -ne $thumbprint) { Fail "signing certificate changed from $previous to $thumbprint" }
}
Set-Content -LiteralPath $ThumbprintFile -Value $thumbprint -NoNewline

function Invoke-NativeProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            Fail "failed to start native process: $FilePath"
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    }
    finally {
        $process.Dispose()
    }
}

function Invoke-Chezmoi([string[]]$Arguments) {
    $chezmoi = (Get-Command chezmoi.exe -ErrorAction Stop).Source
    $result = Invoke-NativeProcess -FilePath $chezmoi -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        Fail "chezmoi $($Arguments -join ' ') failed with exit code $($result.ExitCode): $($result.StdErr.Trim())"
    }

    if ([string]::IsNullOrWhiteSpace($result.StdOut)) {
        return @()
    }

    return @($result.StdOut -split "\r?\n" | Where-Object { $_ -ne "" })
}

function Assert-CleanChezMoi {
    $status = @(Invoke-Chezmoi @("status", "--exclude=scripts"))
    $pending = @($status | Where-Object {
        $line = [string]$_
        $line.Length -ge 2 -and $line[1] -ne ' '
    })
    if ($pending.Count -ne 0) { Fail "chezmoi has pending target changes: $($pending -join [Environment]::NewLine)" }
}

$sourcePath = ((Invoke-Chezmoi @("source-path")) -join "").Trim()
Write-Host "chezmoi source-path: $sourcePath"
$managedAppsPath = Join-Path $RepoRoot "scripts\windows\managed-apps.csv"
$coreApps = @(Import-Csv -LiteralPath $managedAppsPath | Where-Object Category -eq "core")
foreach ($app in $coreApps) {
    if ([string]::IsNullOrWhiteSpace($app.Alias)) { continue }
    if (-not (Get-Command -Name $app.Alias -ErrorAction SilentlyContinue)) {
        Fail "baseline CLI tool is unavailable: $($app.Alias)"
    }
}
& mise which starship *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "starship is not managed by mise"
}
Invoke-Chezmoi @("apply") | Out-Host
Invoke-Chezmoi @("apply") | Out-Host
Assert-CleanChezMoi

$signatureFiles = [System.Collections.Generic.List[string]]::new()
$runtimeFiles = @(
    (Join-Path $HOME ".config\pwsh\env.ps1"),
    (Join-Path $HOME ".config\pwsh\lib\helpers.ps1"),
    (Join-Path $HOME ".config\pwsh\lib\aliases.ps1"),
    $PROFILE.CurrentUserAllHosts
)
foreach ($path in $runtimeFiles) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "runtime PowerShell file is missing: $path" }
    $signatureFiles.Add($path)
}

foreach ($moduleName in @(Get-Content -LiteralPath (Join-Path $RepoRoot "scripts\windows\managed-modules.txt") | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })) {
    if ($moduleName -eq "git-aliases") {
        Import-Module $moduleName -Force -DisableNameChecking -ErrorAction Stop
    }
    else {
        Import-Module $moduleName -Force -ErrorAction Stop
    }

    $module = @(Get-Module -ListAvailable -Name $moduleName | Where-Object {
        $_.ModuleBase -like "$(Join-Path $HOME 'Documents\PowerShell\Modules')*" -or
        $_.ModuleBase -like "$(Join-Path $HOME '.local\share\powershell\Modules')*"
    } | Select-Object -First 1)
    if ($module.Count -ne 1) { Fail "managed module is not in a current-user module path: $moduleName" }

    $moduleFiles = @(Get-ChildItem -LiteralPath $module[0].ModuleBase -File -Recurse |
        Where-Object Extension -in @(".ps1", ".psm1", ".psd1", ".ps1xml", ".cdxml", ".xaml"))
    foreach ($file in $moduleFiles) {
        $signatureFiles.Add($file.FullName)
    }
}

Assert-AuthenticodeFiles -FilePath @($signatureFiles) -ExpectedThumbprint $thumbprint

if ($UpdateMarker) {
    if (-not ((Get-Content (Join-Path $HOME ".fdignore") -Raw) -match [regex]::Escape($UpdateMarker))) { Fail "update marker did not reach .fdignore" }
}

$sourceStatus = @(git -C $sourcePath status --porcelain)
if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) { Fail "chezmoi source Git tree is dirty: $($sourceStatus -join [Environment]::NewLine)" }
$repoStatus = @(git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $repoStatus.Count -ne 0) { Fail "Actions checkout Git tree is dirty: $($repoStatus -join [Environment]::NewLine)" }
$signatureMatches = @(git -C $RepoRoot grep -n "^# SIG # Begin signature block" -- "*.ps1")
if ($LASTEXITCODE -eq 0 -or $signatureMatches.Count -ne 0) { Fail "repository PowerShell source contains an Authenticode signature block" }

$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$profileResult = Invoke-NativeProcess -FilePath $pwsh -Arguments @("-Command", "Write-Output 'profile-ok'")
$profileOutput = @($profileResult.StdOut -split "\r?\n" | Where-Object { $_ -ne "" })
if ($profileResult.ExitCode -ne 0 -or -not ($profileOutput -contains "profile-ok")) {
    Fail "PowerShell profile startup failed with exit code $($profileResult.ExitCode): $($profileResult.StdErr.Trim())"
}

Write-Host "AllSigned assertions passed with certificate $thumbprint."
