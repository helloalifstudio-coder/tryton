# This file is part of Alif Retail for Tryton.
# Copyright (C) 2026 Alif Growth Media
# Licensed under the GNU General Public License v3 or later.

from trytond.pool import Pool
from trytond.tests.test_tryton import ModuleTestCase, with_transaction


class AlifRetailTestCase(ModuleTestCase):
    "Test Alif Retail module"
    module = 'alif_retail'

    @with_transaction()
    def test_brand_and_collection(self):
        "Test brand and collection records"
        pool = Pool()
        Brand = pool.get('alif.retail.brand')
        Collection = pool.get('alif.retail.collection')

        brand, = Brand.create([{
                    'code': 'NB',
                    'name': 'Noman Brothers',
                    }])
        collection, = Collection.create([{
                    'code': 'NB-WED-26',
                    'name': 'Wedding 2026',
                    'brand': brand.id,
                    'season': 'wedding',
                    }])

        self.assertEqual(collection.brand.id, brand.id)
        self.assertEqual(collection.code, 'NB-WED-26')


del ModuleTestCase
