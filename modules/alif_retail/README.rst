Alif Retail for Tryton
======================

This module adds apparel-showroom metadata to Tryton product templates:

* Brand and collection master data.
* Men's wear, kids' wear and accessories departments.
* Garment types relevant to ethnic and occasion wear.
* Fabric composition, fit and care-instruction fields.

Size and colour are intentionally represented by Tryton's existing
product_attribute variant model. Each saleable size/colour combination
must be a distinct product.product variant with its own internal code
and barcode identifier. The module does not create a second stock ledger,
SKU system, POS, accounting engine or customer database.

The module is an initial vertical extension, not a complete showroom release.
See docs/production for the target architecture and acceptance gates.
