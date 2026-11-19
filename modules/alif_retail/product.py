# This file is part of Alif Retail for Tryton.
# Copyright (C) 2026 Alif Growth Media
# Licensed under the GNU General Public License v3 or later.

from trytond.model import fields
from trytond.pool import PoolMeta
from trytond.pyson import Eval


class Template(metaclass=PoolMeta):
    __name__ = 'product.template'

    brand = fields.Many2One(
        'alif.retail.brand', "Brand", ondelete='RESTRICT')
    collection = fields.Many2One(
        'alif.retail.collection', "Collection",
        ondelete='RESTRICT',
        domain=[('brand', '=', Eval('brand', -1))],
        depends=['brand'])
    retail_department = fields.Selection([
            (None, ''),
            ('menswear', "Men's Wear"),
            ('kidswear', "Kids' Wear"),
            ('accessories', "Accessories"),
            ], "Retail Department")
    garment_type = fields.Selection([
            (None, ''),
            ('kurta_pyjama', "Kurta Pyjama"),
            ('pathani', "Pathani"),
            ('sherwani', "Sherwani"),
            ('suit', "Suit"),
            ('jodhpuri', "Jodhpuri"),
            ('waistcoat', "Waistcoat"),
            ('nehru_jacket', "Nehru Jacket"),
            ('shirt', "Shirt"),
            ('trouser', "Trouser"),
            ('kids_ethnic', "Kids' Ethnic Wear"),
            ('jutti', "Jutti / Footwear"),
            ('pagdi', "Pagdi / Turban"),
            ('topi', "Topi / Cap"),
            ('dupatta_stole', "Dupatta / Stole"),
            ('other', "Other"),
            ], "Garment Type")
    fabric_composition = fields.Char("Fabric / Composition")
    fit = fields.Selection([
            (None, ''),
            ('slim', "Slim"),
            ('regular', "Regular"),
            ('classic', "Classic"),
            ('relaxed', "Relaxed"),
            ('custom', "Custom"),
            ], "Fit")
    care_instructions = fields.Text("Care Instructions")
