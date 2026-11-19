# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from trytond.exceptions import UserError
from trytond.i18n import gettext
from trytond.model import fields
from trytond.pool import Pool, PoolMeta


class POSSale(metaclass=PoolMeta):
    __name__ = 'sale.point.sale'

    @fields.depends('lines', 'state')
    def on_scan_code(self, code):
        "Add a sellable product variant to the open sale from its SKU/barcode."
        if self.state != 'open':
            raise UserError(gettext('alif_retail.msg_pos_sale_not_open'))

        code = (code or '').strip()
        if not code:
            return

        Product = Pool().get('product.product')
        products = Product.search([
            ('active', '=', True),
            ('salable', '=', True),
            ['OR',
                ('code', '=', code),
                ('identifiers.code', '=', code),
                ],
            ], limit=2)

        if not products:
            raise UserError(gettext(
                'alif_retail.msg_barcode_unknown', code=code))
        if len(products) > 1:
            raise UserError(gettext(
                'alif_retail.msg_barcode_ambiguous', code=code))

        product, = products
        SaleLine = Pool().get('sale.point.sale.line')
        line = next(
            (line for line in self.lines if line.product == product),
            None)
        if line is None:
            line = SaleLine()
            line.sale = self
            line.product = product
            line.quantity = 1
            self.lines.append(line)
        else:
            line.quantity += 1

        # Resolve the sale unit before applying the upstream POS pricing/tax
        # calculation. Stock moves require this unit when the sale is posted.
        line.unit = line.on_change_with_unit()
        # Never copy a price from the scanner or from the client.
        line.on_change_product()
