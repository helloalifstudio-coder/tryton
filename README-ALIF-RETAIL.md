# Alif Retail Showroom Edition

This is the Alif Growth Media showroom implementation built on the Tryton ERP
platform. It targets local, installed desktop use in menswear and kidswear
retail showrooms.

## Which branch?

Use **`production/8.0-lts`** for this work. It is based on the Tryton 8.0 LTS
release line and is intentionally isolated from `main`, which remains the
upstream 8.3 development mirror. Do not merge the LTS branch into `main`
without a deliberate release-line migration.

- [Showroom implementation branch](https://github.com/helloalifstudio-coder/tryton/tree/production/8.0-lts)
- [Showroom architecture](docs/SHOWROOM_ARCHITECTURE.md)
- [Local deployment runbook](deploy/local/README.md)
- [Alif Retail module](modules/alif_retail/README.rst)
- [Alif Retail module tests](.github/workflows/alif-retail.yml)

## How the application runs

The intended shop deployment is client/server, not one standalone SQLite file
per counter:

1. Install the native Tryton GTK desktop client on each cashier and office PC.
2. Run one Tryton application server and PostgreSQL database on a dedicated
   machine inside the showroom LAN.
3. Connect every counter to the same server and database.
4. Use Tryton's authenticated RPC/REST interfaces for approved integrations.
5. Back up the database and filestore together and rehearse restores.

Core catalogue, stock, purchasing, POS and accounting workflows can run on
the local LAN without internet connectivity. A server or LAN outage still
stops connected counters from committing sales; offline queues and branch
replication are not yet implemented.

## Menswear data model

A product template represents a garment style. Each sellable size/colour/fit
combination is a separate product variant with its own SKU, barcode and stock
quantity. Tryton's product, product-attribute, stock, purchase, sale, POS and
accounting modules remain the system of record. The Alif Retail module adds
brand/collection/garment metadata, customer measurement profiles and
alteration work orders.

## Current engineering status

**Alpha foundation — not approved for live billing yet.**

The initial module package has been tested for installation on SQLite and
PostgreSQL 16 with Python 3.12. This validates module registration and its
current forms. It does not certify the whole ERP, a real showroom deployment,
printer hardware, tax outputs, load capacity or recovery procedures.

Still required before production release:

- Indian GST localisation and accounting validation.
- Fast cashier screen, ESC/POS thermal receipts and physical scanner/drawer
  compatibility tests.
- Returns/exchange and payment-provider flows verified end to end.
- Security review, role-based acceptance tests and key rotation.
- Backup automation, filestore consistency and a witnessed restore drill.
- Load/concurrency tests for the intended counters and inventory size.
- Versioned server/desktop installers, upgrade/rollback procedure and store
  acceptance sign-off.

See [the architecture document](docs/SHOWROOM_ARCHITECTURE.md) for the full
scope and release gates.
