[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$EnvFile = Join-Path $RepoRoot "deploy/docker/.env"
$ComposeFile = Join-Path $RepoRoot "deploy/docker/compose.yml"

if (-not (Test-Path $EnvFile)) {
    Write-Host "No ALIF Retail deployment environment file was found."
    exit 0
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found. The containers may still be running."
}

& docker compose --env-file $EnvFile -f $ComposeFile stop server cron postgres
if ($LASTEXITCODE -ne 0) {
    throw "Could not stop all ALIF Retail services. Check Docker Desktop."
}

Write-Host "ALIF Retail services stopped. PostgreSQL and filestore volumes were preserved." -ForegroundColor Green
Write-Host "Do not use 'docker compose down -v' unless you deliberately intend to delete business data."
