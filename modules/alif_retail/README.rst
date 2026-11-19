Alif Retail for Tryton
======================

This module adds an initial men's apparel showroom layer on top of Tryton 8.0
LTS. It does not replace Tryton's stock, purchase, accounting, sale or
point-of-sale engines.

Included in this foundation
---------------------------

* Garment metadata on product templates: brand, collection, audience,
  garment type, fabric and season.
* Brand and collection master data.
* Customer measurement profiles stored in centimetres.
* Alteration and tailoring work orders with explicit workflow states.
* Separate access groups for retail staff, retail managers and customer
  measurements.

Product variants, SKUs, barcodes, inventory quantities, purchase receipts,
POS sales, payment methods, cash sessions, stock movements and accounting
entries continue to use upstream Tryton models.

The POS form adds Tryton's native GTK scan-code dialog. A USB barcode scanner
configured as a keyboard-wedge device can enter the code into that dialog.
The server resolves the code against a sellable variant SKU or product
identifier, adds the exact variant to the open POS sale, and increments its
quantity on repeat scans. Prices and taxes are calculated by the upstream
POS line model, not supplied by the scanner.

Clothing variant setup
----------------------

Create a product attribute set named 'Apparel Variant' and add attributes
such as 'Size', 'Colour' and 'Fit'. Assign this attribute set to each garment
template. Create a distinct product variant for each sellable combination,
for example Sherwani / Ivory / 38 and Sherwani / Maroon / 40.

Give every sellable variant its own internal product code and barcode
identifier. Do not use one barcode for all sizes or colours of a design.
The product template is the style; its product variants are the stockable
units.

Customer measurements are protected at both menu and field level. Ordinary
retail users can select a saved profile for an alteration but cannot read the
body dimensions or private notes. Only the Customer Measurements and Retail
Manager groups can open the measurements screen and read/write those fields.
Assign these groups only to staff who need that data.

Not yet implemented
-------------------

This is a foundational module, not a certified retail deployment. It does not
yet provide India GST localisation, ESC/POS thermal receipt printing, cash
drawer / scanner device management, customer-facing returns policy screens,
a dedicated cashier UI, branch replication, automated backup verification
or a signed Windows installer. These need separate implementation and
acceptance testing before live store use.
