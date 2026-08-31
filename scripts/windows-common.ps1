# XiansAi Community Edition - Shared helpers for the Windows PowerShell wrappers
#
# The platform's management logic lives in the Bash scripts (start-all.sh,
# stop-all.sh, reset-all.sh, pull-latest.sh) so that macOS, Linux and Windows all
# run exactly the same code. The .ps1 wrappers in the repository root are thin:
# they locate Git Bash, run a pre-flight check, and hand off.
#
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.

# Locate bash.exe from Git for Windows.
# Checks the standard install locations first, then derives it from git.exe on
# PATH (covers winget/Scoop/Chocolatey and other non-default install prefixes).
function Find-GitBash {
    [CmdletBinding()]
    param()

    # Built from environment variables, any of which may be unset on a given host.
    $prefixes = @(
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:LOCALAPPDATA
    )
    $suffixes = @('Git\bin\bash.exe', 'Git\bin\bash.exe', 'Programs\Git\bin\bash.exe')

    for ($i = 0; $i -lt $prefixes.Count; $i++) {
        $prefix = $prefixes[$i]
        if ([string]::IsNullOrWhiteSpace($prefix)) { continue }
        $candidate = Join-Path $prefix $suffixes[$i]
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    # Fall back to deriving the path from git.exe: <prefix>\cmd\git.exe -> <prefix>\bin\bash.exe
    $git = Get-Command -Name 'git.exe' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($git) {
        $prefix = Split-Path -Path (Split-Path -Path $git.Source -Parent) -Parent
        $derived = Join-Path $prefix 'bin\bash.exe'
        if (Test-Path -LiteralPath $derived -PathType Leaf) {
            return $derived
        }
    }

    return $null
}

# Verify the Docker CLI is present and the daemon is reachable.
# Docker Desktop not being started is by far the most common Windows failure, and
# the error it produces deeper in the stack is unhelpful, so check it up front.
function Test-DockerReady {
    [CmdletBinding()]
    param()

    $docker = Get-Command -Name 'docker' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $docker) {
        Write-Host '[X] Docker was not found on PATH.' -ForegroundColor Red
        Write-Host '    Install Docker Desktop: https://www.docker.com/products/docker-desktop'
        return $false
    }

    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[X] Docker is not running. Please start Docker Desktop and try again.' -ForegroundColor Red
        return $false
    }

    return $true
}

# Run one of the repository's Bash scripts through Git Bash.
#
# Arguments are forwarded verbatim, so every flag the Bash script accepts
# (-v <version>, --observability, -f, -h, ...) works unchanged from PowerShell.
#
# Writes nothing to the output stream: the Bash script's stdout/stderr go
# straight to the console so that progress output and interactive prompts (the
# admin e-mail/password in start-all.sh) appear live and unbuffered. The result
# is reported through $LASTEXITCODE, which callers should propagate with
# `exit $LASTEXITCODE`.
function Invoke-XiansBashScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $RepoRoot,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $ScriptArgs = @(),

        [Parameter()]
        [switch] $SkipDockerCheck
    )

    # The Bash scripts print UTF-8 status output; without this the Windows console
    # renders it as mojibake on the default code page.
    $originalEncoding = $null
    try {
        $originalEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    } catch {
        # Some hosts (e.g. the ISE) do not allow changing the console encoding.
        $originalEncoding = $null
    }

    try {
        $bash = Find-GitBash
        if (-not $bash) {
            Write-Host '[X] Git Bash was not found.' -ForegroundColor Red
            Write-Host ''
            Write-Host '    The XiansAi management scripts run through Git Bash, which ships'
            Write-Host '    with Git for Windows. Install it and re-run this script:'
            Write-Host ''
            Write-Host '      winget install --id Git.Git -e'
            Write-Host '      (or download from https://git-scm.com/download/win)'
            $global:LASTEXITCODE = 1
            return
        }

        $scriptPath = Join-Path $RepoRoot $ScriptName
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            Write-Host "[X] Could not find $ScriptName in $RepoRoot" -ForegroundColor Red
            $global:LASTEXITCODE = 1
            return
        }

        if (-not $SkipDockerCheck) {
            if (-not (Test-DockerReady)) {
                $global:LASTEXITCODE = 1
                return
            }
        }

        if ($null -eq $ScriptArgs) {
            $ScriptArgs = @()
        }

        # The Bash scripts resolve sibling paths relative to the working directory
        # (./scripts/create-secrets.sh, studio/.env.local, ...), so run from the
        # repository root regardless of where the user invoked the wrapper from.
        Push-Location -LiteralPath $RepoRoot
        try {
            & $bash "./$ScriptName" @ScriptArgs
        } finally {
            Pop-Location
        }
    } finally {
        if ($null -ne $originalEncoding) {
            try { [Console]::OutputEncoding = $originalEncoding } catch { }
        }
    }
}
