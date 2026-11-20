# ALIF Retail — Windows single-PC deployment

This is the Windows launcher for the local Tryton 8.0 LTS + PostgreSQL
deployment. It keeps PostgreSQL and the Tryton application server in local
Docker containers while the user works in the installed native Tryton GTK
desktop client.

## What this does and does not mean

- No public hosting or internet connection is required for normal local use
  after the images and desktop installer have been downloaded.
- There is still a PostgreSQL database process and a Tryton server process.
  The PowerShell launcher starts them in the background; the user does not
  need to open a terminal and start them manually.
- Data is stored in Docker named volumes and survives closing the desktop
  client, stopping containers and restarting Windows.
- This is a single-computer deployment. It is not an offline-sync client and
  it does not merge multiple independent databases.
- Docker Desktop and its WSL 2 Linux engine must be installed and running.
  The current Compose stack is a local pilot foundation; do not label it a
  validated production Windows appliance until the Windows, backup/restore,
  UPS and hardware acceptance tests have passed.

## Prerequisites

1. Supported 64-bit Windows 10/11 installation with current updates.
2. Docker Desktop configured to use the WSL 2 backend and Linux containers.
3. The official Tryton 8.0 Windows desktop client, installed separately from
   https://www.tryton.org/download
4. This repository cloned locally at the alif/production-foundation branch.
5. Internet access for the first image download/build and desktop-client
   installation. Internet can be disconnected for subsequent local use.

## First-time setup

Open PowerShell in the repository folder. If script execution is restricted,
use a process-scoped policy for this session only:

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Run the installer:

    .\deploy\windows\Install-AlifRetail.ps1 -OwnerEmail "owner@example.com"

The installer:
- Creates deploy/docker/.env only if it does not already exist.
- Generates separate high-entropy database and Tryton administrator
  passwords; it never writes credentials into Git.
- Builds the server image containing alif_retail.
- Starts PostgreSQL and waits for its health check.
- Runs the one-time Tryton database/module initialization.
- Starts the Tryton server and cron services.

**Save the initial administrator password shown at the end of installation.**
Sign in using the native desktop client at 127.0.0.1:8000, select the database
named in deploy/docker/.env, and change the password immediately.

## Daily use

Start the local services:

    .\deploy\windows\Start-AlifRetail.ps1 -LaunchClient

If the desktop client is not on the PATH, start the services without
-LaunchClient, then open Tryton from the Windows Start menu and connect to
127.0.0.1:8000.

Stop the local services after closing the desktop client:

    .\deploy\windows\Stop-AlifRetail.ps1

Stopping services does not delete database or filestore data. Do not use
docker compose down -v, docker volume prune or Docker Desktop's volume
cleanup against a live business installation.

## Backups and restore

Create a consistent backup of both PostgreSQL and the Tryton filestore:

    .\deploy\windows\Backup-AlifRetail.ps1

The script briefly stops Tryton writes, creates a timestamped backup folder
under backups, and records SHA-256 checksums in backup-manifest.json. Copy
the complete folder to encrypted storage on a separate device.

To restore a backup, first take a separate backup of the current installation,
then run:

    .\deploy\windows\Restore-AlifRetail.ps1 -BackupFolder ".\backups\20261120T220000Z"

The restore validates both checksums and requires typing RESTORE. It replaces
the current database and filestore. Keep the application closed during this
operation and validate login, attachments, stock balances and a test invoice
before trading again. A successful backup is not proof of a successful
restore; record a clean restore drill before production use.

## Offline behaviour

After the first successful installation, normal inventory, customer, billing,
and accounting operations are local and do not need internet access. Internet
is still required for software updates, container-image refreshes, remote
payment-provider services, online tax services and any optional integrations.

The Windows launcher requires Docker Desktop to be installed locally. If
Docker Desktop, WSL 2 or the database fails, local billing is unavailable
until the service is restored. This stack does not provide a separate
SQLite fallback or later transaction synchronisation.

## Current deployment limitations

The existing alif_retail addon currently provides apparel brand, collection
and garment metadata only. It is not yet the finished showroom application.
The fast cashier screen, POS-to-customer profile extension, size/colour
matrix creation, full customer activity view, barcode-label workflow,
thermal-printer/cash-drawer integration and Indian GST localisation remain
separate engineering and acceptance tasks.

The Linux server deployment is the preferred long-running production host in
the current deployment guide. The Windows Compose path is provided for a
single-PC local pilot and must pass the Windows-specific acceptance tests
before use with live financial records.
