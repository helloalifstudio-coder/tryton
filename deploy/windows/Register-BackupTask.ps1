[CmdletBinding()]
param(
    [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
    [string]$Time = "22:30"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$EnvFile = Join-Path $RepoRoot "deploy/docker/.env"
$BackupScript = Join-Path $PSScriptRoot "Backup-AlifRetail.ps1"
if (-not (Test-Path $EnvFile)) {
    throw "Run Install-AlifRetail.ps1 before registering scheduled backups."
}

$PowerShell = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $PowerShell) {
    $PowerShell = Get-Command powershell.exe -ErrorAction SilentlyContinue
}
if (-not $PowerShell) {
    throw "PowerShell executable was not found."
}

$Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $BackupScript + '"'
$Action = New-ScheduledTaskAction -Execute $PowerShell.Source -Argument $Arguments -WorkingDirectory $RepoRoot
$Trigger = New-ScheduledTaskTrigger -Daily -At $Time
$Principal = New-ScheduledTaskPrincipal -UserId $Identity -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "ALIF Retail Daily Backup" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Creates a checksummed PostgreSQL and Tryton filestore backup for ALIF Retail." -Force | Out-Null

Write-Host "Daily ALIF Retail backup scheduled for $Time local time." -ForegroundColor Green
Write-Host "The task runs under the current Windows user and requires that user to be signed in."
Write-Host "The backup script starts Docker Desktop/PostgreSQL if needed, then restores the prior running state."
