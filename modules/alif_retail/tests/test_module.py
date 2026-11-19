# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from datetime import date
from decimal import Decimal

from lxml import etree

from trytond.exceptions import UserError
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

        with Transaction().set_context(_check_access=True), Transaction().set_user(cashier.id):
            # The cashier can identify/select the profile for an alteration.
            Profile.read([profile.id], ['name'])
            with self.assertRaises(AccessError):
                Profile.read([profile.id], ['chest_cm'])
            with self.assertRaises(AccessError):
                Profile.read([profile.id], ['notes'])

        with Transaction().set_context(_check_access=True), Transaction().set_user(measurement_user.id):
            record, = Profile.read([profile.id], ['chest_cm'])
            self.assertEqual(record['chest_cm'], Decimal('100.0'))


    @with_transaction()
    def test_pos_form_enables_native_repeat_scanning(self):
        "The POS form advertises scanner support only while a sale is open."
        Sale = Pool().get('sale.point.sale')
        view = Sale.fields_view_get(view_type='form')
        root = etree.fromstring(view['arch'])

        self.assertEqual(root.get('scan_code'), 'loop')
        self.assertEqual(root.get('scan_code_depends'), 'lines,state')
        self.assertTrue(root.get('scan_code_states'))

    @with_transaction()
    def test_pos_scanner_adds_and_increments_variant(self):
        "A barcode adds one variant line and repeat scans increment quantity."
        pool = Pool()
        Uom = pool.get('product.uom')
        Template = pool.get('product.template')
        Product = pool.get('product.product')
        Identifier = pool.get('product.identifier')
        Sale = pool.get('sale.point.sale')

        unit, = Uom.search([], limit=1)
        template = Template(
            name="Scanner Test Sherwani",
            default_uom=unit,
            salable=True,
            sale_uom=unit,
        )
        template.save()
        product = Product(template=template)
        product.identifiers = [Identifier(code="ALIF-SCAN-TEST-001")]
        product.save()

        sale = Sale(state='open', lines=[])
        sale.on_scan_code("ALIF-SCAN-TEST-001")
        self.assertEqual(len(sale.lines), 1)
        self.assertEqual(sale.lines[0].product, product)
        self.assertEqual(sale.lines[0].unit, product.sale_uom)
        self.assertEqual(sale.lines[0].quantity, 1)

        sale.on_scan_code("ALIF-SCAN-TEST-001")
        self.assertEqual(len(sale.lines), 1)
        self.assertEqual(sale.lines[0].quantity, 2)

    @with_transaction()
    def test_pos_scanner_rejects_unknown_barcode(self):
        "An unknown barcode must never silently create a sale line."
        Sale = Pool().get('sale.point.sale')
        sale = Sale(state='open', lines=[])

        with self.assertRaises(UserError):
            sale.on_scan_code("UNKNOWN-ALIF-BARCODE")

    @with_transaction()
    def test_pos_scanner_requires_open_sale(self):
        "A posted or completed sale must not be changed by scanning."
        Sale = Pool().get('sale.point.sale')
        sale = Sale(state='posted', lines=[])

        with self.assertRaises(UserError):
            sale.on_scan_code("ALIF-SCAN-TEST-001")


del ModuleTestCase, with_transaction
