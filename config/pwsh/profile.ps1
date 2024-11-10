# Run ssh-agent if not running
$sshAgent = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
if (-not ($sshAgent -and $sshAgent.Status -eq 'Running')) {
    Start-Service -Name "ssh-agent"
}
# Environment
Import-Module "~\.config\pwsh\env.ps1"
# Helpers
Import-Module "~\.config\pwsh\lib\helpers.ps1"
# Aliases
Import-Module "~\.config\pwsh\lib\aliases.ps1"
# Completions
Import-Module "~\.config\pwsh\lib\completions.ps1"