<#
.SYNOPSIS
    Pulls the XiansAi Community Edition Docker images on Windows.

.DESCRIPTION
    PowerShell wrapper around ./pull-latest.sh, which holds the actual pull
    logic and is shared with macOS and Linux. All arguments are forwarded
    unchanged (-v <version>, -h).

    Requires Git for Windows (for Git Bash) and Docker Desktop.

.EXAMPLE
    .\pull-latest.ps1
    Pull the latest images.

.EXAMPLE
    .\pull-latest.ps1 -v v3.35.1
    Pull a specific version.
#>

. (Join-Path $PSScriptRoot 'scripts\windows-common.ps1')

$global:LASTEXITCODE = 0
Invoke-XiansBashScript -ScriptName 'pull-latest.sh' -RepoRoot $PSScriptRoot -ScriptArgs $args
exit $LASTEXITCODE
