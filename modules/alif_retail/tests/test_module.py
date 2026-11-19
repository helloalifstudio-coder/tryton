# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from datetime import date
from decimal import Decimal

from trytond.model.exceptions import ValidationError
from trytond.pool import Pool
from trytond.tests.test_tryton import ModuleTestCase, with_transaction


class AlifRetailTestCase(ModuleTestCase):
    "Test Alif Retail installation and menswear-specific rules."
    module = 'alif_retail'

    @with_transaction()
    def test_measurement_profile_accepts_positive_measurements(self):
        "A customer's positive measurements can be recorded."
        pool = Pool()
        Party = pool.get('party.party')
        Profile = pool.get('alif.retail.measurement.profile')

        customer, = Party.create([{
            'name': "Test Customer",
        }])
        profile = Profile(
            customer=customer,
            name="Regular Fit",
            measured_on=date(2026, 11, 19),
            chest_cm=Decimal('98.0'),
            shoulder_cm=Decimal('45.0'),
        )
        profile.save()

        self.assertEqual(profile.chest_cm, Decimal('98.0'))
        self.assertEqual(profile.shoulder_cm, Decimal('45.0'))

    @with_transaction()
    def test_measurement_profile_rejects_non_positive_measurements(self):
        "Zero and negative dimensions must not be saved."
        pool = Pool()
        Party = pool.get('party.party')
        Profile = pool.get('alif.retail.measurement.profile')

        customer, = Party.create([{
            'name': "Test Customer",
        }])
        for value in (Decimal('0.0'), Decimal('-1.0')):
            profile = Profile(
                customer=customer,
                name="Invalid Fit",
                measured_on=date(2026, 11, 19),
                chest_cm=value,
            )
            with self.subTest(value=value):
                with self.assertRaises(ValidationError):
                    profile.save()


del ModuleTestCase, with_transaction
