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

if (-not (Test-Path $EnvFile)) {
    throw "Missing deployment environment file. Run Install-AlifRetail.ps1 first."
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found."
}

$RunningServices = @(& docker compose --env-file $EnvFile -f $ComposeFile ps --services --status running)
if ($LASTEXITCODE -ne 0 -or -not ($RunningServices -contains "postgres")) {
    throw "PostgreSQL must be running. Start ALIF Retail before creating a backup."
}
$RestartServer = $RunningServices -contains "server"
$RestartCron = $RunningServices -contains "cron"

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$BackupFolder = Join-Path $BackupRoot $Stamp
New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null

try {
    # Quiesce writes so the PostgreSQL dump and filestore archive are a matched pair.
    Invoke-Compose @("stop", "server", "cron")

    $PgDumpCommand = 'set -eu; export PGPASSWORD="$POSTGRES_PASSWORD"; pg_dump -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner --no-acl --file=/backup/database.dump'
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
    Write-Host "Copy this complete folder to encrypted storage separate from this PC."
}
finally {
    if ($RestartServer) {
        Invoke-Compose @("start", "server")
    }
    if ($RestartCron) {
        Invoke-Compose @("start", "cron")
    }
}
