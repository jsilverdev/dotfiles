[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ThumbprintFile,
    [string]$UpdateMarker
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) { throw "ASSERTION FAILED: $Message" }

if ((Get-ExecutionPolicy) -ne "AllSigned") { Fail "effective execution policy is not AllSigned" }
Write-Host "Execution policy: $(Get-ExecutionPolicy)"
Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-Host

$certificateSubject = "CN=jsilverdev Dotfiles Code Signing"
$codeSigningOid = "1.3.6.1.5.5.7.3.3"
$certificate = @(Get-ChildItem Cert:\CurrentUser\My | Where-Object {
    $_.Subject -eq $certificateSubject -and
    $_.HasPrivateKey -and
    $_.NotAfter -gt (Get-Date) -and
    @($_.EnhancedKeyUsageList | Where-Object ObjectId -eq $codeSigningOid).Count -gt 0
} | Sort-Object NotAfter -Descending | Select-Object -First 1)
if ($certificate.Count -ne 1) { Fail "usable dotfiles Code Signing certificate was not found in CurrentUser\\My" }

foreach ($storeName in @("My", "Root", "TrustedPublisher")) {
    $trusted = @(Get-ChildItem "Cert:\CurrentUser\$storeName" | Where-Object Thumbprint -eq $certificate[0].Thumbprint)
    if ($trusted.Count -ne 1) { Fail "certificate $($certificate[0].Thumbprint) is missing from CurrentUser\\$storeName" }
}
Write-Host "Certificate: $($certificate[0].Subject) thumbprint=$($certificate[0].Thumbprint) expires=$($certificate[0].NotAfter)"

if (Test-Path -LiteralPath $ThumbprintFile) {
    $previous = (Get-Content -LiteralPath $ThumbprintFile -Raw).Trim()
    if ($previous -ne $certificate[0].Thumbprint) { Fail "signing certificate changed from $previous to $($certificate[0].Thumbprint)" }
}
Set-Content -LiteralPath $ThumbprintFile -Value $certificate[0].Thumbprint -NoNewline

function Invoke-Chezmoi([string[]]$Arguments) {
    $output = @(& chezmoi.exe @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "chezmoi $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)" }
    return $output
}

function Assert-CleanChezMoi {
    $status = @(Invoke-Chezmoi @("status"))
    if ($status.Count -ne 0) { Fail "chezmoi status is not clean: $($status -join [Environment]::NewLine)" }
}

$sourcePath = ((Invoke-Chezmoi @("source-path")) -join "").Trim()
Write-Host "chezmoi source-path: $sourcePath"
Invoke-Chezmoi @("apply") | Out-Host
Invoke-Chezmoi @("apply") | Out-Host
Assert-CleanChezMoi

$runtimeFiles = @(
    (Join-Path $HOME ".config\pwsh\env.ps1"),
    (Join-Path $HOME ".config\pwsh\lib\helpers.ps1"),
    (Join-Path $HOME ".config\pwsh\lib\aliases.ps1"),
    $PROFILE.CurrentUserAllHosts
)
foreach ($path in $runtimeFiles) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "runtime PowerShell file is missing: $path" }
    $signature = Get-AuthenticodeSignature -FilePath $path
    Write-Host "${path}: $($signature.Status) signer=$($signature.SignerCertificate.Thumbprint)"
    if ($signature.Status -ne "Valid") { Fail "runtime PowerShell signature is not Valid: $path ($($signature.Status))" }
    if ($signature.SignerCertificate.Thumbprint -ne $certificate[0].Thumbprint) { Fail "runtime PowerShell file has an unexpected signer: $path" }
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
    $moduleFiles = @(Get-ChildItem -LiteralPath $module[0].ModuleBase -File -Recurse | Where-Object Extension -in @(".ps1", ".psm1", ".psd1", ".ps1xml", ".cdxml", ".xaml"))
    foreach ($file in $moduleFiles) {
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName
        if ($signature.Status -ne "Valid") { Fail "managed module file is not Validly signed: $($file.FullName) ($($signature.Status))" }
    }
}

if ($UpdateMarker) {
    if (-not ((Get-Content (Join-Path $HOME ".fdignore") -Raw) -match [regex]::Escape($UpdateMarker))) { Fail "update marker did not reach .fdignore" }
}

$sourceStatus = @(git -C $sourcePath status --porcelain)
if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) { Fail "chezmoi source Git tree is dirty: $($sourceStatus -join [Environment]::NewLine)" }
$repoStatus = @(git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $repoStatus.Count -ne 0) { Fail "Actions checkout Git tree is dirty: $($repoStatus -join [Environment]::NewLine)" }
$signatureMatches = @(git -C $RepoRoot grep -n "^# SIG # Begin signature block" -- "*.ps1")
if ($LASTEXITCODE -eq 0 -or $signatureMatches.Count -ne 0) { Fail "repository PowerShell source contains an Authenticode signature block" }

$profileOutput = @(& pwsh.exe -Command "Write-Output 'profile-ok'" 2>&1)
if ($LASTEXITCODE -ne 0 -or -not ($profileOutput -contains "profile-ok")) { Fail "PowerShell profile startup failed: $($profileOutput -join [Environment]::NewLine)" }

Write-Host "AllSigned assertions passed with certificate $($certificate[0].Thumbprint)."
