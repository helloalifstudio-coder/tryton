# Alif Showroom — go-live acceptance checklist

No production label should be applied until each applicable item has an
evidence record, test owner and pass result. A Docker build or a successful
login is not a production acceptance test.

## 1. Build and release

- [ ] Server, modules and desktop client are all on the same Tryton 8.0 series.
- [ ] The build is pinned to a reviewed image tag and recorded image digest.
- [ ] The custom addon installs and upgrades on an empty database.
- [ ] The custom addon upgrades a populated test database without data loss.
- [ ] CI passes for supported Python versions.
- [ ] Database migration has a tested rollback/restore plan.
- [ ] Upstream changes are merged through a reviewed branch, not copied into
  the custom code by hand.

## 2. Single-PC Windows deployment

- [ ] Install on a clean supported Windows 10/11 PC with the WSL 2 Linux engine.
- [ ] Installer generates unique secrets and refuses to overwrite an existing
  environment file or database volume.
- [ ] Start script starts PostgreSQL, Tryton and cron before opening the client.
- [ ] Stop script closes services without deleting PostgreSQL or filestore volumes.
- [ ] Windows restart preserves all records, attachments and configuration.
- [ ] Core inventory, customer, billing and accounting workflows pass with
  internet disconnected after initial installation.
- [ ] Docker Desktop unavailable, WSL failure and database-unhealthy cases
  produce clear recovery instructions.
- [ ] Desktop client connection and native Windows printer/scanner devices
  are tested on the actual target PC.

## 3. Apparel catalogue and barcode

- [ ] One garment template can carry brand, collection, department and garment
  type.
- [ ] Size and colour attribute sets can create the expected variants.
- [ ] Each sellable size/colour has its own internal code and unique barcode.
- [ ] Duplicate barcodes are rejected by the data model.
- [ ] Barcode scan resolves the exact variant, not just the parent template.
- [ ] Variant-specific sale price and cost are correct.
- [ ] Inactive products cannot be sold accidentally.
- [ ] Bulk product/variant import is repeatable and reports rejected rows.

## 4. Purchasing and inventory

- [ ] A supplier purchase for multiple sizes/colours receives the correct
  variant quantities.
- [ ] Supplier returns reverse the correct stock movements.
- [ ] Physical stock count can reconcile a sample shelf without hand-editing
  stored quantities.
- [ ] Internal transfers preserve the correct from/to locations.
- [ ] Damaged or quarantined stock is unavailable to normal billing.
- [ ] Stock reports reconcile to posted stock moves and valuation.

## 5. POS and cashier

- [ ] Scanner-based sale works at realistic checkout speed.
- [ ] Cash, UPI, card and split tenders reconcile to the correct accounts.
- [ ] Cash session opening, cash-in/out, closing and variance are tested.
- [ ] A posted POS sale creates exactly one stock movement per applicable
  sale line and its corresponding accounting entry.
- [ ] Repeated clicks or retrying a timed-out request do not create duplicate
  sales or duplicate payments.
- [ ] Exchanges, returns, refunds and cancelled sales follow an approved
  supervisor policy.
- [ ] Receipt reprint does not create a new sale.
- [ ] Two or more counters can post sales concurrently without lost stock or
  duplicate document numbers.

## 6. Thermal devices

- [ ] Exact 58 mm and/or 80 mm printer model has been tested.
- [ ] Paper width, character set, line wrapping, logo and GST fields are correct.
- [ ] Cutter works where fitted.
- [ ] Cash drawer opens only after authorised cash payment.
- [ ] Printer-offline, paper-out and USB/network disconnect cases are handled.
- [ ] Reprint queue is auditable and does not duplicate accounting transactions.
- [ ] Barcode label printer and exact scanner models have been tested.

## 7. Indian tax and accounting

- [ ] CA-approved chart of accounts and journals are configured.
- [ ] GST registration data, GSTIN and place-of-supply rules are correct.
- [ ] HSN/SAC and applicable tax rates are approved.
- [ ] CGST/SGST/IGST behaviour is tested for local and inter-state scenarios.
- [ ] Tax-inclusive and tax-exclusive pricing are tested, including rounding.
- [ ] Tax invoices, credit notes, cancellations and exports are approved.
- [ ] GST reports reconcile to invoice and ledger totals.
- [ ] E-invoicing/e-way bill applicability is assessed for the taxpayer and
  current turnover/rule thresholds; do not assume it is always required.

## 8. Security and permissions

- [ ] Default credentials have been replaced before live data is entered.
- [ ] Cashiers cannot edit product cost, tax configuration, accounts or users.
- [ ] Supervisors have only the approved override permissions.
- [ ] Administrators use individual accounts; no shared cashier login.
- [ ] API application keys are scoped to dedicated integration users and can be
  revoked.
- [ ] PostgreSQL is reachable only on the private container network.
- [ ] Port 8000 is not exposed directly to the public internet.
- [ ] Remote access uses VPN or a properly configured TLS reverse proxy.
- [ ] Secrets and backup archives are encrypted and access controlled.

## 9. Data safety, recovery and performance

- [ ] Scheduled database and filestore backups complete without interrupting
  active sales; backup logs and retention are monitored.
- [ ] Every backup contains a matched PostgreSQL dump, filestore archive and
  verified checksum manifest.
- [ ] A backup has been restored to a clean test environment successfully.
- [ ] Windows PowerShell and Linux restore procedures have both been exercised.
- [ ] Recovery time and acceptable data-loss window are documented.
- [ ] UPS shutdown and server restart recovery are tested.
- [ ] A representative 10,000+ variant dataset is loaded.
- [ ] Search, barcode scan, sale posting, stock availability and reports meet
  agreed response-time targets under concurrent cashier load.
- [ ] Historical stock moves and attachments are included in performance
  testing.
- [ ] Database maintenance, log rotation and disk-space alerts are configured.

## 10. Store operations

- [ ] Staff training and role-specific operating instructions are complete.
- [ ] Opening, receiving, billing, returns, stock-count and closing procedures
  are documented.
- [ ] Existing product and opening-stock import has been reconciled.
- [ ] The owner signs off opening stock and financial balances.
- [ ] A pilot period has been completed with daily reconciliation.
- [ ] A named person owns support, backups, upgrades and device replacement.
