from datetime import datetime
from flask import Blueprint, jsonify, request, session
from extensions import db, socketio
from models import Booking, ChatMessage, CallSession, Trip, User, Staff

communication_bp = Blueprint('communication', __name__)

# Bộ nhớ đệm tạm thời cho tín hiệu WebRTC signaling (cho phép polling nếu socket gián đoạn)
_active_signals = {}  # {booking_id: {'signals': [], 'status': 'IDLE', 'updated_at': datetime}}


def _get_call_room(booking_id):
    return f"booking_{booking_id}"


@communication_bp.route('/<int:booking_id>/messages', methods=['GET'])
def get_chat_messages(booking_id):
    booking = Booking.query.get_or_404(booking_id)
    trip = booking.trip

    # Tìm thông tin đối phương (Tài xế hoặc Hành khách)
    driver_name = "Tài xế"
    bus_plate = "Chưa gán xe"
    if trip:
        if trip.bus and trip.bus.license_plate:
            bus_plate = trip.bus.license_plate
        if getattr(trip, 'driver', None) and trip.driver.name:
            driver_name = trip.driver.name
        elif trip.bus and getattr(trip.bus, 'driver_name', None):
            driver_name = trip.bus.driver_name

    messages = ChatMessage.query.filter_by(booking_id=booking_id).order_by(ChatMessage.created_at.asc()).all()

    # Đánh dấu đã đọc các tin nhắn từ đối phương
    role = session.get('role', 'PASSENGER')
    for m in messages:
        if m.sender_role != role and not m.is_read:
            m.is_read = True
    db.session.commit()

    return jsonify({
        'success': True,
        'booking_id': booking.id,
        'ticket_code': booking.ticket_code,
        'passenger': {
            'name': booking.passenger_name,
            'phone': booking.passenger_phone,
            'seat': booking.seat_number,
        },
        'operator': {
            'driver_name': driver_name,
            'bus_plate': bus_plate,
            'company_name': trip.route.company.name if trip and trip.route and trip.route.company else 'Nhà xe',
        },
        'messages': [m.to_dict() for m in messages]
    })


@communication_bp.route('/<int:booking_id>/send', methods=['POST'])
def send_chat_message(booking_id):
    booking = Booking.query.get_or_404(booking_id)
    data = request.get_json(silent=True) or request.form or {}
    message_text = (data.get('message') or '').strip()

    if not message_text:
        return jsonify({'success': False, 'message': 'Nội dung tin nhắn không được để trống'}), 400

    sender_role = data.get('sender_role') or session.get('role', 'PASSENGER')
    sender_name = data.get('sender_name') or session.get('user_name') or (booking.passenger_name if sender_role == 'PASSENGER' else 'Tài xế / Nhà xe')
    message_type = data.get('message_type', 'TEXT')

    new_msg = ChatMessage(
        booking_id=booking.id,
        trip_id=booking.trip_id,
        sender_role=sender_role,
        sender_name=sender_name,
        sender_id=session.get('user_id') or session.get('staff_id'),
        message=message_text,
        message_type=message_type,
        created_at=datetime.utcnow()
    )
    db.session.add(new_msg)
    db.session.commit()

    msg_dict = new_msg.to_dict()

    # Bắn tín hiệu SocketIO thời gian thực
    try:
        room = _get_call_room(booking.id)
        socketio.emit('new_chat_message', msg_dict, room=room)
    except Exception:
        pass

    return jsonify({
        'success': True,
        'message': msg_dict
    })


# --- IN-APP CALLING SIGNALING & CONTROL ---

@communication_bp.route('/check-incoming', methods=['GET'])
def check_incoming_call():
    """Kiểm tra xem thiết bị hiện tại có cuộc gọi thoại đến nào đang đổ chuông không."""
    role = (request.args.get('role') or session.get('role', 'PASSENGER')).upper()
    user_id = request.args.get('user_id', type=int) or session.get('user_id')
    phone = (request.args.get('phone') or session.get('phone') or '').strip()
    trip_id = request.args.get('trip_id', type=int)
    booking_id = request.args.get('booking_id', type=int)

    now = datetime.utcnow()

    # 1. Nếu có booking_id cụ thể (đang mở vé hoặc chat)
    if booking_id:
        active_call = CallSession.query.filter(
            CallSession.booking_id == booking_id,
            CallSession.status == 'RINGING',
            CallSession.caller_role != role
        ).order_by(CallSession.id.desc()).first()

        if active_call and (now - active_call.created_at).total_seconds() < 45:
            return jsonify({
                'has_incoming': True,
                'call': active_call.to_dict()
            })

    # 2. Nếu là Tài xế / Nhà xe (OPERATOR, DRIVER, STAFF)
    if role in ('OPERATOR', 'DRIVER', 'STAFF'):
        calls = CallSession.query.filter(
            CallSession.status == 'RINGING',
            CallSession.caller_role == 'PASSENGER'
        ).order_by(CallSession.id.desc()).limit(15).all()

        for c in calls:
            if (now - c.created_at).total_seconds() < 45:
                if trip_id and c.booking and c.booking.trip_id != trip_id:
                    continue
                return jsonify({
                    'has_incoming': True,
                    'call': c.to_dict()
                })

    # 3. Nếu là Hành khách (PASSENGER)
    else:
        calls = CallSession.query.filter(
            CallSession.status == 'RINGING',
            CallSession.caller_role == 'OPERATOR'
        ).order_by(CallSession.id.desc()).limit(15).all()

        for c in calls:
            if (now - c.created_at).total_seconds() < 45:
                b = c.booking
                if b:
                    if user_id and b.user_id == user_id:
                        return jsonify({'has_incoming': True, 'call': c.to_dict()})
                    if phone and b.passenger_phone and (phone in b.passenger_phone or b.passenger_phone in phone):
                        return jsonify({'has_incoming': True, 'call': c.to_dict()})
                # Nếu không truyền user_id/phone cụ thể, kiểm tra session
                if session.get('user_id') and b and b.user_id == session.get('user_id'):
                    return jsonify({'has_incoming': True, 'call': c.to_dict()})

    return jsonify({'has_incoming': False})


@communication_bp.route('/call/start', methods=['POST'])
def start_call():
    data = request.get_json(silent=True) or request.form or {}
    booking_id = int(data.get('booking_id', 0))
    booking = Booking.query.get_or_404(booking_id)

    caller_role = data.get('caller_role') or session.get('role', 'PASSENGER')
    caller_name = data.get('caller_name') or (booking.passenger_name if caller_role == 'PASSENGER' else 'Tài xế xe')
    receiver_name = booking.passenger_name if caller_role != 'PASSENGER' else (booking.trip.bus.license_plate if booking.trip and booking.trip.bus else 'Tài xế')

    # Tạo CallSession
    call = CallSession(
        booking_id=booking_id,
        caller_role=caller_role,
        caller_name=caller_name,
        receiver_name=receiver_name,
        status='RINGING',
        created_at=datetime.utcnow()
    )
    db.session.add(call)
    db.session.commit()

    # Reset cache tín hiệu
    _active_signals[booking_id] = {
        'call_id': call.id,
        'status': 'RINGING',
        'caller_role': caller_role,
        'caller_name': caller_name,
        'receiver_name': receiver_name,
        'signals': [],
        'updated_at': datetime.utcnow()
    }

    call_payload = call.to_dict()

    # Phát tín hiệu cuộc gọi đến qua SocketIO
    try:
        room = _get_call_room(booking_id)
        socketio.emit('incoming_call', call_payload, room=room)
    except Exception:
        pass

    return jsonify({
        'success': True,
        'call': call_payload
    })


@communication_bp.route('/call/signal', methods=['POST'])
def post_signal():
    """Trao đổi tín hiệu WebRTC (SDP offer/answer, ICE candidates)."""
    data = request.get_json(silent=True) or request.form or {}
    booking_id = int(data.get('booking_id', 0))
    signal_type = data.get('signal_type')  # 'offer', 'answer', 'candidate'
    payload = data.get('payload')
    sender_role = data.get('sender_role')

    if not booking_id or not signal_type:
        return jsonify({'success': False, 'message': 'Thiếu tham số'}), 400

    signal_obj = {
        'signal_type': signal_type,
        'payload': payload,
        'sender_role': sender_role,
        'timestamp': datetime.utcnow().isoformat()
    }

    if booking_id not in _active_signals:
        _active_signals[booking_id] = {'signals': [], 'status': 'CONNECTED'}

    _active_signals[booking_id]['signals'].append(signal_obj)
    # Giới hạn bộ đệm
    if len(_active_signals[booking_id]['signals']) > 50:
        _active_signals[booking_id]['signals'] = _active_signals[booking_id]['signals'][-30:]

    # Bắn tín hiệu tức thời qua SocketIO
    try:
        room = _get_call_room(booking_id)
        socketio.emit('call_signal', signal_obj, room=room)
    except Exception:
        pass

    return jsonify({'success': True})


@communication_bp.route('/<int:booking_id>/call-status', methods=['GET'])
def get_call_status(booking_id):
    """Kiểm tra trạng thái cuộc gọi & nhận tín hiệu WebRTC (hỗ trợ cả REST polling)."""
    call_info = _active_signals.get(booking_id, {'status': 'IDLE', 'signals': []})

    # Lấy tín hiệu cho vai trò gọi tới
    role = request.args.get('role', '')
    unread_signals = [s for s in call_info.get('signals', []) if s.get('sender_role') != role]

    # Kiểm tra trong DB nếu cache chưa có
    if call_info.get('status') == 'IDLE':
        last_call = CallSession.query.filter_by(booking_id=booking_id).order_by(CallSession.id.desc()).first()
        if last_call and (datetime.utcnow() - last_call.created_at).total_seconds() < 45 and last_call.status == 'RINGING':
            call_info = {
                'call_id': last_call.id,
                'status': last_call.status,
                'caller_role': last_call.caller_role,
                'caller_name': last_call.caller_name,
                'receiver_name': last_call.receiver_name,
                'signals': []
            }

    return jsonify({
        'success': True,
        'booking_id': booking_id,
        'status': call_info.get('status', 'IDLE'),
        'call_id': call_info.get('call_id'),
        'caller_role': call_info.get('caller_role'),
        'caller_name': call_info.get('caller_name'),
        'receiver_name': call_info.get('receiver_name'),
        'signals': unread_signals
    })


@communication_bp.route('/call/action', methods=['POST'])
def call_action():
    """Hành động cuộc gọi: ACCEPT, REJECT, END."""
    data = request.get_json(silent=True) or request.form or {}
    booking_id = int(data.get('booking_id', 0))
    action = (data.get('action') or '').upper()  # 'ACCEPT', 'REJECT', 'END'
    duration = int(data.get('duration_seconds', 0))

    new_status = 'CONNECTED' if action == 'ACCEPT' else ('REJECTED' if action == 'REJECT' else 'ENDED')

    # Cập nhật DB
    last_call = CallSession.query.filter_by(booking_id=booking_id).order_by(CallSession.id.desc()).first()
    if last_call and last_call.status in ('RINGING', 'CONNECTED'):
        last_call.status = new_status
        last_call.duration_seconds = duration
        if new_status in ('ENDED', 'REJECTED'):
            last_call.ended_at = datetime.utcnow()
        db.session.commit()

        # Thêm nhật ký vào cuộc trò chuyện
        if new_status in ('ENDED', 'REJECTED'):
            log_msg = f"📞 Cuộc gọi thoại ({duration // 60:02d}:{duration % 60:02d})" if duration > 0 else ("📞 Cuộc gọi bị từ chối" if new_status == 'REJECTED' else "📞 Cuộc gọi nhỡ")
            chat_log = ChatMessage(
                booking_id=booking_id,
                trip_id=last_call.booking.trip_id if last_call.booking else None,
                sender_role=last_call.caller_role,
                sender_name=last_call.caller_name,
                message=log_msg,
                message_type='CALL_LOG',
                created_at=datetime.utcnow()
            )
            db.session.add(chat_log)
            db.session.commit()

    # Cập nhật cache
    if booking_id in _active_signals:
        _active_signals[booking_id]['status'] = new_status

    # Bắn tín hiệu socket
    try:
        room = _get_call_room(booking_id)
        socketio.emit('call_action', {'action': action, 'status': new_status, 'duration_seconds': duration}, room=room)
    except Exception:
        pass

    return jsonify({
        'success': True,
        'action': action,
        'status': new_status
    })

