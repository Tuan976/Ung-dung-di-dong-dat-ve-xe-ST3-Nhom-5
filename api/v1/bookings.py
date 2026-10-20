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
    for _ in range(10):
        code = 'HT' + ''.join(random.choices(string.digits, k=8))
        if not Booking.query.filter_by(ticket_code=code).first():
            return code
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
    pickup_station_id = data.get('pickup_station_id')
    dropoff_station_id = data.get('dropoff_station_id')

    if pickup_station_id or dropoff_station_id:
        from .map_routes import STATIONS_DATA
        if pickup_station_id:
            st = next((s for s in STATIONS_DATA if s['id'] == pickup_station_id and s['is_active']), None)
            if not st:
                return api_error(message="Điểm đón được chọn không hợp lệ hoặc đã ngừng hoạt động", error_code="INVALID_PICKUP_STATION", status=400)
            if not pickup_point:
                pickup_point = f"{st['name']} ({st['address']})"
        if dropoff_station_id:
            st = next((s for s in STATIONS_DATA if s['id'] == dropoff_station_id and s['is_active']), None)
            if not st:
                return api_error(message="Điểm đến được chọn không hợp lệ hoặc đã ngừng hoạt động", error_code="INVALID_DROPOFF_STATION", status=400)
            if not dropoff_point:
                dropoff_point = f"{st['name']} ({st['address']})"

    if not all([trip_id, seat_number, passenger_name, passenger_phone]):
        return api_error(message="Vui lòng cung cấp đầy đủ thông tin", error_code="MISSING_DATA", status=400)

    # Locking the trip record to prevent concurrent bookings
    trip = Trip.query.with_for_update().get(trip_id)
    if not trip:
        return api_error(message="Không tìm thấy chuyến xe", error_code="TRIP_NOT_FOUND", status=404)

    if trip.status != 'Scheduled':
        return api_error(message="Chuyến xe không còn khả dụng", error_code="TRIP_UNAVAILABLE", status=400)

    now = datetime.now()

    # Dọn dẹp các vé HOLD đã hết hạn của chuyến đi này
    stale_holds = Booking.query.filter(
        Booking.trip_id == trip_id,
        Booking.status == 'HOLD',
        Booking.expires_at.isnot(None),
        Booking.expires_at <= now
    ).all()
    for b in stale_holds:
        b.seat_number = f"~{b.seat_number}_{b.id}"
        b.status = 'CANCELLED'
        b.payment_status = 'Expired'
        b.expires_at = None

    # Giải phóng các bản ghi CANCELLED để không xung đột UniqueConstraint('trip_id', 'seat_number')
    cancelled_seats = Booking.query.filter(
        Booking.trip_id == trip_id,
        Booking.seat_number == seat_number,
        Booking.status == 'CANCELLED'
    ).all()
    for b in cancelled_seats:
        b.seat_number = f"~{b.seat_number}_{b.id}"

    # Kiểm tra xem ghế có đang được đặt hoặc giữ chỗ hợp lệ hay không
    active_booking = Booking.query.filter(
        Booking.trip_id == trip_id,
        Booking.seat_number == seat_number,
        (
            (Booking.status == 'CONFIRMED') |
            ((Booking.status == 'HOLD') & ((Booking.expires_at.is_(None)) | (Booking.expires_at > now)))
        )
    ).first()

    if active_booking:
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
        expires_at=now + timedelta(minutes=15),
        ticket_price=ticket_price,
        payment_status='Unpaid'
    )

    try:
        db.session.add(new_booking)
        db.session.commit()
    except IntegrityError as ie:
        db.session.rollback()
        import logging
        logging.exception("Booking IntegrityError: %s", ie)
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
                "company_name": b.trip.route.company.name,
                "license_plate": b.trip.bus.license_plate if b.trip.bus else None
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
                "company_name": booking.trip.route.company.name,
                "license_plate": booking.trip.bus.license_plate if booking.trip.bus else None
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


@api_v1_bp.route('/bookings/active', methods=['GET'])
@jwt_required()
def get_active_bookings():
    """Lấy danh sách các vé sắp đi của hành khách để đối chiếu điểm đón AI Vision."""
    user = request.current_user
    # Lấy các vé đã xác nhận hoặc đang giữ chỗ, chưa hoàn thành
    active_bookings = Booking.query.filter(
        Booking.user_id == user.id,
        Booking.status.in_(['CONFIRMED', 'HOLD'])
    ).order_by(Booking.booking_time.desc()).limit(10).all()

    items = []
    for b in active_bookings:
        trip = b.trip
        route = trip.route if trip else None
        items.append({
            "id": b.id,
            "ticket_code": b.ticket_code,
            "seat_number": b.seat_number,
            "passenger_name": b.passenger_name,
            "passenger_phone": b.passenger_phone,
            "pickup_point": b.pickup_point,
            "status": b.status,
            "trip_id": trip.id if trip else None,
            "departure_time": trip.departure_time.isoformat() if trip else None,
            "route_name": f"{route.start_point} - {route.end_point}" if route else "Chưa xác định",
            "start_point": route.start_point if route else "",
            "end_point": route.end_point if route else "",
            "company_name": route.company.name if route and route.company else "Nhà xe"
        })

    return api_success(data={"items": items, "count": len(items)})


@api_v1_bp.route('/bookings/<int:booking_id>/notify-pickup', methods=['POST'])
@jwt_required()
def notify_pickup_location(booking_id):
    """Cập nhật điểm đón đã xác thực bằng AI Vision và phát tín hiệu cho nhà xe/tài xế."""
    user = request.current_user
    booking = Booking.query.filter_by(id=booking_id, user_id=user.id).first()
    if not booking:
        return api_error(message="Không tìm thấy thông tin vé", error_code="BOOKING_NOT_FOUND", status=404)

    data = request.json or {}
    pickup_location = data.get('pickup_location', '').strip()
    note = data.get('note', '')
    latitude = data.get('latitude')
    longitude = data.get('longitude')
    landmark_name = data.get('landmark_name', '')

    if not pickup_location:
        return api_error(message="Vui lòng cung cấp vị trí điểm đón", error_code="MISSING_PICKUP_LOCATION", status=400)

    # Cập nhật điểm đón mới vào cơ sở dữ liệu
    formatted_point = f"{pickup_location} [Xác thực AI Vision]"
    booking.pickup_point = formatted_point
    if latitude is not None:
        try:
            booking.pickup_lat = float(latitude)
        except (ValueError, TypeError):
            pass
    if longitude is not None:
        try:
            booking.pickup_lng = float(longitude)
        except (ValueError, TypeError):
            pass
    if landmark_name:
        booking.pickup_landmark = landmark_name
    if note:
        booking.pickup_note = note

    try:
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        return api_error(message=f"Lỗi cập nhật điểm đón: {str(e)}", error_code="DATABASE_ERROR", status=500)

    # Gửi tín hiệu Socket.IO thời gian thực đến Dashboard điều hành và Tài xế
    try:
        from extensions import socketio
        notice_payload = {
            'event': 'PASSENGER_PICKUP_UPDATE',
            'booking_id': booking.id,
            'ticket_code': booking.ticket_code,
            'passenger_name': booking.passenger_name,
            'passenger_phone': booking.passenger_phone,
            'seat_number': booking.seat_number,
            'trip_id': booking.trip_id,
            'route_name': f"{booking.trip.route.start_point} - {booking.trip.route.end_point}" if booking.trip and booking.trip.route else "",
            'pickup_location': pickup_location,
            'landmark_name': landmark_name,
            'latitude': latitude,
            'longitude': longitude,
            'note': note,
            'timestamp': datetime.utcnow().isoformat(),
            'message': f"Hành khách {booking.passenger_name} (Ghế {booking.seat_number}) đã xác thực vị trí đón tại: {pickup_location}. Bác tài lưu ý đón khách!"
        }
        socketio.emit('passenger_pickup_notice', notice_payload, namespace='/ops')
        socketio.emit('seat_update', {
            'trip_id': booking.trip_id,
            'seat_number': booking.seat_number,
            'pickup_point': formatted_point,
            'status': booking.boarding_status
        }, namespace='/ops')
    except Exception as sock_err:
        print(f"Socket emit notice warning: {sock_err}")

    return api_success(
        message="Đã cập nhật điểm đón và thông báo cho nhà xe & bác tài thành công!",
        data={
            "booking_id": booking.id,
            "ticket_code": booking.ticket_code,
            "pickup_point": booking.pickup_point,
            "passenger_name": booking.passenger_name,
            "passenger_phone": booking.passenger_phone,
            "seat_number": booking.seat_number
        }
    )


@api_v1_bp.route('/bookings/notify-pickup-public', methods=['POST'])
def notify_pickup_public():
    """Thông báo điểm đón trực tiếp qua mã vé hoặc số điện thoại (hỗ trợ cả khách vãng lai)."""
    data = request.json or {}
    pickup_location = data.get('pickup_location', '').strip()
    ticket_code = data.get('ticket_code', '').strip().upper()
    passenger_phone = data.get('passenger_phone', '').strip()
    passenger_name = data.get('passenger_name', '').strip() or "Hành khách"
    route_name = data.get('route_name', '').strip()
    landmark_name = data.get('landmark_name', '')
    note = data.get('note', '')
    latitude = data.get('latitude')
    longitude = data.get('longitude')

    if not pickup_location:
        return api_error(message="Vui lòng cung cấp vị trí điểm đón", error_code="MISSING_PICKUP_LOCATION", status=400)

    booking = None
    if ticket_code:
        booking = Booking.query.filter_by(ticket_code=ticket_code).first()
    elif passenger_phone:
        booking = Booking.query.filter_by(passenger_phone=passenger_phone).order_by(Booking.id.desc()).first()

    if booking:
        formatted_point = f"{pickup_location} [Xác thực AI Vision]"
        booking.pickup_point = formatted_point
        if latitude is not None:
            try:
                booking.pickup_lat = float(latitude)
            except (ValueError, TypeError):
                pass
        if longitude is not None:
            try:
                booking.pickup_lng = float(longitude)
            except (ValueError, TypeError):
                pass
        if landmark_name:
            booking.pickup_landmark = landmark_name
        if note:
            booking.pickup_note = note
        try:
            db.session.commit()
        except Exception as e:
            db.session.rollback()

    # Phát thông báo Socket.IO cho Trung tâm Điều hành & Bác tài
    try:
        from extensions import socketio
        notice_payload = {
            'event': 'PASSENGER_PICKUP_UPDATE',
            'booking_id': booking.id if booking else None,
            'ticket_code': booking.ticket_code if booking else ticket_code,
            'passenger_name': booking.passenger_name if booking else passenger_name,
            'passenger_phone': booking.passenger_phone if booking else passenger_phone,
            'seat_number': booking.seat_number if booking else "Chờ xếp",
            'trip_id': booking.trip_id if booking else None,
            'route_name': route_name or (f"{booking.trip.route.start_point} - {booking.trip.route.end_point}" if booking and booking.trip and booking.trip.route else "Tuyến xe"),
            'pickup_location': pickup_location,
            'landmark_name': landmark_name,
            'latitude': latitude,
            'longitude': longitude,
            'note': note,
            'timestamp': datetime.utcnow().isoformat(),
            'message': f"Hành khách {booking.passenger_name if booking else passenger_name} báo điểm đón tại: {pickup_location}. Nhà xe lưu ý điều phối đón khách!"
        }
        socketio.emit('passenger_pickup_notice', notice_payload, namespace='/ops')
    except Exception as sock_err:
        print(f"Socket emit warning: {sock_err}")

    return api_success(
        message="Đã gửi thông báo điểm đón đến nhà xe và tài xế thành công!",
        data={
            "ticket_code": booking.ticket_code if booking else ticket_code,
            "pickup_location": pickup_location,
            "landmark_name": landmark_name,
            "passenger_phone": booking.passenger_phone if booking else passenger_phone
        }
    )



# NOTE: POST /sos da duoc chuyen sang api/v1/sos.py (canh bao SOS theo vi tri, bat buoc dang nhap).

@api_v1_bp.route('/update_device_info', methods=['POST'])
def update_device_info():
    # API để app gọi lên cập nhật token FCM và tọa độ mới nhất
    try:
        import jwt as _jwt, os as _os
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return api_error(message="Yêu cầu đăng nhập", status=401)
            
        token = auth_header.split(' ')[1]
        secret = _os.getenv('JWT_SECRET_KEY', 'local-dev-jwt-secret-key-12345')
        payload = _jwt.decode(token, secret, algorithms=['HS256'])
        from models import User
        user = User.query.get(payload.get('sub'))
        if not user:
            return api_error(message="Không tìm thấy user", status=404)
            
        data = request.json or {}
        if 'fcm_token' in data:
            user.fcm_token = data['fcm_token']
        if 'lat' in data and 'lng' in data:
            user.last_lat = float(data['lat'])
            user.last_lng = float(data['lng'])
            import datetime
            user.last_location_time = datetime.datetime.now()
            
        db.session.commit()
        return api_success({"message": "Đã cập nhật thông tin thiết bị"})
    except Exception as e:
        db.session.rollback()
        return api_error(message=str(e), status=500)

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
    # Dong bo: nhan vien ket thuc -> dong su kien SOS thoi gian thuc lien ket
    try:
        from models import SOSIncident
        inc = SOSIncident.query.filter_by(legacy_sos_id=alert.id, status='active').first()
        if inc:
            inc.status = 'resolved'
            inc.resolved_at = alert.resolved_at
            inc.resolved_by = 'staff'
    except Exception:
        pass
    # In a real app, we'd record the staff ID from token
    db.session.commit()
    
    return api_success({"message": "Alert resolved"})
