# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from datetime import date
from decimal import Decimal

from trytond.model.exceptions import AccessError, ValidationError
from trytond.pool import Pool
from trytond.tests.test_tryton import ModuleTestCase, with_transaction
from trytond.transaction import Transaction


class AlifRetailTestCase(ModuleTestCase):
    "Test Alif Retail installation, privacy and menswear-specific rules."
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

    @with_transaction()
    def test_measurement_profile_fields_are_role_restricted(self):
        "Cashiers may select a profile; authorised staff may read dimensions."
        pool = Pool()
        Party = pool.get('party.party')
        Profile = pool.get('alif.retail.measurement.profile')
        User = pool.get('res.user')
        Group = pool.get('res.group')

        customer, = Party.create([{
            'name': "Privacy Test Customer",
        }])
        profile = Profile(
            customer=customer,
            name="Privacy Test",
            measured_on=date(2026, 11, 19),
            chest_cm=Decimal('100.0'),
        )
        profile.save()

        retail_group, = Group.search([
            ('name', '=', "Retail User"),
        ], limit=1)
        measurements_group, = Group.search([
            ('name', '=', "Customer Measurements"),
        ], limit=1)

        cashier = User(
            login="retail-cashier-privacy-test",
            name="Retail Cashier",
            groups=[retail_group],
        )
        cashier.save()
        measurement_user = User(
            login="retail-measurements-privacy-test",
            name="Measurements Staff",
            groups=[measurements_group],
        )
        measurement_user.save()

        with Transaction().set_user(cashier.id):
            # The cashier can identify/select the profile for an alteration.
            Profile.read([profile.id], ['name'])
            with self.assertRaises(AccessError):
                Profile.read([profile.id], ['chest_cm'])
            with self.assertRaises(AccessError):
                Profile.read([profile.id], ['notes'])

        with Transaction().set_user(measurement_user.id):
            record, = Profile.read([profile.id], ['chest_cm'])
            self.assertEqual(record['chest_cm'], Decimal('100.0'))


del ModuleTestCase, with_transaction
