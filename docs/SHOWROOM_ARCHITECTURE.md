# Alif Retail — Showroom architecture and implementation contract

## 1. What this repository is

This repository is the Tryton ERP monorepo. The original main branch is an
upstream mirror. The production work described here is being developed on
production/8.0-lts, based on the Tryton 8.0 long-term-support source line.

The system is not a single desktop executable with a local file database.
It is a local client/server ERP:

- A native GTK desktop client is installed on each cashier and office PC.
- A Tryton application server runs on a dedicated machine inside the shop LAN.
- PostgreSQL holds the shared operational database.
- Server-side modules implement product, stock, purchase, sale, POS, accounting,
  permissions, workflows and reporting.
- The REST/RPC interfaces support controlled connections from a website,
  mobile app or external automation.

For a one-counter shop the server and client can run on the same machine.
For multiple counters, use one server and one PostgreSQL database; never give
each counter a separate copy of the stock database.

## 2. Logical architecture

    Windows / Linux desktop clients (GTK)
     Cashier 1     Cashier 2     Manager / Stock Office
         |             |                   |
         +-------------+-------------------+
                       | shop LAN
                       v
               Tryton application server
           authentication | workflows | modules
                       |
           +-----------+----------------------+
           |                                  |
           v                                  v
       PostgreSQL                        Filestore
     business records                 attachments/images
           ^
           |
           +--- authenticated REST / RPC integrations
                Website | Mobile | WhatsApp connector
                Payment provider | Reporting/BI

The browser client SAO is present in upstream source, but it is not required
for the intended showroom workflow. Users can work through installed desktop
clients. External services connect through the server's authenticated API,
not by connecting directly to PostgreSQL.

## 3. Core data model for menswear

### Style versus sellable variant

A product template is a style/design. A product product is a sellable variant.
For a clothing shop, this is the core modelling rule:

| Style | Variant attributes | Example SKU |
|---|---|---|
| Wedding sherwani NB-SHW-104 | Ivory / 38 | NB-SHW-104-IV-38 |
| Wedding sherwani NB-SHW-104 | Ivory / 40 | NB-SHW-104-IV-40 |
| Wedding sherwani NB-SHW-104 | Maroon / 38 | NB-SHW-104-MR-38 |

The upstream product and product_attribute modules provide templates,
variants, attribute sets, product codes, identifiers, units and pricing.
The upstream product_image module can hold catalogue imagery. Alif Retail
adds brand, collection, audience, garment type, fabric and season to the
template.

Every size-colour combination that can be sold or counted needs its own
variant, internal code and barcode identifier. A barcode on the style alone
is not enough where different sizes or colours have separate stock.

### Supporting entities

- Brand and Collection organise the catalogue.
- Party is the customer/supplier master.
- Product and Product Variant identify the garment.
- Stock Location identifies shop floor, back room, warehouse, damaged/repair
  and customer locations.
- Stock Move is the operational movement record.
- Purchase and incoming shipment represent replenishment.
- POS Sale, POS Payment and Cash Session represent retail checkout and till
  control.
- Account Move and Invoice represent financial postings.
- Measurement Profile and Alteration Order add menswear-specific tailoring
  operations.

## 4. End-to-end shop workflows

### Purchasing and receiving

1. Create or select the supplier.
2. Create a purchase with the exact product variants, quantities and cost.
3. Confirm the purchase.
4. Receive the incoming shipment into the chosen storage location.
5. Verify the resulting stock moves and product quantities.
6. Record supplier invoice/payment through the accounting workflows.

The purchase/stock modules link supplier documents to incoming stock moves.
A receiving correction should be a return, stock move or inventory count,
not a manual overwrite of the on-hand number.

### Inventory and transfers

Use storage locations to represent the showroom, back room, another
warehouse and damaged stock. Stock moves carry the product variant,
quantity, unit, source, destination, date, company and origin. The stock
module calculates current/forecast quantities from movements and supports
physical inventory counts.

The stock ledger, rather than a cached number on the product card, is the
source of truth.

### Thermal billing

The upstream Sale Point module provides POS points, sale lines, payment
methods, cash sessions, cash transfers and posted accounting records. A POS
point has a stock source location, customer destination location, revenue
journal and document sequence.

The state flow is open -> done -> posted. The sale must be fully paid before
it can be completed. Posting creates stock moves for goods and an accounting
move for sale lines, taxes and payments.

The generic upstream POS does not by itself meet the required cashier
experience or thermal-printer requirement. The project still needs a fast
cashier screen, receipt layout and ESC/POS print bridge. Printer failure must
not repeat a sale: sale posting and print-job execution must be separate,
idempotent operations.

### Customer orders and tailoring

Alif Retail introduces a measurement profile tied to a customer and an
alteration order tied to a garment and optionally to the original POS sale
line. The alteration workflow is draft -> confirmed -> in progress -> ready
-> delivered, with cancellation/rework transitions.

This first slice records the work order; it does not yet create an extra
invoice or charge. Any tailoring fee must use a proper sale/POS charge until
a dedicated billing integration exists.

## 5. Transaction and integration boundaries

The Tryton server owns business rules. PostgreSQL is not an integration API.
External applications should use the authenticated REST/RPC interface with
least-privilege user application keys. The built-in REST endpoints support
model search/read/create/update/delete, registered actions and reports, with
model/field access checks.

For customer-facing connectors, add a small adapter service only where a
provider needs webhooks, retries, idempotency, payload translation or
secrets isolation. Do not duplicate stock or billing logic in that adapter.
A payment provider timeout or WhatsApp outage must not roll back a completed
in-store sale.

Do not expose the database port to the internet. Keep application/server
traffic within the shop LAN, use TLS when traffic crosses an untrusted
network, rotate application keys and log privileged operations.

## 6. Local deployment topology

Recommended topology:

- One dedicated Linux server or business mini-PC running Tryton server and
  PostgreSQL on the same protected LAN.
- Wired Ethernet for cashier stations and server.
- Installed Tryton GTK desktop on each workstation.
- UPS for the server, router and primary switch.
- PostgreSQL backup plus a backup of Tryton's configured filestore path.
- A second backup copy on removable or off-site storage.

This is internet-independent for core in-store operations, but it is not
multi-master offline POS. If the server or local network fails, connected
counters cannot commit sales. Branch-to-branch synchronization and local
offline transaction queues need a separate design and conflict strategy.

## 7. Production gates still required

The following are not marked complete in this branch:

1. **India GST:** GSTIN, HSN, CGST/SGST/IGST, tax invoice/credit note rules,
   returns reports and possible e-invoicing/e-way bill integration. Configure
   only after a qualified Indian tax professional validates the chart,
   product tax mapping and invoice outputs.
2. **Thermal hardware:** ESC/POS support, 58/80 mm layouts, cutter, cash drawer,
   barcode scanners and actual printer/scanner compatibility testing.
3. **Cashier UX:** fast product search, scan-to-cart, variant clarity,
   discounts/approval, split tender and exchange/return workflows.
4. **Security:** role matrix, measurement-data controls, API key lifecycle,
   LAN firewall, TLS where appropriate, secure admin bootstrap and audit review.
5. **Operations:** automatic encrypted backups, restore rehearsal, monitoring,
   log rotation, UPS shutdown behaviour and a written recovery procedure.
6. **Performance:** representative load test for catalogue size, transaction
   history, simultaneous counters, reporting and database backup windows.
7. **Release:** test migration from the exact previous release, build signed
   desktop/server packages, test install/upgrade/uninstall on supported OS
   versions and complete a store acceptance test.

## 8. Acceptance tests before live billing

A release candidate must pass at least these end-to-end tests:

- Create one garment style and multiple size/colour variants.
- Assign a different barcode to every sellable variant.
- Receive 5 units of one variant and 3 of another; verify separate quantities.
- Sell one variant at counter 1; verify stock and accounting changes once.
- Sell simultaneously at two counters; verify unique sale numbers and
  consistent stock.
- Reprint a receipt after a printer fault without duplicating the sale.
- Close and reconcile a cash session with cash, UPI and card tender.
- Return/exchange one item and verify stock and credit/accounting treatment.
- Create an alteration order, attach the customer's authorised measurements,
  progress it to delivered and retain the original sale-line reference.
- Restore the database and filestore backups to a clean machine and verify
  logins, product images, stock, sale history and reports.

**Production status:** engineering foundation and initial apparel module are
under development. Do not use this branch for live billing until the gates
above have been executed and documented.
