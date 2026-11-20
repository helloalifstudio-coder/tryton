[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$EnvFile = Join-Path $RepoRoot "deploy/docker/.env"
$ComposeFile = Join-Path $RepoRoot "deploy/docker/compose.yml"
$BackupFolder = (Resolve-Path -LiteralPath $BackupFolder).Path

function Invoke-Compose {
    param([string[]]$ComposeArgs)

    & docker compose --env-file $EnvFile -f $ComposeFile @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose failed: docker compose $($ComposeArgs -join ' ')"
    }
}

$ManifestPath = Join-Path $BackupFolder "backup-manifest.json"
$DatabasePath = Join-Path $BackupFolder "database.dump"
$FilestorePath = Join-Path $BackupFolder "filestore.tar.gz"
foreach ($RequiredPath in @($ManifestPath, $DatabasePath, $FilestorePath)) {
    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf)) {
        throw "Required backup file is missing: $RequiredPath"
    }
}

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$ActualDatabaseHash = (Get-FileHash -Algorithm SHA256 $DatabasePath).Hash
$ActualFilestoreHash = (Get-FileHash -Algorithm SHA256 $FilestorePath).Hash
if ($ActualDatabaseHash -ne $Manifest.database_sha256 -or
    $ActualFilestoreHash -ne $Manifest.filestore_sha256) {
    throw "Backup checksum verification failed. Nothing was restored."
}

Write-Warning "RESTORE REPLACES THE CURRENT ALIF RETAIL DATABASE AND FILESTORE."
Write-Warning "Make a separate backup of the current installation before continuing."
$Confirmation = Read-Host "Type RESTORE to replace current business data"
if ($Confirmation -cne "RESTORE") {
    throw "Restore cancelled. No data was changed."
}

if (-not (Test-Path $EnvFile)) {
    throw "Missing deployment environment file."
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found."
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
    throw "PostgreSQL did not become healthy. No restore was attempted."
}

Invoke-Compose @("stop", "server", "cron")

$DatabaseRestoreCommand = 'set -eu; export PGPASSWORD="$POSTGRES_PASSWORD"; dropdb -h postgres -U "$POSTGRES_USER" --maintenance-db=postgres --if-exists "$POSTGRES_DB"; createdb -h postgres -U "$POSTGRES_USER" --maintenance-db=postgres --owner="$POSTGRES_USER" "$POSTGRES_DB"; pg_restore --exit-on-error --no-owner --role="$POSTGRES_USER" -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" /restore/database.dump'
Invoke-Compose @("run", "--rm", "--no-deps", "--volume", ($BackupFolder + ":/restore:ro"), "--entrypoint", "sh", "postgres", "-lc", $DatabaseRestoreCommand)

$FilestoreRestoreCommand = 'set -eu; mkdir -p /var/lib/trytond/db; find /var/lib/trytond/db -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar -C /var/lib/trytond -xzf /restore/filestore.tar.gz'
Invoke-Compose @("run", "--rm", "--no-deps", "--volume", ($BackupFolder + ":/restore:ro"), "--entrypoint", "sh", "server", "-lc", $FilestoreRestoreCommand)

Invoke-Compose @("up", "-d", "server", "cron")
Write-Host "Database and filestore restore completed. Validate login, attachments, stock and a test invoice before returning to trading." -ForegroundColor Green
