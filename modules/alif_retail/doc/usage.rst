Usage
=====

Initial configuration
---------------------

#. Install and activate the alif_retail module with its dependencies.
#. Create brand records with a stable short code.
#. Create collections and optionally associate a brand and season.
#. Configure an attribute set such as Apparel Variant with Size, Colour and
   Fit attributes.
#. Assign that attribute set to garment product templates.
#. Create one product variant per sellable size-colour-fit combination.
#. Assign each product variant a unique internal code and barcode identifier.
#. Assign Retail User, Retail Manager and Customer Measurements groups to
   named users according to their responsibilities.

Example catalogue
-----------------

A style such as NB-SHW-104 may have the following variants:

* NB-SHW-104-IV-38 — Ivory, size 38.
* NB-SHW-104-IV-40 — Ivory, size 40.
* NB-SHW-104-MR-38 — Maroon, size 38.

The actual code format is a showroom policy; Tryton does not impose the
example format. The important rule is that every sellable variant has a
distinct code and barcode.

Receiving stock
---------------

Use standard Tryton Purchase and Stock workflows. Confirm the purchase,
receive the incoming shipment, and verify that the expected variant
quantities are present in the correct storage location. Do not adjust stock
by editing a displayed quantity: use a stock move or inventory count so the
stock ledger remains auditable.

Billing
-------

Configure a POS point, its storage location, customer location, revenue
journal, tax configuration and payment methods. A POS sale must be paid
before it can be completed. Posting the POS sale creates its stock movements
and accounting move. Reconcile cash sessions as part of the cashier close
procedure.

The POS sale form has a native GTK scan-code dialog. Connect a USB barcode
scanner in keyboard-wedge mode, focus the scanner entry, and scan the
variant's internal SKU or product identifier. A matching active, salable
variant is added to the current open sale; repeated scans increment the
quantity on the existing line. Unknown and ambiguous codes are rejected.
The scanner does not set a price: Tryton calculates the POS price and taxes.

This is a scan-to-cart workflow on Tryton's generic POS form, not yet a
dedicated touchscreen cashier interface. Direct ESC/POS thermal receipt
printing, cash-drawer control and physical hardware compatibility tests
remain outstanding.

Alterations
-----------

Create an alteration order for the customer and garment, add a measurement
profile when required, record the promised date and instructions, and move
the order through the workflow. A linked POS line provides traceability to
the garment sale; it is not a second sale or a charge.
