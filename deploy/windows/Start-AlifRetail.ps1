[CmdletBinding()]
param(
    [switch]$LaunchClient
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$EnvFile = Join-Path $RepoRoot "deploy/docker/.env"
$ComposeFile = Join-Path $RepoRoot "deploy/docker/compose.yml"

function Invoke-Compose {
    param([string[]]$ComposeArgs)

    & docker compose --env-file $EnvFile -f $ComposeFile @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose failed: docker compose $($ComposeArgs -join ' ')"
    }
}

if (-not (Test-Path $EnvFile)) {
    throw "No local installation was found. Run Install-AlifRetail.ps1 first."
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found. Install Docker Desktop for Windows."
}

$DockerOs = $null
try {
    $DockerOs = (& docker info --format "{{.OSType}}" 2>$null).Trim()
} catch {
    $DockerOs = $null
}
if ($LASTEXITCODE -ne 0 -or -not $DockerOs) {
    $DockerCandidates = @(
        (Join-Path $env:ProgramFiles "Docker/Docker/Docker Desktop.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs/DockerDesktop/Docker Desktop.exe")
    )
    $DockerDesktop = $DockerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $DockerDesktop) {
        throw "Docker Desktop is not running and its executable was not found."
    }
    Start-Process -FilePath $DockerDesktop
    $Deadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 3
        try {
            $DockerOs = (& docker info --format "{{.OSType}}" 2>$null).Trim()
        } catch {
            $DockerOs = $null
        }
    } while ((-not $DockerOs -or $LASTEXITCODE -ne 0) -and (Get-Date) -lt $Deadline)
}
if (-not $DockerOs -or $DockerOs -ne "linux") {
    throw "Docker Desktop must be using Linux containers with the WSL 2 backend."
}

Invoke-Compose @("up", "-d", "postgres")
$Deadline = (Get-Date).AddMinutes(3)
$Healthy = $false
do {
    $ContainerId = (& docker compose --env-file $EnvFile -f $ComposeFile ps -q postgres 2>$null).Trim()
    if ($LASTEXITCODE -eq 0 -and $ContainerId) {
        $Health = (& docker inspect --format "{{.State.Health.Status}}" $ContainerId 2>$null).Trim()
        if ($Health -eq "healthy") {
            $Healthy = $true
            break
        }
    }
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $Deadline)

if (-not $Healthy) {
    Invoke-Compose @("logs", "--tail=80", "postgres")
    throw "PostgreSQL did not become healthy. The Tryton server was not started."
}

Invoke-Compose @("up", "-d", "server", "cron")
$Deadline = (Get-Date).AddMinutes(3)
$ServerHealthy = $false
do {
    $ServerId = (& docker compose --env-file $EnvFile -f $ComposeFile ps -q server 2>$null).Trim()
    if ($LASTEXITCODE -eq 0 -and $ServerId) {
        $ServerHealth = (& docker inspect --format "{{.State.Health.Status}}" $ServerId 2>$null).Trim()
        if ($ServerHealth -eq "healthy") {
            $ServerHealthy = $true
            break
        }
    }
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $Deadline)
if (-not $ServerHealthy) {
    Invoke-Compose @("logs", "--tail=100", "server")
    throw "Tryton server did not become healthy. The desktop client was not opened."
}
Invoke-Compose @("ps")

if ($LaunchClient) {
    $Client = Get-Command tryton -ErrorAction SilentlyContinue
    if (-not $Client) {
        $Client = Get-Command tryton.exe -ErrorAction SilentlyContinue
    }
    if ($Client) {
        Start-Process -FilePath $Client.Source
    }
    else {
        Write-Warning "The Tryton desktop client command was not found. Install the official 8.0 Windows desktop client and connect it to 127.0.0.1:8000."
    }
}

Write-Host "ALIF Retail services are running locally at 127.0.0.1:8000." -ForegroundColor Green
