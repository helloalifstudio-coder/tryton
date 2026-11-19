# This file is part of the Alif Retail extension for Tryton.

from trytond.tests.test_tryton import ModuleTestCase


class AlifRetailTestCase(ModuleTestCase):
    "Test Alif Retail module installation and model registration."
    module = 'alif_retail'


del ModuleTestCase
