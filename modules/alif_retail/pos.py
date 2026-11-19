# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from trytond.exceptions import UserError
from lxml import etree

from trytond.i18n import gettext
from trytond.model import fields
from trytond.pool import Pool, PoolMeta
from trytond.pyson import Eval, PYSONEncoder


class POSSale(metaclass=PoolMeta):
    __name__ = 'sale.point.sale'

    _open_states = {
        'readonly': Eval('state') != 'open',
    }

    customer = fields.Many2One(
        'party.party', "Customer",
        ondelete='RESTRICT',
        states=_open_states,
        depends={'state'},
        help="Optional customer for CRM, alterations and transaction history.")


    @classmethod
    def fields_view_get(cls, view_id=None, view_type='form', level=None):
        "Enable repeat barcode scanning on the native GTK POS form."
        result = super().fields_view_get(
            view_id=view_id, view_type=view_type, level=level)
        if view_type == 'form' and result.get('arch'):
            result = result.copy()
            root = etree.fromstring(result['arch'])
            root.set('scan_code', 'loop')
            root.set('scan_code_depends', 'lines,state')
            root.set('scan_code_states', PYSONEncoder().encode({
                'readonly': Eval('state') != 'open',
            }))
            result['arch'] = etree.tostring(root, encoding='unicode')
        return result

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
