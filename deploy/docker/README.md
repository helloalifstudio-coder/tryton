# Local Tryton 8.0 LTS deployment

This stack runs the Tryton server and PostgreSQL locally. The showroom
workstations use the installed GTK desktop client; the cashier does not need
to operate the ERP through a browser.

## Prerequisites

- A supported 64-bit Linux server for the long-running shop installation.
  Docker Desktop on Windows is suitable for development/pilot validation.
- Docker Engine and the Docker Compose plugin.
- The official Tryton 8.0 desktop client installed on each counter PC.
- A wired LAN and UPS for a multi-counter shop.
- Access to this repository at its Alif production branch.

The server image extends the official `tryton/tryton:8.0` image with the
`alif_retail` module. PostgreSQL data and Tryton's filestore are held in
persistent named volumes. PostgreSQL is not published to the host.

## First installation

Run these commands from the repository root:

```bash
cp deploy/docker/.env.example deploy/docker/.env
```

Edit `deploy/docker/.env`. Set two different long random passwords:
`DB_PASSWORD` for PostgreSQL and `TRYTON_ADMIN_PASSWORD` for the initial
Tryton administrator. Protect the file:

```bash
chmod 600 deploy/docker/.env
docker compose --env-file deploy/docker/.env -f deploy/docker/compose.yml build server
docker compose --profile setup --env-file deploy/docker/.env -f deploy/docker/compose.yml run --rm init
docker compose --env-file deploy/docker/.env -f deploy/docker/compose.yml up -d server cron
```

The init command creates/updates the Tryton database and activates the module
set available to the initial database. Review the activated module list and
configure only the business functionality the showroom will use. Do not load
live customer or stock data until the tax, product and opening-balance setup
has been reviewed.

Check service status:

```bash
docker compose --env-file deploy/docker/.env -f deploy/docker/compose.yml ps
docker compose --env-file deploy/docker/.env -f deploy/docker/compose.yml logs --tail=100 server
```

## Connect the installed desktop client

Install the native Tryton GTK client from:

https://www.tryton.org/download

For the first PC, keep `TRYTON_BIND_ADDRESS=127.0.0.1` and connect the
desktop client to `127.0.0.1:8000`. Select the database configured by
`DB_NAME` and sign in using the administrator credentials provided during
initialisation. Change the initial password immediately and create named
accounts with least-privilege groups for cashiers, supervisors and managers.

## Add more counters on the shop LAN

Give the server a reserved private LAN address, for example `192.168.1.10`.
Set `TRYTON_BIND_ADDRESS=192.168.1.10`, then recreate the stack:

```bash
docker compose --env-file deploy/docker/.env -f deploy/docker/compose.yml up -d
```

Configure the operating-system firewall to allow TCP 8000 only from the shop
LAN/counter subnet. Connect each installed client to `192.168.1.10:8000`.
Never publish PostgreSQL's port to the LAN or expose the Tryton port directly
to the public internet. Use a VPN or a properly secured TLS reverse proxy for
remote administration.

## Backup

Run the backup script from the repository root during a quiet maintenance
window:

```bash
bash scripts/backup-local.sh
```

It stops the application and cron briefly, then writes a PostgreSQL custom
dump, a filestore archive and SHA-256 checksums under `backups/`. These files
contain sensitive customer and business data. Copy them to encrypted storage
off the server. Configure a retention policy and perform restore drills before
the shop depends on the system. The script creates backups; it does not prove
that a restore works.

## Upgrades

Do not use `latest`. Keep the official image on the 8.0 series and record the
exact image digest used for each release. Before every patch or module update:

1. Take and verify a database + filestore backup.
2. Rehearse the update on a restored copy.
3. Run module tests and the showroom acceptance checklist.
4. Confirm printer and counter regressions.
5. Roll out during a maintenance window with a rollback plan.

For an 8.2 or later upgrade, treat it as a planned series migration with
separate compatibility and data-migration testing, not a simple image-tag
change.

## Known limitations

- This is a local server deployment, not a per-counter offline database.
- The initial addon covers apparel catalogue metadata only.
- ESC/POS thermal billing, Indian GST localisation, tailoring/alteration
  orders, a fast cashier screen, gateway reconciliation and measured 10k+
  variant performance are not completed by this deployment slice.
- The official server image tag is updated by Tryton; for reproducibility,
  record and pin its digest in the release process.
