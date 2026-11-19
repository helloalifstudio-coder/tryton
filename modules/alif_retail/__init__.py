# This file is part of Alif Retail for Tryton.
# Copyright (C) 2026 Alif Growth Media
# Licensed under the GNU General Public License v3 or later.

from trytond.pool import Pool

from . import brand, product


def register():
    Pool.register(
        brand.Brand,
        brand.Collection,
        product.Template,
        module='alif_retail', type_='model')
