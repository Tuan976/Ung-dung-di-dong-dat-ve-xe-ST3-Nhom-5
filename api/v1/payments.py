import time
import random
import os
from flask import request, current_app
from models import Booking
from extensions import db, payos_client

from . import api_v1_bp
from .errors import api_success, api_error
from .decorators import jwt_required


def _get_domain():
    return os.getenv('DOMAIN', 'http://127.0.0.1:5000')


@api_v1_bp.route('/payments/create', methods=['POST'])
@jwt_required()
def create_payment():
    user = request.current_user
    data = request.json or {}
    booking_id = data.get('booking_id')

    if not booking_id:
        return api_error(message='Vui long cung cap booking_id', error_code='MISSING_DATA', status=400)

    booking = Booking.query.filter_by(id=booking_id, user_id=user.id).first()
    if not booking:
        return api_error(message='Khong tim thay ve', error_code='BOOKING_NOT_FOUND', status=404)

    if booking.status == 'CANCELLED':
        return api_error(message='Ve da bi huy', error_code='BOOKING_CANCELLED', status=400)

    if booking.payment_status == 'Paid':
        return api_error(message='Ve da duoc thanh toan', error_code='ALREADY_PAID', status=400)

    if payos_client is None:
        return api_success(
            message='PayOS chua duoc cau hinh',
            data={
                'order_code': 999999,
                'checkout_url': None,
                'qr_code': None,
                'amount': int(booking.ticket_price),
                'description': 'Thanh toan ve ' + booking.ticket_code,
                'status': 'PENDING',
                'is_mock': True,
            }
        )

    try:
        from payos.type import ItemData, PaymentData
        order_code = int(time.time()) % 100000000 + random.randint(1, 999)
        domain = _get_domain()
        route_name = booking.trip.route.start_point + ' - ' + booking.trip.route.end_point if booking.trip else 'Ve xe khach'
        payment_data = PaymentData(
            orderCode=order_code,
            amount=int(booking.ticket_price),
            description='Ve ' + booking.ticket_code,
            items=[ItemData(name=route_name, quantity=1, price=int(booking.ticket_price))],
            returnUrl=domain + '/api/v1/payments/return',
            cancelUrl=domain + '/api/v1/payments/cancel',
        )
        response = payos_client.createPaymentLink(payment_data)
        booking.payment_id = str(order_code)
        booking.payment_method = 'PayOS'
        db.session.commit()
        return api_success(
            message='Tao lien ket thanh toan thanh cong',
            data={
                'order_code': order_code,
                'checkout_url': response.checkoutUrl,
                'qr_code': response.qrCode,
                'amount': int(booking.ticket_price),
                'description': 'Ve ' + booking.ticket_code,
                'status': 'PENDING',
                'is_mock': False,
            }
        )
    except Exception as e:
        current_app.logger.error('PayOS create error: ' + str(e))
        return api_error(message='Loi tao thanh toan: ' + str(e), error_code='PAYMENT_CREATE_ERROR', status=500)


@api_v1_bp.route('/payments/<int:booking_id>/status', methods=['GET'])
@jwt_required()
def get_payment_status(booking_id):
    user = request.current_user
    booking = Booking.query.filter_by(id=booking_id, user_id=user.id).first()
    if not booking:
        return api_error(message='Khong tim thay ve', error_code='BOOKING_NOT_FOUND', status=404)

    if booking.payment_status == 'Paid':
        return api_success(data={'payment_status': 'Paid', 'booking_status': booking.status, 'is_paid': True})

    if not booking.payment_id:
        return api_success(data={'payment_status': booking.payment_status, 'booking_status': booking.status, 'is_paid': False})

    if payos_client is None:
        return api_success(data={'payment_status': booking.payment_status, 'booking_status': booking.status, 'is_paid': False})

    try:
        payment_info = payos_client.getPaymentLinkInformation(int(booking.payment_id))
        if payment_info.status == 'PAID':
            booking.payment_status = 'Paid'
            booking.status = 'CONFIRMED'
            booking.payment_method = 'PayOS'
            db.session.commit()
            return api_success(data={'payment_status': 'Paid', 'booking_status': 'CONFIRMED', 'is_paid': True})
        return api_success(data={'payment_status': payment_info.status, 'booking_status': booking.status, 'is_paid': False})
    except Exception as e:
        return api_success(data={'payment_status': booking.payment_status, 'booking_status': booking.status, 'is_paid': False})


@api_v1_bp.route('/payments/return', methods=['GET'])
def payment_return():
    return api_success(message='Thanh toan da duoc ghi nhan.')


@api_v1_bp.route('/payments/cancel', methods=['GET'])
def payment_cancel():
    return api_error(message='Thanh toan da bi huy.', error_code='PAYMENT_CANCELLED', status=400)
