# This file is part of Alif Retail for Tryton.
# Copyright (C) 2026 Alif Growth Media
# Licensed under the GNU General Public License v3 or later.

from trytond.i18n import gettext
from trytond.model import DeactivableMixin, ModelSQL, ModelView, Unique, fields

from .exceptions import RetailValidationError


class Brand(DeactivableMixin, ModelSQL, ModelView):
    "Retail Brand"
    __name__ = 'alif.retail.brand'
    _rec_name = 'name'

    code = fields.Char("Code", required=True, strip=True)
    name = fields.Char("Name", required=True, translate=True)

    @classmethod
    def __setup__(cls):
        super().__setup__()
        table = cls.__table__()
        cls._sql_constraints += [
            ('code_unique', Unique(table, table.code),
                'alif_retail.msg_brand_code_unique'),
            ]
        cls._order.insert(0, ('name', 'ASC'))


class Collection(DeactivableMixin, ModelSQL, ModelView):
    "Retail Collection"
    __name__ = 'alif.retail.collection'
    _rec_name = 'name'

    code = fields.Char("Code", required=True, strip=True)
    name = fields.Char("Name", required=True, translate=True)
    brand = fields.Many2One(
        'alif.retail.brand', "Brand", required=True, ondelete='RESTRICT')
    season = fields.Selection([
            (None, ''),
            ('year_round', "Year Round"),
            ('spring_summer', "Spring / Summer"),
            ('autumn_winter', "Autumn / Winter"),
            ('festive', "Festive"),
            ('wedding', "Wedding"),
            ], "Season")
    start_date = fields.Date("Start Date")
    end_date = fields.Date("End Date")

    @classmethod
    def __setup__(cls):
        super().__setup__()
        table = cls.__table__()
        cls._sql_constraints += [
            ('code_unique', Unique(table, table.code),
                'alif_retail.msg_collection_code_unique'),
            ]
        cls._order.insert(0, ('name', 'ASC'))

    @classmethod
    def validate(cls, collections):
        super().validate(collections)
        for collection in collections:
            if (collection.start_date and collection.end_date
                    and collection.start_date > collection.end_date):
                raise RetailValidationError(gettext(
                        'alif_retail.msg_collection_dates'))
