<#
.SYNOPSIS
    Completely resets the XiansAi Community Edition platform on Windows (DESTRUCTIVE).

.DESCRIPTION
    PowerShell wrapper around ./reset-all.sh, which holds the actual reset logic
    and is shared with macOS and Linux. All arguments are forwarded unchanged.

    WARNING: this stops all services and DELETES ALL DATA (Docker volumes are
    removed and the generated .env.local files are deleted). Without -f you are
    prompted to type RESET to confirm.

    Requires Git for Windows (for Git Bash) and Docker Desktop.

.EXAMPLE
    .\reset-all.ps1
    Reset with a confirmation prompt.

.EXAMPLE
    .\reset-all.ps1 -f
    Reset without prompting.
#>

. (Join-Path $PSScriptRoot 'scripts\windows-common.ps1')

$global:LASTEXITCODE = 0
Invoke-XiansBashScript -ScriptName 'reset-all.sh' -RepoRoot $PSScriptRoot -ScriptArgs $args
exit $LASTEXITCODE
