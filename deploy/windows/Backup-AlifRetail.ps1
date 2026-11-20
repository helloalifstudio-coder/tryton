[CmdletBinding()]
param(
    [string]$BackupRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$EnvFile = Join-Path $RepoRoot "deploy/docker/.env"
$ComposeFile = Join-Path $RepoRoot "deploy/docker/compose.yml"
if (-not $BackupRoot) {
    $BackupRoot = Join-Path $RepoRoot "backups"
}
$BackupRoot = [System.IO.Path]::GetFullPath($BackupRoot)

function Invoke-Compose {
    param([string[]]$ComposeArgs)

    & docker compose --env-file $EnvFile -f $ComposeFile @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose failed: docker compose $($ComposeArgs -join ' ')"
    }
}

function Ensure-DockerLinuxEngine {
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
            throw "Docker Desktop is not installed. Install it with the WSL 2 Linux engine."
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

if (-not (Test-Path $EnvFile)) {
    throw "Missing deployment environment file. Run Install-AlifRetail.ps1 first."
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found."
}

Ensure-DockerLinuxEngine
$RunningServices = @(& docker compose --env-file $EnvFile -f $ComposeFile ps --services --status running)
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect the current ALIF Retail services."
}
$PostgresWasRunning = $RunningServices -contains "postgres"
$RestartServer = $RunningServices -contains "server"
$RestartCron = $RunningServices -contains "cron"

# A scheduled backup can run after the shop has shut down. Start only PostgreSQL
# when the application was previously stopped, and restore the previous state.
Invoke-Compose @("up", "-d", "postgres")
Wait-ForPostgres

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$BackupFolder = Join-Path $BackupRoot $Stamp
New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null

$CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $BackupFolder /inheritance:r /grant:r ($CurrentIdentity + ":(OI)(CI)F") | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not restrict permissions on the backup folder."
}

$TranscriptStarted = $false
try {
    Start-Transcript -Path (Join-Path $BackupFolder "backup.log") -Force | Out-Null
    $TranscriptStarted = $true

    # Quiesce writes so the PostgreSQL dump and filestore archive form one pair.
    Invoke-Compose @("stop", "server", "cron")

    $PgDumpCommand = 'set -eu; export PGPASSWORD="$POSTGRES_PASSWORD"; pg_dump -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-password --format=custom --no-owner --no-acl --file=/backup/database.dump'
    Invoke-Compose @("run", "--rm", "--no-deps", "--volume", ($BackupFolder + ":/backup"), "--entrypoint", "sh", "postgres", "-lc", $PgDumpCommand)

    $FilestoreCommand = 'set -eu; tar -C /var/lib/trytond -czf /backup/filestore.tar.gz db'
    Invoke-Compose @("run", "--rm", "--no-deps", "--volume", ($BackupFolder + ":/backup"), "--entrypoint", "sh", "server", "-lc", $FilestoreCommand)

    $DatabaseHash = (Get-FileHash -Algorithm SHA256 (Join-Path $BackupFolder "database.dump")).Hash
    $FilestoreHash = (Get-FileHash -Algorithm SHA256 (Join-Path $BackupFolder "filestore.tar.gz")).Hash
    $Manifest = [ordered]@{
        created_utc = (Get-Date).ToUniversalTime().ToString("o")
        repository = "helloalifstudio-coder/tryton"
        deployment_series = "8.0"
        database_file = "database.dump"
        database_sha256 = $DatabaseHash
        filestore_file = "filestore.tar.gz"
        filestore_sha256 = $FilestoreHash
    }
    $Manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $BackupFolder "backup-manifest.json") -Encoding UTF8

    Write-Host "Backup created: $BackupFolder" -ForegroundColor Green
    Write-Host "Copy this complete folder to encrypted storage on a separate device."
}
finally {
    if ($TranscriptStarted) {
        Stop-Transcript | Out-Null
    }
    if ($RestartServer) {
        Invoke-Compose @("start", "server")
    }
    if ($RestartCron) {
        Invoke-Compose @("start", "cron")
    }
    if (-not $PostgresWasRunning) {
        Invoke-Compose @("stop", "postgres")
    }
}
