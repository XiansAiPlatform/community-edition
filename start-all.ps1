<#
.SYNOPSIS
    Starts the XiansAi Community Edition platform on Windows.

.DESCRIPTION
    PowerShell wrapper around ./start-all.sh, which holds the actual startup
    logic and is shared with macOS and Linux. All arguments are forwarded
    unchanged, so every flag the Bash script supports works here too
    (-v <version>, --observability, --observability-azure, -h).

    Requires Git for Windows (for Git Bash) and Docker Desktop.

.EXAMPLE
    .\start-all.ps1
    Start with defaults (latest images).

.EXAMPLE
    .\start-all.ps1 -v v3.35.1
    Start a specific image version.

.EXAMPLE
    .\start-all.ps1 --observability
    Start with the Aspire Dashboard for OTel traces/metrics/logs.

.EXAMPLE
    .\start-all.ps1 -h
    Show the full option list from the underlying Bash script.
#>

. (Join-Path $PSScriptRoot 'scripts\windows-common.ps1')

$global:LASTEXITCODE = 0
Invoke-XiansBashScript -ScriptName 'start-all.sh' -RepoRoot $PSScriptRoot -ScriptArgs $args
exit $LASTEXITCODE
