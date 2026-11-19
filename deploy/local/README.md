# Local showroom deployment (operator runbook)

This runbook describes the intended on-premises topology. It is not a
one-click installer and has not yet been validated on your specific hardware.

## Topology

- Linux server on the shop LAN: Tryton server + PostgreSQL.
- Windows/Linux cashier stations: installed GTK desktop client.
- One shared database for all counters.
- No internet dependency for core catalogue, inventory, POS and accounting
  workflows. Online payment and messaging integrations naturally require
  external connectivity.

Do not run separate SQLite databases for each counter.

## Server preparation

Use a dedicated, supported Linux host, a wired LAN, SSD/NVMe storage and a UPS.
Install PostgreSQL and create a dedicated database user and database. Do not
use the PostgreSQL superuser from Tryton.

Example (run with a PostgreSQL administrator account):

    createuser --pwprompt tryton
    createdb --owner=tryton showroom

Copy trytond.conf.example to /etc/trytond/trytond.conf, restrict it to the
server service account, and supply the database URI through the service
environment:

    TRYTOND_DATABASE_URI=postgresql://tryton:CHANGE_ME@127.0.0.1:5432/
    TRYTOND_CONFIG=/etc/trytond/trytond.conf

Keep the real password in a root-owned environment file with mode 0600; never
commit it to Git or put it in a support ticket. Bind the web service to the
LAN interface and firewall the port so only shop workstations and approved
integration hosts can reach it. Do not expose PostgreSQL to the LAN unless
there is a documented operational reason.

## Install this source branch

Use the Python version supported by the selected Tryton 8.0 release and keep
the server environment isolated. From the repository root:

    python3 -m venv .venv
    . .venv/bin/activate
    python -m pip install --upgrade pip packaging build hatchling hatch-tryton babel rnc2rng
    ./.hooks/link_modules
    ./.hooks/update_requirements
    python -m pip install -e ./trytond -r requirements.txt

The source hook links the module folders into the server module path. Do not
run the server from an unreviewed developer checkout in a live store; build
and deploy a versioned release artifact after the release gates pass.

## Initialise a new database

Set the database URI, config path and a root-owned admin password file
containing the initial Tryton administrator password. Restrict that file to
the service account (mode 0600). Then activate the required modules and
their dependencies:

    TRYTOND_CONFIG=/etc/trytond/trytond.conf
    TRYTOND_DATABASE_URI='postgresql://tryton:CHANGE_ME@127.0.0.1:5432/'
    TRYTONPASSFILE=/etc/trytond/admin.pass
    trytond-admin -d showroom -u ir res company country currency party product product_attribute stock account account_product account_invoice account_invoice_stock account_payment purchase sale sale_point alif_retail --activate-dependencies

Confirm module activation in the administration client. Do not use --all as
a shortcut: that updates all activated modules and is not a substitute for
selecting the intended module set on a fresh database.

For subsequent releases, take a verified backup first, deploy the reviewed
release artifact, then run the explicit module update command for the modules
being upgraded. Never update the live database directly from an unreviewed
branch.

## Start the server and connect clients

Run trytond with the same configuration and database environment. Install
the GTK desktop client from the matching Tryton 8.0 release line on each
workstation, create a connection profile pointing to the server's LAN
hostname and port 8000, then sign in with an individual named account.

The native GTK client is the intended staff interface. Do not configure
cashiers to use the SAO browser client for this desktop-only deployment.

## Backups and recovery

At minimum:

1. Back up PostgreSQL with pg_dump -Fc on a scheduled basis.
2. Back up the configured Tryton filestore under database.path as well as
   the database. Keep a consistent snapshot; briefly stop writes or use a
   tested snapshot procedure so database records and file objects agree.
3. Encrypt backup copies and store a second copy on a separate device or
   off-site location.
4. Monitor backup completion and free disk space.
5. Rehearse a full restore to a clean host and verify product images, users,
   stock, sales, payments and reports.

Example database backup (adjust host, database and secure credential handling):

    pg_dump --format=custom --no-owner --file=showroom.dump showroom

A backup that has never been restored is not a proven recovery plan.

## Still required before a live shop

This deployment note does not implement or certify India GST, e-invoicing,
thermal receipt printing, cash drawer control, barcode scanner device
management, multi-branch replication, offline-counter recovery, signed
installers or production monitoring. Validate those separately. In particular,
test the actual 58/80 mm printer, cutter, drawer and barcode scanner models
before promising cashier go-live.
