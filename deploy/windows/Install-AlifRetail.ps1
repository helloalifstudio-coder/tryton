[CmdletBinding()]
param(
    [string]$OwnerEmail,
    [switch]$Resume
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

function Get-DockerDesktopPath {
    $Candidates = @(
        (Join-Path $env:ProgramFiles "Docker/Docker/Docker Desktop.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs/DockerDesktop/Docker Desktop.exe")
    )
    return $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Ensure-DockerLinuxEngine {
    $DockerOs = $null
    try {
        $DockerOs = (& docker info --format "{{.OSType}}" 2>$null).Trim()
    }
    catch {
        $DockerOs = $null
    }

    if (-not $DockerOs) {
        $DockerDesktop = Get-DockerDesktopPath
        if (-not $DockerDesktop) {
            throw "Docker Desktop is not installed. Install it with the WSL 2 Linux engine, then rerun this installer."
        }

        Start-Process -FilePath $DockerDesktop
        $Deadline = (Get-Date).AddMinutes(5)
        do {
            Start-Sleep -Seconds 3
            try {
                $DockerOs = (& docker info --format "{{.OSType}}" 2>$null).Trim()
            }
            catch {
                $DockerOs = $null
            }
        } while (-not $DockerOs -and (Get-Date) -lt $Deadline)
    }

    if ($DockerOs -ne "linux") {
        throw "Docker Desktop must be using Linux containers with the WSL 2 backend."
    }
}

function Wait-ForServiceHealth {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Service,
        [int]$TimeoutSeconds = 300
    )

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $ContainerId = (& docker compose --env-file $EnvFile -f $ComposeFile ps -q $Service 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $ContainerId) {
            $Health = (& docker inspect --format "{{.State.Health.Status}}" $ContainerId 2>$null).Trim()
            if ($Health -eq "healthy") {
                return
            }
            if ($Health -eq "unhealthy") {
                break
            }
        }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $Deadline)

    Invoke-Compose @("logs", "--tail=100", $Service)
    throw "$Service did not become healthy within $TimeoutSeconds seconds."
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found. Install Docker Desktop for Windows."
}
if (-not (Test-Path $EnvExample)) {
    throw "Missing deployment template: $EnvExample"
}

$IsNewEnvironment = -not (Test-Path $EnvFile)
if ($IsNewEnvironment -and $Resume) {
    throw "-Resume requires an existing deploy/docker/.env file."
}
if (-not $IsNewEnvironment -and -not $Resume) {
    throw "A deploy/docker/.env already exists. The installer will not overwrite it. Use Run-ALIF-Retail.cmd for normal use, or -Resume only after an interrupted first-time setup."
}

$AdminPassword = $null
if ($IsNewEnvironment) {
    if (-not $OwnerEmail) {
        $OwnerEmail = Read-Host "Owner email for the initial Tryton administrator"
    }
    if ($OwnerEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        throw "Enter a valid owner email address."
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

    if ($EnvContent.Contains("REPLACE_WITH_")) {
        throw "The deployment template still contains an unreplaced secret placeholder."
    }

    [System.IO.File]::WriteAllText(
        $EnvFile,
        $EnvContent,
        (New-Object System.Text.UTF8Encoding($false)))
}
else {
    $ExistingEnv = Get-Content -LiteralPath $EnvFile -Raw
    foreach ($Placeholder in @(
        "REPLACE_WITH_A_LONG_RANDOM_DATABASE_PASSWORD",
        "REPLACE_WITH_A_DIFFERENT_LONG_RANDOM_ADMIN_PASSWORD"
    )) {
        if ($ExistingEnv.Contains($Placeholder)) {
            throw "The existing .env still contains a placeholder secret. Replace it securely before using -Resume."
        }
    }
    if ($ExistingEnv -notmatch '(?m)^DB_PASSWORD=.+$' -or
        $ExistingEnv -notmatch '(?m)^TRYTON_ADMIN_PASSWORD=.+$' -or
        $ExistingEnv -notmatch '(?m)^TRYTON_ADMIN_EMAIL=[^@\s]+@[^@\s]+\.[^@\s]+$') {
        throw "The existing .env is missing a database password, administrator password or valid owner email."
    }
    $EmailMatch = [regex]::Match($ExistingEnv, '(?m)^TRYTON_ADMIN_EMAIL=(.+)$')
    if ($EmailMatch.Success) {
        $OwnerEmail = $EmailMatch.Groups[1].Value.Trim()
    }
}

# Restrict the secret file to the current Windows user.
$CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $EnvFile /inheritance:r /grant:r ($CurrentIdentity + ":(R,W)") | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not restrict permissions on deploy/docker/.env."
}

Ensure-DockerLinuxEngine

try {
    Invoke-Compose @("build", "server")
    Invoke-Compose @("up", "-d", "postgres")
    Wait-ForServiceHealth -Service "postgres"
    Invoke-Compose @("--profile", "setup", "run", "--rm", "init")
    Invoke-Compose @("up", "-d", "server", "cron")
    Wait-ForServiceHealth -Service "server"
}
catch {
    Write-Error "Installation did not complete. Database and filestore volumes were not deleted. Review Docker logs before using -Resume."
    throw
}

Write-Host ""
Write-Host "ALIF Retail local services are initialized." -ForegroundColor Green
Write-Host "Server address: 127.0.0.1:8000"
if ($IsNewEnvironment) {
    Write-Host "Initial administrator email: $OwnerEmail"
    Write-Host "Initial administrator password (shown once): $AdminPassword" -ForegroundColor Yellow
    Write-Host "Store this password securely, sign in using the native Tryton desktop client, then change it."
}
else {
    Write-Host "Existing deployment credentials were preserved. The administrator password was not displayed."
}
Write-Host "The secret file is: $EnvFile"
Write-Host "Use Run-ALIF-Retail.cmd for normal daily use. Stop-AlifRetail.ps1 stops services without deleting data volumes."
