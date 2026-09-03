<#
.SYNOPSIS
    Stops all XiansAi Community Edition services on Windows.

.DESCRIPTION
    PowerShell wrapper around ./stop-all.sh, which holds the actual shutdown
    logic and is shared with macOS and Linux. All arguments are forwarded
    unchanged.

    Requires Git for Windows (for Git Bash) and Docker Desktop.

.EXAMPLE
    .\stop-all.ps1
    Stop all XiansAi services.
#>

. (Join-Path $PSScriptRoot 'scripts\windows-common.ps1')

$global:LASTEXITCODE = 0
Invoke-XiansBashScript -ScriptName 'stop-all.sh' -RepoRoot $PSScriptRoot -ScriptArgs $args
exit $LASTEXITCODE
