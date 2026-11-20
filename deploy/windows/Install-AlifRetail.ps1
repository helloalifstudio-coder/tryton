[CmdletBinding()]
param(
    [string]$OwnerEmail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$EnvExample = Join-Path $RepoRoot "deploy/docker/.env.example"
$EnvFile = Join-Path $RepoRoot "deploy/docker/.env"
$ComposeFile = Join-Path $RepoRoot "deploy/docker/compose.yml"

function New-UrlSafeSecret {
    $Bytes = New-Object byte[] 48
    $Generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $Generator.GetBytes($Bytes)
    }
    finally {
        $Generator.Dispose()
    }

    return [Convert]::ToBase64String($Bytes).TrimEnd("=").Replace("+", "A").Replace("/", "B")
}

function Invoke-Compose {
    param([string[]]$ComposeArgs)

    & docker compose --env-file $EnvFile -f $ComposeFile @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose failed: docker compose $($ComposeArgs -join ' ')"
    }
}

function Wait-ForPostgres {
    $Deadline = (Get-Date).AddMinutes(3)
    do {
        $ContainerId = (& docker compose --env-file $EnvFile -f $ComposeFile ps -q postgres 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $ContainerId) {
            $Health = (& docker inspect --format "{{.State.Health.Status}}" $ContainerId 2>$null).Trim()
            if ($Health -eq "healthy") {
                return
            }
        }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $Deadline)

    Invoke-Compose @("logs", "--tail=80", "postgres")
    throw "PostgreSQL did not become healthy within three minutes."
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found. Install Docker Desktop for Windows with the WSL 2 backend, then rerun this installer."
}
if (-not (Test-Path $EnvExample)) {
    throw "Missing deployment template: $EnvExample"
}
if (Test-Path $EnvFile) {
    throw "A deploy/docker/.env already exists. Refusing to overwrite credentials or an existing installation. Use Start-AlifRetail.ps1 instead."
}

if (-not $OwnerEmail) {
    $OwnerEmail = Read-Host "Owner email for the initial Tryton administrator"
}
if ($OwnerEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    throw "Enter a valid owner email address."
}

# Start Docker Desktop when installed but not already running.
$DockerOs = $null
try {
    $DockerOs = (& docker info --format "{{.OSType}}" 2>$null).Trim()
} catch {
    $DockerOs = $null
}
if ($LASTEXITCODE -ne 0 -or -not $DockerOs) {
    $DockerDesktop = Join-Path $env:ProgramFiles "Docker/Docker/Docker Desktop.exe"
    if (-not (Test-Path $DockerDesktop)) {
        throw "Docker Desktop is not installed or the engine is unavailable. Install/start Docker Desktop and enable its WSL 2 Linux engine."
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

$DbPassword = New-UrlSafeSecret
$AdminPassword = New-UrlSafeSecret
$EnvContent = Get-Content -LiteralPath $EnvExample -Raw
$EnvContent = $EnvContent.Replace(
    "DB_PASSWORD=REPLACE_WITH_A_LONG_RANDOM_DATABASE_PASSWORD",
    "DB_PASSWORD=$DbPassword")
$EnvContent = $EnvContent.Replace(
    "TRYTON_ADMIN_EMAIL=owner@example.invalid",
    "TRYTON_ADMIN_EMAIL=$OwnerEmail")
$EnvContent = $EnvContent.Replace(
    "TRYTON_ADMIN_PASSWORD=REPLACE_WITH_A_DIFFERENT_LONG_RANDOM_ADMIN_PASSWORD",
    "TRYTON_ADMIN_PASSWORD=$AdminPassword")

# Write UTF-8 without BOM; Docker Compose dotenv parsing expects a clean first key.
[System.IO.File]::WriteAllText(
    $EnvFile,
    $EnvContent,
    (New-Object System.Text.UTF8Encoding($false)))

try {
    Invoke-Compose @("build", "server")
    Invoke-Compose @("up", "-d", "postgres")
    Wait-ForPostgres
    Invoke-Compose @("--profile", "setup", "run", "--rm", "init")
    Invoke-Compose @("up", "-d", "server", "cron")
}
catch {
    Write-Error "Installation stopped. Existing Docker volumes have not been deleted. Review the Compose logs before retrying."
    throw
}

Write-Host ""
Write-Host "ALIF Retail local services were initialized." -ForegroundColor Green
Write-Host "Server address: 127.0.0.1:8000"
Write-Host "Initial administrator: $OwnerEmail"
Write-Host "Initial administrator password (shown once): $AdminPassword" -ForegroundColor Yellow
Write-Host "Store this password securely, sign in with the official Tryton 8.0 desktop client, then change it."
Write-Host "The secret file is: $EnvFile"
Write-Host "Use Start-AlifRetail.ps1 to start later and Stop-AlifRetail.ps1 to stop. Neither script deletes the data volumes."
