# This file is part of the Alif Retail extension for Tryton.
# See COPYRIGHT and LICENSE for applicable license terms.

from trytond.model import (
    DeactivableMixin, ModelSQL, ModelView, Unique, Workflow, fields)
from trytond.model.exceptions import ValidationError
from trytond.pool import Pool
from trytond.i18n import gettext
from trytond.pyson import Eval


class Brand(DeactivableMixin, ModelSQL, ModelView):
    "Retail Brand"
    __name__ = 'alif.retail.brand'

    name = fields.Char("Name", required=True, translate=True)
    code = fields.Char("Code", required=True)

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

    name = fields.Char("Name", required=True, translate=True)
    code = fields.Char("Code", required=True)
    brand = fields.Many2One(
        'alif.retail.brand', "Brand",
        help="Leave empty when the collection spans multiple brands.")
    season = fields.Char("Season")

    @classmethod
    def __setup__(cls):
        super().__setup__()
        table = cls.__table__()
        cls._sql_constraints += [
            ('code_unique', Unique(table, table.code),
                'alif_retail.msg_collection_code_unique'),
        ]
        cls._order.insert(0, ('name', 'ASC'))


class MeasurementProfile(ModelSQL, ModelView):
    "Customer Measurement Profile"
    __name__ = 'alif.retail.measurement.profile'

    customer = fields.Many2One(
        'party.party', "Customer", required=True, ondelete='CASCADE')
    name = fields.Char("Profile Name", required=True)
    measured_on = fields.Date("Measured On", required=True)
    notes = fields.Text("Notes")
    chest_cm = fields.Numeric("Chest (cm)", digits=(6, 1))
    shoulder_cm = fields.Numeric("Shoulder (cm)", digits=(6, 1))
    sleeve_cm = fields.Numeric("Sleeve (cm)", digits=(6, 1))
    neck_cm = fields.Numeric("Neck (cm)", digits=(6, 1))
    waist_cm = fields.Numeric("Waist (cm)", digits=(6, 1))
    hip_cm = fields.Numeric("Hip (cm)", digits=(6, 1))
    inseam_cm = fields.Numeric("Inseam (cm)", digits=(6, 1))
    kurta_length_cm = fields.Numeric("Kurta Length (cm)", digits=(6, 1))
    active = fields.Boolean("Active")

    @staticmethod
    def default_active():
        return True

    @classmethod
    def __setup__(cls):
        super().__setup__()
        cls._order.insert(0, ('measured_on', 'DESC'))

    @classmethod
    def validate(cls, profiles):
        super().validate(profiles)
        dimensions = (
            'chest_cm', 'shoulder_cm', 'sleeve_cm', 'neck_cm',
            'waist_cm', 'hip_cm', 'inseam_cm', 'kurta_length_cm')
        for profile in profiles:
            for dimension in dimensions:
                value = getattr(profile, dimension)
                if value is not None and value <= 0:
                    raise ValidationError(gettext(
                        'alif_retail.msg_measurement_must_be_positive',
                        field=dimension))


class AlterationOrder(Workflow, ModelSQL, ModelView):
    "Garment Alteration / Tailoring Order"
    __name__ = 'alif.retail.alteration'
    _rec_name = 'number'

    number = fields.Char("Order Number", readonly=True, required=True)
    customer = fields.Many2One(
        'party.party', "Customer", required=True, ondelete='RESTRICT')
    product = fields.Many2One(
        'product.product', "Garment", required=True, ondelete='RESTRICT')
    sale_line = fields.Many2One(
        'sale.point.sale.line', "POS Sale Line", ondelete='SET NULL',
        help="Optional source sale line for traceability.")
    measurement_profile = fields.Many2One(
        'alif.retail.measurement.profile', "Measurement Profile",
        ondelete='RESTRICT',
        domain=[('customer', '=', Eval('customer', -1))])
    received_on = fields.Date("Received On", required=True)
    due_date = fields.Date("Promised Date", required=True)
    instructions = fields.Text("Alteration Instructions")
    state = fields.Selection([
        ('draft', "Draft"),
        ('confirmed', "Confirmed"),
        ('in_progress', "In Progress"),
        ('ready', "Ready"),
        ('delivered', "Delivered"),
        ('cancelled', "Cancelled"),
        ], "Status", required=True, readonly=True)

    @classmethod
    def __setup__(cls):
        super().__setup__()
        table = cls.__table__()
        cls._sql_constraints += [
            ('number_unique', Unique(table, table.number),
                'alif_retail.msg_alteration_number_unique'),
        ]
        cls._transitions |= {
            ('draft', 'confirmed'),
            ('draft', 'cancelled'),
            ('confirmed', 'in_progress'),
            ('confirmed', 'cancelled'),
            ('in_progress', 'ready'),
            ('in_progress', 'cancelled'),
            ('ready', 'delivered'),
            ('ready', 'in_progress'),
        }
        cls._buttons.update({
            'confirm': {
                'invisible': Eval('state') != 'draft',
                'depends': ['state'],
            },
            'start': {
                'invisible': Eval('state') != 'confirmed',
                'depends': ['state'],
            },
            'mark_ready': {
                'invisible': Eval('state') != 'in_progress',
                'depends': ['state'],
            },
            'deliver': {
                'invisible': Eval('state') != 'ready',
                'depends': ['state'],
            },
            'cancel': {
                'invisible': ~Eval('state').in_(
                    ['draft', 'confirmed', 'in_progress']),
                'depends': ['state'],
            },
        })

    @staticmethod
    def default_state():
        return 'draft'

    @staticmethod
    def default_received_on():
        return Pool().get('ir.date').today()

    @classmethod
    def preprocess_values(cls, mode, values):
        values = super().preprocess_values(mode, values)
        if mode == 'create' and not values.get('number'):
            ModelData = Pool().get('ir.model.data')
            Sequence = Pool().get('ir.sequence.strict')
            sequence_id = ModelData.get_id(
                'alif_retail', 'sequence_alteration')
            values['number'] = Sequence(sequence_id).get()
        return values

    @classmethod
    def validate(cls, orders):
        super().validate(orders)
        for order in orders:
            if order.due_date and order.received_on:
                if order.due_date < order.received_on:
                    raise ValidationError(gettext(
                        'alif_retail.msg_due_date_before_received'))
            if (order.measurement_profile
                    and order.measurement_profile.customer != order.customer):
                raise ValidationError(gettext(
                    'alif_retail.msg_measurement_customer_mismatch'))
            if (order.sale_line
                    and order.sale_line.product != order.product):
                raise ValidationError(gettext(
                    'alif_retail.msg_alteration_sale_line_product_mismatch'))

    @classmethod
    @ModelView.button
    @Workflow.transition('confirmed')
    def confirm(cls, orders):
        pass

    @classmethod
    @ModelView.button
    @Workflow.transition('in_progress')
    def start(cls, orders):
        pass

    @classmethod
    @ModelView.button
    @Workflow.transition('ready')
    def mark_ready(cls, orders):
        pass

    @classmethod
    @ModelView.button
    @Workflow.transition('delivered')
    def deliver(cls, orders):
        pass

    @classmethod
    @ModelView.button
    @Workflow.transition('cancelled')
    def cancel(cls, orders):
        pass
