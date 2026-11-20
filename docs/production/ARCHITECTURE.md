# Alif Showroom — production architecture

**Baseline:** Tryton 8.0 LTS  
**Upstream:** https://github.com/tryton/tryton  
**Alif fork:** https://github.com/helloalifstudio-coder/tryton  
**Custom module:** `modules/alif_retail`

This document describes the code that exists in the selected Tryton baseline,
the showroom use of those modules, and the work that is still required. It is
not a statement that the system has passed a live-store acceptance test.

## 1. Runtime architecture

Tryton is a three-tier application:

```text
┌──────────────────────────────┐       ┌──────────────────────────────┐
│ Counter 1                    │       │ Counter 2                    │
│ Installed Tryton GTK client  │       │ Installed Tryton GTK client  │
│ Windows / Linux / macOS      │       │ Windows / Linux / macOS      │
└──────────────┬───────────────┘       └──────────────┬───────────────┘
               │             Private shop LAN         │
               └──────────────────┬───────────────────┘
                                  │ RPC / authenticated sessions
                   ┌──────────────▼──────────────┐
                   │ Tryton application server   │
                   │ Server modules + workflows  │
                   │ REST / JSON-RPC / XML-RPC   │
                   └──────────────┬──────────────┘
                                  │
                   ┌──────────────▼──────────────┐
                   │ PostgreSQL                  │
                   │ Business records / ledger   │
                   └─────────────────────────────┘
                                  │
                   ┌──────────────▼──────────────┐
                   │ Persistent Tryton filestore │
                   │ Attachments / stored files  │
                   └─────────────────────────────┘
```

The cashier and manager use the installed GTK desktop client. They do not need
to use a browser-based ERP screen. The official server Docker image also
contains a web client, but that does not force the showroom workstations to use
it. The desktop client connects to the same application server and business
records.

**Important operating model:** this is local-network software, not a
standalone database on every counter. All counters use the same shop server
and PostgreSQL database. Internet access is not needed for normal operation
inside the shop once the server, desktop clients and local network are working.
If the central server or shop LAN fails, the counters cannot transact until
connectivity is restored. Independent offline counter queues and later
conflict-free synchronisation are not supplied by this design.

Official architecture and installers:
- https://www.tryton.org/download
- https://docs.tryton.org/8.0/client-desktop/
- https://docs.tryton.org/8.0/server/

## 2. What the upstream repository actually contains

The repository is the complete Tryton source tree, not a small retail app. The
important source areas are:

| Source area | Responsibility |
|---|---|
| `trytond/` | Application server, ORM, transactions, access control, RPC, REST, reports, queue/cron support |
| `tryton/` | Native GTK desktop client |
| `sao/` | Browser client; optional for this desktop-first deployment |
| `proteus/` | Python client/automation library |
| `modules/product/` | Product templates, variants, internal product codes, product identifiers, categories and units |
| `modules/product_attribute/` | Attribute sets and per-variant attributes |
| `modules/stock/` | Warehouses, storage locations, stock moves, shipments, inventory counts and stock reports |
| `modules/stock_supply/` | Replenishment rules and purchase requests |
| `modules/purchase/` | Suppliers, purchase orders, supplier receipts, purchase returns and supplier invoicing |
| `modules/sale/` | Sales, delivery moves, customer invoicing and returns |
| `modules/sale_point/` | Retail sale points, POS sales, payments, payment methods and cash sessions |
| `modules/account/` | Journals, accounts, periods, taxes and double-entry accounting |
| `modules/account_invoice/` | Customer/supplier invoices, payment terms and invoice documents |
| `modules/account_payment/` | Payment records and reconciliation workflows |
| `modules/party/` | Shared customer, supplier, address and contact records |
| `modules/company/` | Company, employee and company-specific configuration |

The modules are loaded into the server's model registry. A module declares its
dependencies in `tryton.cfg`, registers Python models and wizards, and adds
menus, access rules and views through XML. This is why the showroom extension
is being written as a separate module instead of patching the upstream stock
or accounting engines.

## 3. Men's clothing data model

### 3.1 Product template versus variant

The most important design decision is to model a design separately from each
saleable size/colour combination.

Example:

**Template / style**
- Brand: Noman Brothers
- Style code: the existing Tryton product-template code
- Name: Royal Blue Embroidered Sherwani
- Department: Men's Wear
- Garment type: Sherwani
- Collection: Wedding 2026
- Fabric: Silk blend
- Fit: Regular
- Attribute set: Apparel Size + Colour

**Variants / stock keeping units**
- Royal Blue Sherwani / 38
- Royal Blue Sherwani / 40
- Royal Blue Sherwani / 42
- Royal Blue Sherwani / 44
- Black Sherwani / 40
- Black Sherwani / 42

Each saleable combination is an individual `product.product` record. It can
have its own internal code, barcode identifier, price and stock quantity.
A barcode must resolve to exactly one variant, not merely to the parent style.
This is what allows a scan at the counter to decrement the correct size and
colour.

The upstream `product_attribute` module supplies the attribute-set mechanism.
The showroom should configure an attribute set such as:

| Attribute | Example values |
|---|---|
| Size | 34, 36, 38, 40, 42, 44, 46, S, M, L, XL, XXL, 3XL |
| Colour | Black, Navy, Maroon, Ivory, Bottle Green, White |
| Fit | Slim, Regular, Classic, Relaxed |
| Sleeve | Full, Half, Sleeveless |

Use only values appropriate to the garment category. A sherwani and a
children's kurta do not necessarily share the same size scale. The existing
attribute model provides the data structure; a user-friendly bulk size/colour
matrix generator and bulk barcode-label workflow are still planned work.

### 3.2 Alif's custom showroom module

The first custom module, `alif_retail`, extends the standard product template
with:
- Brand master data.
- Collection master data, including season and dates.
- Retail department: Men's Wear, Kids' Wear or Accessories.
- Garment type: kurta pyjama, pathani, sherwani, suit, Jodhpuri, waistcoat,
  Nehru jacket, shirts, trousers, kids' ethnic wear, jutti, pagdi, topi,
  dupatta/stole or other.
- Fabric composition, fit and care instructions.

It does **not** create parallel product, variant, SKU, stock, customer or
accounting tables. Existing Tryton product/stock records remain the source of
truth. The model and screens are in `modules/alif_retail/`.

## 4. How a showroom transaction moves through the system

### Step A — Catalogue setup

1. Create a brand and collection in Products → Configuration.
2. Create a product template for each garment design.
3. Assign department, garment type, collection, fabric and fit.
4. Select a product attribute set for size and colour.
5. Create the variants that can actually be sold.
6. Set a unique internal code and barcode identifier for each variant.
7. Configure list prices, cost method, sales taxes and accounting categories.

Do not create one product record for every garment photograph with no variant
structure. That would make stock by size and colour unreliable.

### Step B — Supplier purchasing and receiving

1. Create the supplier as a Party record.
2. Create a purchase order for the exact product variants and quantities.
3. Confirm the purchase and receive the shipment into the correct warehouse
   storage location.
4. Validate the receipt and reconcile the supplier invoice.

The purchase module links purchase lines to stock moves. Receiving a shipment
is therefore an inventory event, not just an edit to a displayed quantity.

### Step C — Stock management

The stock module stores movements between locations. A showroom should
configure locations at least for:
- Main store / back room.
- Display floor, when floor stock is separately controlled.
- Damaged / quarantine stock.
- Customer location.
- Supplier location.

Use stock inventories for physical counts and corrections. Use internal
shipments for transfers between locations. Use replenishment rules only after
the min/max levels have been defined and validated with actual demand.

### Step D — Retail billing

The `sale_point` module contains the concepts for:
- A configured POS point.
- Its company and stock storage location.
- Its customer destination and return location.
- Its revenue journal and tax-included pricing setting.
- A POS sale and its lines.
- Payment methods and payments.
- Cash sessions, transfers and closing balances.

A cashier sale references a product variant. On posting, the POS implementation
creates the corresponding stock moves and accounting move. The standard POS
code explicitly links sale posting to both the stock and account workflows.
That is the important integration: the billing record and stock ledger are not
separate systems that need a nightly spreadsheet sync.

For the showroom, configure payment methods such as Cash, UPI, Debit/Credit
Card and Bank Transfer against the appropriate accounting accounts. This
records the tender method; it does not itself integrate with a UPI PSP, card
terminal or bank. Automated settlement/payment-gateway integration is a
separate project.

### Step E — Returns and exchanges

The POS line supports negative quantities and creates reverse-direction stock
moves using the configured return location. The exact exchange policy, refund
approval, receipt linkage and damaged-goods inspection must be configured and
tested before launch. Staff should never make a return by silently editing
stock quantity.

### Step F — Accounts and reports

POS posting creates accounting entries using the configured revenue journal,
product revenue accounts, taxes and payment-method accounts. The accounting
and invoice modules provide the underlying ledgers and documents. A qualified
accountant must approve the Indian chart of accounts, tax setup, invoice
formats and reports before production use.

## 5. Integration surfaces

The server source includes:
- JSON-RPC and XML-RPC for Tryton clients.
- A built-in REST protocol for model reads/writes, registered actions and
  reports.
- Authenticated user-application keys for external clients.
- Server-side model and field access checks.

The integration design should use those authenticated server interfaces.
External websites, mobile apps or reporting services must not connect directly
to PostgreSQL or receive a database password. A future integration gateway
may provide narrower, stable business endpoints, webhook delivery, retries
and idempotency, but it should call the Tryton server API rather than bypass
its model rules.

## 6. What is not solved yet

These are material go-live gaps, not minor polish tasks.

| Gap | Current state | Required engineering |
|---|---|---|
| Thermal receipt printing | No verified ESC/POS cashier print pipeline in this fork | Build a print service/report, printer profiles, retries, drawer kick and physical tests on the actual 58/80 mm devices |
| Indian GST | Core has a generic tax/accounting engine; no verified India-specific GST module is included in this fork | GSTIN/HSN, CGST/SGST/IGST, invoice/credit-note formats, returns and e-invoice applicability; CA sign-off |
| Fast cashier interface | Standard POS records and payment workflow exist | Build and usability-test a keyboard/scanner-first cashier screen; the standard form is not yet the finished showroom till UX |
| Size/colour matrix | Generic attribute/variant framework exists | Bulk variant generation, matrix stock view, bulk barcode assignment and label printing |
| Tailoring / alterations | No showroom-specific alteration-order workflow in the first addon | Customer measurements, alteration ticket, advance, due date, status and delivery acknowledgement |
| UPI/card gateway | Payment methods can classify/account for tender | Integrate selected provider/terminal and reconcile settlements; manual tender recording is not gateway integration |
| Multi-branch offline sync | Central database and company/warehouse separation exist | Define branch topology and conflict-safe synchronisation before claiming disconnected branch operation |
| Performance at 10,000+ SKUs | PostgreSQL and indexed model/stock queries provide a sound base | Run load tests using representative variants, historical moves, concurrent counters and reports |
| Device support | No showroom hardware has been tested here | Verify scanner, printer, cash drawer, label printer and any weighing device on the exact models |

## 7. Deployment topology

For the first showroom:
- One local server PC or small Linux server runs the Tryton server and PostgreSQL.
- A persistent filestore volume stores Tryton attachments.
- Each till runs the installed GTK desktop client.
- Counters connect to the server over wired LAN where possible.
- The server and network switch are protected by a UPS.
- PostgreSQL is not exposed as a client-facing port.
- TCP 8000 is restricted to the shop LAN when additional counters are enabled.
- Daily database and filestore backups are copied to a separate encrypted
  device, and restore drills are recorded.

For multiple branches, decide explicitly between one central service accessed
over a protected WAN/VPN and a future branch-synchronisation design. Do not
create independent SQLite databases at each counter and expect them to merge.

The Compose stack in `deploy/docker` is a starting local deployment for the
8.0 LTS server plus the custom addon. It is not yet a signed installer or a
fully tested unattended Windows appliance.

## 8. Branch and upgrade policy

- `main` remains the clean upstream mirror.
- `release/8.0-lts` tracks the Tryton 8.0 LTS release line.
- `alif/production-foundation` contains Alif-owned customisation.
- Never patch upstream stock, accounting or sale-point source just to add
  showroom fields; use a separate module and supported extension hooks.
- Every upstream LTS patch update must run module tests, database migration
  tests, hardware regression tests and a restore test before rollout.
- Do not merge an upgrade or deploy it to a live store solely because a Docker
  image builds.

## 9. Production-readiness definition

This becomes production-ready only when all gates in
[GO_LIVE_CHECKLIST.md](GO_LIVE_CHECKLIST.md) have evidence. At minimum,
thermal hardware, Indian GST configuration, cashier usability, data migration,
backup restoration, role/security behaviour, 10k-SKU performance and
multi-counter concurrency must pass in a representative environment.
