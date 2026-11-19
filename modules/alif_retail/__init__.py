# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from trytond.pool import Pool

from . import product, retail


def register():
    Pool.register(
        product.Template,
        retail.Brand,
        retail.Collection,
        retail.MeasurementProfile,
        retail.AlterationOrder,
        module='alif_retail', type_='model')
