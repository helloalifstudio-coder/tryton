# This file is part of Alif Retail for Tryton.
# Copyright (C) 2026 Alif Growth Media
# Licensed under the GNU General Public License v3 or later.

import datetime

from trytond.modules.alif_retail.exceptions import RetailValidationError
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

    @with_transaction()
    def test_collection_date_validation(self):
        "Reject a collection whose end date is before its start date"
        pool = Pool()
        Brand = pool.get('alif.retail.brand')
        Collection = pool.get('alif.retail.collection')

        brand, = Brand.create([{
                    'code': 'NB-DATE',
                    'name': 'Date Test Brand',
                    }])
        with self.assertRaises(RetailValidationError):
            Collection.create([{
                        'code': 'NB-INVALID-DATES',
                        'name': 'Invalid Date Range',
                        'brand': brand.id,
                        'start_date': datetime.date(2026, 12, 1),
                        'end_date': datetime.date(2026, 11, 1),
                        }])

    @with_transaction()
    def test_product_collection_brand_validation(self):
        "Reject assigning a collection from a different brand"
        pool = Pool()
        Brand = pool.get('alif.retail.brand')
        Collection = pool.get('alif.retail.collection')
        Template = pool.get('product.template')

        brand_a, = Brand.create([{
                    'code': 'NB-A',
                    'name': 'Brand A',
                    }])
        brand_b, = Brand.create([{
                    'code': 'NB-B',
                    'name': 'Brand B',
                    }])
        collection, = Collection.create([{
                    'code': 'NB-B-COLLECTION',
                    'name': 'Brand B Collection',
                    'brand': brand_b.id,
                    }])
        template = Template()
        template.brand = brand_a
        template.collection = collection

        with self.assertRaises(RetailValidationError):
            Template.validate([template])


del ModuleTestCase
