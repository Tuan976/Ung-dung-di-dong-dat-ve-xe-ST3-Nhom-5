from flask import request
from models import Booking, Trip, PassengerSOS
from extensions import db
from extensions import db
import string
import random
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timedelta

from . import api_v1_bp
from .errors import api_success, api_error
from .decorators import jwt_required

def generate_ticket_code():
    return 'HT' + ''.join(random.choices(string.digits, k=8))

@api_v1_bp.route('/bookings', methods=['POST'])
@jwt_required()
def create_booking():
    user = request.current_user
    data = request.json or {}
    
    trip_id = data.get('trip_id')
    seat_number = data.get('seat_number')
    passenger_name = data.get('passenger_name')
    passenger_phone = data.get('passenger_phone')
    pickup_point = data.get('pickup_point', '')
    dropoff_point = data.get('dropoff_point', '')

    if not all([trip_id, seat_number, passenger_name, passenger_phone]):
        return api_error(message="Vui lòng cung cấp đầy đủ thông tin", error_code="MISSING_DATA", status=400)

    # Locking the trip record to prevent concurrent bookings
    trip = Trip.query.with_for_update().get(trip_id)
    if not trip:
        return api_error(message="Không tìm thấy chuyến xe", error_code="TRIP_NOT_FOUND", status=404)

    if trip.status != 'Scheduled':
        return api_error(message="Chuyến xe không còn khả dụng", error_code="TRIP_UNAVAILABLE", status=400)

    # Check if seat is already booked
    existing_booking = Booking.query.filter_by(trip_id=trip_id, seat_number=seat_number).filter(
        Booking.status.in_(['CONFIRMED', 'HOLD'])
    ).first()

    if existing_booking:
        return api_error(message=f"Ghế {seat_number} đã được đặt", error_code="SEAT_TAKEN", status=409)

    ticket_price = trip.route.base_price * trip.price_multiplier

    new_booking = Booking(
        ticket_code=generate_ticket_code(),
        trip_id=trip_id,
        user_id=user.id,
        seat_number=seat_number,
        passenger_name=passenger_name,
        passenger_phone=passenger_phone,
        pickup_point=pickup_point,
        dropoff_point=dropoff_point,
        status='HOLD',
        expires_at=datetime.now() + timedelta(minutes=15),
        ticket_price=ticket_price,
        payment_status='Unpaid'
    )

    try:
        db.session.add(new_booking)
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return api_error(message="Lỗi khi tạo booking. Vui lòng thử lại.", error_code="DATABASE_ERROR", status=500)

    return api_success(
        message="Đặt chỗ thành công",
        data={
            "booking_id": new_booking.id,
            "ticket_code": new_booking.ticket_code,
            "status": new_booking.status,
            "expires_at": new_booking.expires_at.isoformat() if new_booking.expires_at else None
        },
        status=201
    )

@api_v1_bp.route('/bookings', methods=['GET'])
@jwt_required()
def get_user_bookings():
    user = request.current_user
    page = request.args.get('page', 1, type=int)
    limit = request.args.get('limit', 20, type=int)
    status = request.args.get('status')

    query = Booking.query.filter_by(user_id=user.id)
    if status:
        query = query.filter_by(status=status)

    query = query.order_by(Booking.booking_time.desc())
    paginated = query.paginate(page=page, per_page=limit, error_out=False)

    items = []
    for b in paginated.items:
        items.append({
            "id": b.id,
            "ticket_code": b.ticket_code,
            "seat_number": b.seat_number,
            "passenger_name": b.passenger_name,
            "passenger_phone": b.passenger_phone,
            "booking_time": b.booking_time.isoformat(),
            "status": b.status,
            "payment_status": b.payment_status,
            "ticket_price": b.ticket_price,
            "expires_at": b.expires_at.isoformat() if b.expires_at else None,
            "trip": {
                "id": b.trip.id,
                "departure_time": b.trip.departure_time.isoformat(),
                "start_point": b.trip.route.start_point,
                "end_point": b.trip.route.end_point,
                "company_name": b.trip.route.company.name
            }
        })

    return api_success(
        data={
            "items": items,
            "pagination": {
                "page": paginated.page,
                "limit": paginated.per_page,
                "total": paginated.total,
                "total_pages": paginated.pages
            }
        }
    )


@api_v1_bp.route('/bookings/<int:booking_id>', methods=['GET'])
@jwt_required()
def get_booking_detail(booking_id):
    user = request.current_user
    booking = Booking.query.filter_by(id=booking_id, user_id=user.id).first()
    if not booking:
        return api_error(message="Không tìm thấy vé", error_code="BOOKING_NOT_FOUND", status=404)

    return api_success(
        data={
            "id": booking.id,
            "ticket_code": booking.ticket_code,
            "seat_number": booking.seat_number,
            "passenger_name": booking.passenger_name,
            "passenger_phone": booking.passenger_phone,
            "booking_time": booking.booking_time.isoformat(),
            "status": booking.status,
            "payment_status": booking.payment_status,
            "ticket_price": booking.ticket_price,
            "expires_at": booking.expires_at.isoformat() if booking.expires_at else None,
            "payment_id": booking.payment_id,
            "trip": {
                "id": booking.trip.id,
                "departure_time": booking.trip.departure_time.isoformat(),
                "arrival_time": booking.trip.arrival_time.isoformat() if booking.trip.arrival_time else None,
                "start_point": booking.trip.route.start_point,
                "end_point": booking.trip.route.end_point,
                "company_name": booking.trip.route.company.name
            }
        }
    )


@api_v1_bp.route('/bookings/<int:booking_id>/cancel', methods=['POST'])
@jwt_required()
def cancel_booking(booking_id):
    user = request.current_user
    booking = Booking.query.filter_by(id=booking_id, user_id=user.id).first()
    if not booking:
        return api_error(message="Không tìm thấy vé", error_code="BOOKING_NOT_FOUND", status=404)

    if booking.status == 'CANCELLED':
        return api_error(message="Vé đã bị hủy trước đó", error_code="ALREADY_CANCELLED", status=400)

    if booking.status == 'CONFIRMED' and booking.payment_status == 'Paid':
        # For paid bookings: allow cancellation but note refund is manual
        booking.status = 'CANCELLED'
        booking.payment_status = 'Refund_Pending'
    elif booking.status in ['HOLD', 'CONFIRMED']:
        booking.status = 'CANCELLED'
    else:
        return api_error(message="Không thể hủy vé ở trạng thái này", error_code="CANNOT_CANCEL", status=400)

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        return api_error(message="Lỗi khi hủy vé", error_code="DATABASE_ERROR", status=500)

    return api_success(message="Hủy vé thành công", data={"status": booking.status})


@api_v1_bp.route('/sos', methods=['POST'])
def send_sos():
    # Lấy user từ token nếu có (không bắt buộc - đây là tính năng khẩn cấp)
    user = None
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        try:
            import jwt as _jwt, os as _os
            token = auth_header.split(' ')[1]
            secret = _os.getenv('JWT_SECRET_KEY', 'local-dev-jwt-secret-key-12345')
            payload = _jwt.decode(token, secret, algorithms=['HS256'])
            from models import User
            user = User.query.get(payload.get('sub'))
        except Exception:
            pass

    data = request.json or {}
    lat = data.get('lat')
    lng = data.get('lng')
    msg = data.get('message', 'SOS! Hành khách gặp nguy hiểm.')

    try:
        new_sos = PassengerSOS(
            user_id=user.id if user else None,
            passenger_name=user.name if user else data.get('name', 'Ẩn danh'),
            passenger_phone=user.phone if user else data.get('phone', 'Không rõ'),
            latitude=float(lat) if lat is not None else 0.0,
            longitude=float(lng) if lng is not None else 0.0,
            message=msg
        )
        db.session.add(new_sos)
        db.session.commit()
        return api_success({
            "message": "Tín hiệu SOS đã được gửi đến nhà xe và cơ quan chức năng! Hãy giữ an toàn, chúng tôi đang tới.", 
            "received": True
        })
    except Exception as e:
        db.session.rollback()
        return api_error(message=f"Lỗi lưu SOS: {str(e)}", error_code="SOS_ERROR", status=500)

@api_v1_bp.route('/sos_alerts', methods=['GET'])
def get_sos_alerts():
    # Only return PENDING alerts for admin dashboard polling
    alerts = PassengerSOS.query.filter_by(status='PENDING').order_by(PassengerSOS.created_at.desc()).all()
    
    results = []
    for a in alerts:
        results.append({
            "id": a.id,
            "user_id": a.user_id,
            "passenger_name": a.passenger_name,
            "passenger_phone": a.passenger_phone,
            "latitude": a.latitude,
            "longitude": a.longitude,
            "message": a.message,
            "created_at": a.created_at.isoformat() if a.created_at else None
        })
        
    return api_success(results)

@api_v1_bp.route('/sos_alerts/<int:sos_id>/resolve', methods=['POST'])
def resolve_sos_alert(sos_id):
    alert = PassengerSOS.query.get(sos_id)
    if not alert:
        return api_error("Alert not found", status_code=404)
        
    alert.status = 'RESOLVED'
    alert.resolved_at = datetime.utcnow()
    # In a real app, we'd record the staff ID from token
    db.session.commit()
    
    return api_success({"message": "Alert resolved"})
