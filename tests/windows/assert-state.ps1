[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [string]$ExpectedCommit,
    [string]$UpdateMarker
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) { throw "ASSERTION FAILED: $Message" }

Write-Host "Windows: $([Environment]::OSVersion.Version)"
Write-Host "User: $env:USERNAME"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "Execution policy: $(Get-ExecutionPolicy)"
Write-Host "Execution policies:"
Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-Host

if ((Get-ExecutionPolicy) -eq "AllSigned") { Fail "normal-policy test unexpectedly has AllSigned effective" }

function Invoke-Chezmoi([string[]]$Arguments) {
    $output = @(& chezmoi.exe @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "chezmoi $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)" }
    return $output
}

function Assert-CleanChezMoi {
    # Always-run scripts appear as "R" and create-only files may legitimately
    # differ in the first status column. Only the second column means apply
    # still has work to do.
    $status = @(Invoke-Chezmoi @("status", "--exclude=scripts"))
    $pending = @($status | Where-Object {
        $line = [string]$_
        $line.Length -ge 2 -and $line[1] -ne ' '
    })
    if ($pending.Count -ne 0) { Fail "chezmoi has pending target changes: $($pending -join [Environment]::NewLine)" }
}

Write-Host "chezmoi: $((chezmoi.exe --version) -join ' ')"
$sourcePath = ((Invoke-Chezmoi @("source-path")) -join "").Trim()
Write-Host "chezmoi source-path: $sourcePath"
if (-not (Test-Path -LiteralPath $sourcePath)) { Fail "chezmoi source path does not exist: $sourcePath" }

$requiredFiles = @(
    (Join-Path $HOME ".gitconfig"),
    (Join-Path $HOME ".gitconfig.local"),
    (Join-Path $HOME ".fdignore"),
    (Join-Path $HOME ".wslconfig"),
    (Join-Path $HOME ".config\starship\config.toml"),
    (Join-Path $HOME ".codex\AGENTS.md"),
    (Join-Path $HOME ".codex\skills\mule-munit\SKILL.md"),
    (Join-Path $HOME ".codex\skills\mule-munit\agents\openai.yaml"),
    (Join-Path $HOME ".config\pwsh\env.ps1"),
    (Join-Path $HOME ".config\pwsh\lib\helpers.ps1"),
    (Join-Path $HOME ".config\pwsh\lib\aliases.ps1"),
    $PROFILE.CurrentUserAllHosts
)
foreach ($path in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "expected deployed file is missing: $path" }
}

if ($ExpectedCommit) {
    $sourceCommit = ((git -C $sourcePath rev-parse HEAD) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or $sourceCommit -ne $ExpectedCommit) { Fail "source commit $sourceCommit is not expected commit $ExpectedCommit" }
}

$managedAppsPath = Join-Path $RepoRoot "scripts\windows\managed-apps.csv"
$coreApps = @(Import-Csv -LiteralPath $managedAppsPath | Where-Object Category -eq "core")
foreach ($app in $coreApps) {
    if ([string]::IsNullOrWhiteSpace($app.Alias)) { continue }
    if (-not (Get-Command -Name $app.Alias -ErrorAction SilentlyContinue)) {
        Fail "baseline CLI tool is unavailable: $($app.Alias)"
    }
}
if (-not (Get-Command -Name starship -ErrorAction SilentlyContinue)) {
    Fail "starship is unavailable"
}

Invoke-Chezmoi @("apply") | Out-Host
Invoke-Chezmoi @("apply") | Out-Host
Assert-CleanChezMoi

$configMarker = "ci-create-only-$([Guid]::NewGuid().ToString('N'))"
$rulesMarker = "ci-create-only-rule-$([Guid]::NewGuid().ToString('N'))"
Add-Content -LiteralPath (Join-Path $HOME ".codex\config.toml") -Value $configMarker
Add-Content -LiteralPath (Join-Path $HOME ".codex\rules\default.rules") -Value $rulesMarker
Invoke-Chezmoi @("apply") | Out-Host
if (-not ((Get-Content (Join-Path $HOME ".codex\config.toml") -Raw) -match [regex]::Escape($configMarker))) { Fail "chezmoi overwrote create-only config.toml" }
if (-not ((Get-Content (Join-Path $HOME ".codex\rules\default.rules") -Raw) -match [regex]::Escape($rulesMarker))) { Fail "chezmoi overwrote create-only default.rules" }
Assert-CleanChezMoi

if ($UpdateMarker) {
    if (-not ((Get-Content (Join-Path $HOME ".fdignore") -Raw) -match [regex]::Escape($UpdateMarker))) { Fail "update marker did not reach .fdignore" }
}

foreach ($module in @(Get-Content -LiteralPath (Join-Path $RepoRoot "scripts\windows\managed-modules.txt") | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })) {
    if ($module -eq "git-aliases") {
        Import-Module $module -Force -DisableNameChecking -ErrorAction Stop
    }
    else {
        Import-Module $module -Force -ErrorAction Stop
    }
}

$certificateSubject = "CN=jsilverdev Dotfiles Code Signing"
$certificate = @(Get-ChildItem Cert:\CurrentUser\My | Where-Object Subject -eq $certificateSubject)
if ($certificate.Count -ne 0) { Fail "normal-policy run unexpectedly created a dotfiles signing certificate" }

$sourceStatus = @(git -C $sourcePath status --porcelain)
if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) { Fail "chezmoi source Git tree is dirty: $($sourceStatus -join [Environment]::NewLine)" }
$repoStatus = @(git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $repoStatus.Count -ne 0) { Fail "Actions checkout Git tree is dirty: $($repoStatus -join [Environment]::NewLine)" }
$signatureMatches = @(git -C $RepoRoot grep -n "^# SIG # Begin signature block" -- "*.ps1")
if ($LASTEXITCODE -eq 0 -or $signatureMatches.Count -ne 0) { Fail "repository PowerShell source contains an Authenticode signature block" }

$profileOutput = @(& pwsh.exe -Command "Write-Output 'profile-ok'" 2>&1)
if ($LASTEXITCODE -ne 0 -or -not ($profileOutput -contains "profile-ok")) { Fail "PowerShell profile startup failed: $($profileOutput -join [Environment]::NewLine)" }

Write-Host "Windows normal-policy assertions passed."
