Design
======

The module extends standard Tryton product templates and introduces a small
number of retail-specific models. It does not fork the upstream product,
stock, sale, accounting or POS models.

Product model
-------------

product.template represents a garment style. Alif Retail adds brand,
collection, audience, garment type, fabric and season metadata.

product.product remains the sellable stock variant. Use the upstream
product_attribute module to define Size, Colour and Fit attributes. A
separate variant must exist for every stockable combination. Each variant
retains its own product code and product identifiers (barcodes).

This distinction is fundamental: a sherwani style is not a stock balance.
The size-colour variant is the stockable unit.

Measurement profiles
--------------------

alif.retail.measurement.profile stores customer measurements in centimetres.
It validates that supplied dimensions are positive and links each profile
to one customer.

Only Customer Measurements and Retail Manager roles can open the dedicated
measurement menu or read/write detailed dimensions and private notes. Retail
users have read-only access to profile identity so they can link a profile to
an alteration order, but field-level access rules hide all body measurements
and notes. This lets a cashier select the correct customer profile without
gaining access to sensitive measurements.

Alteration workflow
-------------------

alif.retail.alteration stores the customer, garment, optional originating
POS line, optional customer measurement profile, received date, promised
date and work instructions.

Allowed state transitions are:

* Draft to Confirmed or Cancelled.
* Confirmed to In Progress or Cancelled.
* In Progress to Ready or Cancelled.
* Ready to Delivered or back to In Progress.

The model validates the promised date and ensures a linked measurement
profile belongs to the selected customer. If a POS line is linked, its
product must match the garment on the alteration record.

The alteration order is an operational work order. It does not yet create a
separate charge, invoice or stock movement. Any alteration fee must be
entered through a configured sale/POS workflow until a dedicated billing
integration has been designed and tested.

Security and scope
------------------

Model access is deny-by-default, then granted by role. The module does not
publish measurement fields to public interfaces. Tryton's authenticated RPC
and REST layers still apply their normal model and field access checks.

The current module is a first vertical slice. GST localisation, receipt
printing, hardware orchestration, tailored cashier views and multi-branch
replication are not part of this module version.
