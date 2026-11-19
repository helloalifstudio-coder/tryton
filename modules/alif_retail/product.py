# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from trytond.model import fields
from trytond.pool import PoolMeta


class Template(metaclass=PoolMeta):
    __name__ = 'product.template'

    brand = fields.Many2One(
        'alif.retail.brand', "Brand",
        help="Brand or label associated with this garment style.")
    collection = fields.Many2One(
        'alif.retail.collection', "Collection",
        help="Seasonal or named collection for this garment style.")
    gender = fields.Selection([
        (None, ""),
        ('men', "Men"),
        ('boys', "Boys"),
        ('unisex', "Unisex"),
        ], "Audience")
    garment_type = fields.Selection([
        (None, ""),
        ('kurta_pyjama', "Kurta Pyjama"),
        ('pathani', "Pathani"),
        ('sherwani', "Sherwani"),
        ('suit', "Suit"),
        ('jodhpuri', "Jodhpuri"),
        ('waistcoat', "Waistcoat"),
        ('shirt', "Shirt"),
        ('trouser', "Trouser"),
        ('accessory', "Accessory"),
        ('footwear', "Footwear"),
        ('other', "Other"),
        ], "Garment Type")
    fabric = fields.Char(
        "Fabric",
        help="Fabric description, for example: silk blend, cotton or linen.")
    season = fields.Char(
        "Season",
        help="Season or buying period, for example: Wedding 2026.")
