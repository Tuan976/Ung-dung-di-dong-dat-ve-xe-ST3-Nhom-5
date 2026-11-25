import re
from datetime import date
from urllib.parse import urlencode

from flask import current_app, g, jsonify, make_response, request, session
from itsdangerous import BadData, URLSafeTimedSerializer

from ai_service import ai_service
from api.v1.decorators import jwt_required
from gemini_chat import gemini_enabled, gemini_trip_filters
from models import Booking, User
from routes_ai import _default_ai_state, _get_known_locations, _now, _resolve_trip_selection, _search_trips
from routes_public import (
    _cancel_passenger_booking, _extract_display_seat_number, _passenger_cancellation_error,
    book_trip, trip_details,
)


SESSION_KEY = 'customer_assistant'
TICKET_CODE = re.compile(r'\bHT\d{8}\b', re.IGNORECASE)
POLICY_LINKS = (
    ('chinh sach bao mat', 'Chính sách bảo mật', 'chinh-sach-bao-mat'),
    ('chinh sach thanh toan', 'Chính sách thanh toán', 'chinh-sach-thanh-toan'),
    ('quy che', 'Quy chế hoạt động', 'quy-che-hoat-dong'),
    ('khieu nai', 'Liên hệ hỗ trợ', 'giai-quyet-khieu-nai'),
)


def link(label, href):
    return {'label': label, 'href': href}


def reply(response, **details):
    return jsonify(response=response, **details)


def passenger():
    if getattr(g, 'assistant_mobile', False):
        return request.current_user if getattr(request, 'current_user_role', None) == 'passenger' else None
    if session.get('role') == 'passenger' and session.get('user_id'):
        return User.query.get(session['user_id'])
    return None


def load_state():
    state = _default_ai_state()
    if getattr(g, 'assistant_mobile', False):
        state.update(g.assistant_state)
    else:
        state.update(session.get(SESSION_KEY, {}))
    return state


def save_state(state):
    if getattr(g, 'assistant_mobile', False):
        g.assistant_state = state
    elif state:
        session[SESSION_KEY] = state
    else:
        session.pop(SESSION_KEY, None)


def ticket_card(booking, owned=False):
    trip = booking.trip
    return {
        'code': booking.ticket_code,
        'booking_id': booking.id if owned else None,
        'route': f'{trip.route.start_point} → {trip.route.end_point}',
        'departure': trip.departure_time.strftime('%H:%M %d/%m/%Y'),
        'seat': _extract_display_seat_number(booking.seat_number),
        'pickup': booking.pickup_point,
        'dropoff': booking.dropoff_point,
        'status': booking.status,
        'payment_status': booking.payment_status,
        'price': booking.ticket_price,
        'can_cancel': owned and not _passenger_cancellation_error(booking, _now()),
    }


def own_tickets(user, code=None):
    if not user:
        return reply(
            'Đăng nhập tài khoản hành khách để xem hoặc quản lý vé. Bạn cũng có thể tra bằng mã vé và số điện thoại.',
            links=[link('Đăng nhập', '/auth')], panel='lookup', code=code or '',
        )
    query = Booking.query.filter_by(user_id=user.id)
    if code:
        query = query.filter_by(ticket_code=code)
    bookings = query.order_by(Booking.id.desc()).limit(8).all()
    if not bookings:
        return reply('Mình chưa tìm thấy vé trong tài khoản này.', panel='lookup', code=code or '')
    return reply('Đây là các vé của bạn.', tickets=[ticket_card(item, owned=True) for item in bookings])


def search_options(state):
    options, _ = _search_trips({**state, 'exact_route': True, 'time_window': bool(state['time_pref'])})
    return options


def search_reply(state):
    day = date.fromisoformat(state['date_iso'])
    if day < _now().date():
        state['trip_options'] = []
        save_state(state)
        return reply('Ngày này đã qua. Bạn chọn ngày đi mới nhé.', panel='search', criteria=criteria_summary(state))
    options = search_options(state)
    # Store IDs only. Read current price and availability again when selecting a card.
    state['trip_options'] = [trip['trip_id'] for trip in options]
    save_state(state)
    summary = criteria_summary(state)
    if options:
        return reply(
            f"Tìm thấy {len(options)} chuyến phù hợp đang còn chỗ. Bạn có thể chọn chuyến hoặc nhắn để đổi giờ, ngày hay số vé.",
            trips=options, criteria=summary,
        )
    params = urlencode({'start_point': state['from'], 'end_point': state['to'], 'date': state['date_iso']})
    links = [link('Mở trang tìm chuyến', '/search?' + params)]
    if state.get('time_pref') or state.get('bus_type'):
        return reply(
            'Chưa có chuyến đủ chỗ theo giờ hoặc loại xe đã chọn. Bạn có thể bỏ bộ lọc hoặc đổi ngày.',
            panel='search', criteria=summary, links=links, clear_filters=True,
        )
    return reply(
        'Chưa tìm thấy chuyến đủ chỗ cho tuyến và ngày này. Bạn thử đổi ngày hoặc giảm số vé nhé.',
        panel='search', criteria=summary, links=links,
    )


def criteria_summary(state):
    return {
        'from': state['from'], 'to': state['to'], 'date': state['date_iso'],
        'pax': state['pax'], 'time': (state['time_pref'] or {}).get('label'),
    }


def select_trip(state, trip_id):
    if trip_id not in state['trip_options']:
        return reply('Bạn hãy tìm lại chuyến để lấy giá và ghế mới nhất.', panel='search', criteria=criteria_summary(state))
    current = search_options(state)
    trip = next((item for item in current if item['trip_id'] == trip_id), None)
    if not trip:
        return reply('Chuyến này vừa thay đổi hoặc không còn đủ chỗ. Bạn chọn chuyến khác nhé.', trips=current)
    from extensions import payos_client

    user = passenger()
    contact = {'name': user.name, 'phone': user.phone or ''} if user else {}
    return reply(
        'Mình đã mở sơ đồ ghế. Chọn ghế và kiểm tra thông tin trước khi xác nhận.',
        checkout={'trip': trip, 'pax': state['pax'], 'contact': contact, 'online_payment': payos_client is not None},
    )


def location_value(value, locations):
    return ai_service.canonicalize_location(value, locations, fallback_raw=False) if value else None


def new_search(data, locations):
    origin, destination, travel_date, pax = (data.get(field) for field in ('from', 'to', 'date', 'pax'))
    if not all(isinstance(value, str) for value in (origin, destination, travel_date)):
        return reply('Bạn chọn điểm đi, điểm đến và ngày đi nhé.', panel='search')
    if origin not in locations or destination not in locations or origin == destination:
        return reply('Bạn chọn hai địa điểm khác nhau trong danh sách nhé.', panel='search')
    try:
        travel_date = date.fromisoformat(travel_date).isoformat()
    except ValueError:
        return reply('Ngày đi chưa hợp lệ.', panel='search')
    if type(pax) is not int or not 1 <= pax <= 20:
        return reply('Bạn chọn từ 1 đến 20 vé cho mỗi lần tìm.', panel='search')
    state = _default_ai_state()
    state.update({'from': origin, 'to': destination, 'date_iso': travel_date, 'pax': pax})
    return search_reply(state)


def handle_message(message, state, locations):
    normalized = ai_service.normalize_text(message)
    code_match = TICKET_CODE.search(message)
    code = code_match.group().upper() if code_match else None
    if not normalized:
        return reply('Bạn muốn tìm chuyến hay tra vé?', panel='help')
    if ai_service.detect_reset(message) or normalized in ('tim lai', 'bat dau lai'):
        save_state({})
        return reply('Mình đã bắt đầu cuộc tìm kiếm mới.', panel='search')
    if normalized in ('trang chu', 've trang chu'):
        return reply('Đây là trang chủ HUTECH BUS.', links=[link('Mở trang chủ', '/')])
    if re.search(r'\b(huy ve|doi ve|hoan ve|hoan tien)\b', normalized):
        if 'huy ve' in normalized:
            return own_tickets(passenger(), code)
        return reply(
            'Bạn xem điều kiện đổi hoặc hoàn vé và liên hệ hỗ trợ để xử lý vé cụ thể.',
            links=[link('Điều kiện đổi vé', '/thong-tin/faq'), link('Liên hệ hỗ trợ', '/thong-tin/giai-quyet-khieu-nai')],
        )
    if 'tra ve' in normalized or 'tra cuu ve' in normalized or code:
        user = passenger()
        if code and user:
            return own_tickets(user, code)
        return reply('Nhập mã vé và số điện thoại đã dùng khi đặt.', panel='lookup', code=code or '')
    if ai_service.detect_ticket_lookup(message) or normalized in ('ve da dat', 'lich su dat ve'):
        return own_tickets(passenger())
    for phrase, label, slug in POLICY_LINKS:
        if phrase in normalized:
            return reply(f'Mình đã tìm trang {label.lower()} của HUTECH BUS.', links=[link(label, f'/thong-tin/{slug}')])
    if re.search(r'\b(hotline|tong dai|lien he|nhan vien|ho tro)\b', normalized):
        return reply('Bạn có thể xem các kênh hỗ trợ của HUTECH BUS tại đây.', links=[link('Liên hệ hỗ trợ', '/thong-tin/giai-quyet-khieu-nai')])
    if re.search(r'\b(thanh toan|chuyen khoan|payos)\b', normalized):
        return reply(
            'Bạn chọn phương thức ở bước đặt vé. Với thanh toán trực tuyến, cổng thanh toán sẽ mở để bạn hoàn tất.',
            links=[link('Hướng dẫn thanh toán', '/thong-tin/huong-dan-thanh-toan')],
        )
    if re.search(r'\b(quen mat khau|dang nhap|dang ky|tai khoan|ho so)\b', normalized):
        target = '/profile' if 'ho so' in normalized and passenger() else '/auth'
        if 'quen mat khau' in normalized:
            target = '/auth?mode=forgot'
        elif 'dang ky' in normalized:
            target = '/auth?mode=register'
        return reply('Mình có thể mở đúng trang tài khoản cho bạn.', links=[link('Mở trang tài khoản', target)])
    if re.search(r'\b(hanh ly|doi tra|cau hoi|tre em|in ve|len xe)\b', normalized):
        return reply('Bạn có thể xem giải đáp của HUTECH BUS hoặc liên hệ hỗ trợ.', links=[
            link('Câu hỏi thường gặp', '/thong-tin/faq'),
            link('Liên hệ hỗ trợ', '/thong-tin/giai-quyet-khieu-nai'),
        ])
    message = re.sub(r'\b(?:đổi|doi)\s+sang\b', 'đổi', message, flags=re.IGNORECASE)
    today = _now().date()
    parsed = ai_service.parse_message(message, state, locations)
    slots = parsed['slots']
    date_info = ai_service.parse_date(message, today=today)
    if date_info:
        slots['date_iso'] = date_info['date'].isoformat()
        slots['date_label'] = date_info['label']
    selection_message = re.fullmatch(r'(?:(?:chon|lay)\s+(?:chuyen\s+)?|chuyen\s+)?\d{1,2}', normalized)
    selection = parsed['selection']
    if state['trip_options'] and selection and (
        selection_message or selection['type'] == 'strategy' and not slots['date_iso']
    ):
        current = search_options(state)
        # Keep the order shown to the customer even if a trip has since sold out.
        by_id = {item['trip_id']: item for item in current}
        shown = [by_id.get(trip_id, {'trip_id': trip_id}) for trip_id in state['trip_options']]
        if selection['type'] == 'strategy':
            shown = [item for item in shown if 'departure_iso' in item]
        selected = _resolve_trip_selection(selection, shown)
        if selected:
            return select_trip(state, selected['trip_id'])
        return reply('Không còn chuyến phù hợp với lựa chọn đó. Bạn có thể tìm lại.', panel='search', criteria=criteria_summary(state))
    if selection_message and not state['trip_options'] and state['from'] and state['to'] and state['date_iso']:
        if not re.fullmatch(r'\d{1,2}', normalized):
            return reply('Bạn cần tìm chuyến trước khi chọn theo số thứ tự.', panel='search', criteria=criteria_summary(state))
    if slots['pax'] and re.search(r'\bthem\b', normalized):
        slots['pax'] += state['pax'] or 1
    if slots['pax'] and slots['pax'] > 20:
        return reply('Bạn chọn tối đa 20 vé cho mỗi lần tìm.', panel='search', criteria=criteria_summary(state))
    # A single place is treated as the answer to the missing endpoint.
    if not slots['to'] and state['from'] and not state['to'] and not re.search(r'\b(tu|di|den|toi)\b', normalized):
        single = location_value(message, locations)
        if single and single != state['from']:
            slots['from'], slots['to'] = None, single
    for field in ('from', 'to'):
        slots[field] = location_value(slots[field], locations)
    if 'ghe' in normalized and not re.search(r'\b(xe ghe|ghe ngoi|xe ngoi|seat)\b', normalized):
        slots['bus_type'] = None
    # Let Gemini help with follow-ups and incomplete free-text searches. Explicit
    # form submissions, trip selection, and all booking actions stay local.
    if (
        not selection_message
        and not parsed['greeting']
        and (parsed['booking_interest'] or any(slots.values()))
        and not all(slots[key] for key in ('from', 'to', 'date_iso', 'pax'))
    ):
        slots.update(gemini_trip_filters(message, state, locations, today))
    state, changed = ai_service.merge_state(state, slots)
    if not changed and not parsed['booking_interest']:
        return reply('Mình có thể tìm chuyến, chọn ghế, tra vé và hỗ trợ tài khoản. Bạn muốn làm gì?', panel='help')
    save_state(state)
    if not state['from'] or not state['to'] or not state['date_iso'] or state['from'] == state['to']:
        question = 'Bạn chọn điểm đến khác điểm đi nhé.' if state['from'] and state['from'] == state['to'] else ai_service.next_question(state)
        return reply(question, panel='search', criteria=criteria_summary(state))
    state['pax'] = state['pax'] or 1
    return search_reply(state)


def assistant_action(data):
    if not isinstance(data, dict):
        return reply('Yêu cầu không hợp lệ.'), 400
    action = data.get('action', 'message')
    state = load_state()
    if action == 'reset':
        save_state({})
        return reply('Mình đã bắt đầu cuộc trò chuyện mới.')
    if action == 'tickets':
        return own_tickets(passenger())
    if action in ('lookup', 'cancel_ticket'):
        raw_code = data.get('code')
        code = raw_code.strip().upper() if isinstance(raw_code, str) else ''
        if not TICKET_CODE.fullmatch(code):
            return reply('Mã vé chưa hợp lệ. Ví dụ: HT12345678.'), 400
        if action == 'lookup':
            raw_phone = data.get('phone')
            phone = re.sub(r'[\s.-]', '', raw_phone) if isinstance(raw_phone, str) else ''
            if not re.fullmatch(r'\d{8,15}', phone):
                return reply('Bạn nhập đúng số điện thoại đã dùng khi đặt vé nhé.'), 400
            booking = Booking.query.filter_by(ticket_code=code, passenger_phone=phone).first()
            if not booking:
                return reply('Không tìm thấy vé khớp với thông tin đã nhập.'), 404
            user = passenger()
            return reply('Mình đã tìm thấy vé.', tickets=[ticket_card(booking, owned=bool(user and booking.user_id == user.id))])
        user = passenger()
        if not user:
            return reply('Bạn cần đăng nhập để hủy vé.'), 401
        if data.get('confirmed') is not True:
            return reply('Bạn cần xác nhận trước khi hủy vé.'), 400
        booking = Booking.query.filter_by(ticket_code=code, user_id=user.id).first()
        if not booking:
            return reply('Không tìm thấy vé trong tài khoản của bạn.'), 404
        message, cancelled = _cancel_passenger_booking(booking)
        if not cancelled:
            return reply(message), 409
        return reply(message, tickets=[ticket_card(booking)])
    if action == 'select_trip':
        trip_id = data.get('trip_id')
        if type(trip_id) is not int:
            return reply('Chuyến xe không hợp lệ.'), 400
        return select_trip(state, trip_id)
    if action == 'clear_filters':
        if not (state['from'] and state['to'] and state['date_iso']):
            return reply('Bạn chọn tuyến và ngày đi trước nhé.', panel='search')
        state.update(time_pref=None, bus_type=None)
        return search_reply(state)
    if action == 'search':
        return new_search(data, _get_known_locations())
    message = data.get('message')
    if action != 'message' or not isinstance(message, str) or len(message) > 500:
        return reply('Nhập nội dung tối đa 500 ký tự.'), 400
    return handle_message(message.strip(), state, _get_known_locations())

def register_chatbot(app):
    @app.route('/api/ai/chatbot', methods=['GET', 'POST'])
    def customer_assistant():
        if request.method == 'GET':
            return jsonify(status='API Chatbot is active', gemini_enabled=gemini_enabled())
        return assistant_action(request.get_json(silent=True))

    def serve_mobile_assistant():
        g.assistant_mobile = True
        g.assistant_state = {}
        user = passenger()
        user_id = user.id if user else None
        data = request.get_json(silent=True)
        signer = URLSafeTimedSerializer(current_app.secret_key, salt='hutech-mobile-assistant-v1')
        token = data.get('conversation') if isinstance(data, dict) else None
        if isinstance(token, str) and len(token) <= 4096:
            try:
                saved = signer.loads(token, max_age=7200)
                if saved['user_id'] == user_id and isinstance(saved['state'], dict):
                    g.assistant_state = saved['state']
            except (BadData, KeyError, TypeError):
                pass

        response = make_response(assistant_action(data))
        body = response.get_json()
        if g.assistant_state:
            body['conversation'] = signer.dumps({'user_id': user_id, 'state': g.assistant_state})
        else:
            body['conversation'] = None
        result = jsonify(body)
        result.status_code = response.status_code
        result.headers['Cache-Control'] = 'no-store'
        return result

    @app.route('/api/v1/assistant', methods=['GET', 'POST'])
    def mobile_assistant():
        if request.method == 'GET':
            return jsonify(gemini_enabled=gemini_enabled(), locations=_get_known_locations())
        if 'Authorization' in request.headers:
            return jwt_required()(serve_mobile_assistant)()
        return serve_mobile_assistant()

    @app.get('/api/v1/assistant/trips/<int:trip_id>')
    def mobile_assistant_trip(trip_id):
        return trip_details(trip_id)

    def serve_mobile_checkout():
        g.assistant_mobile = True
        user = passenger()
        if 'Authorization' in request.headers and not user:
            return jsonify(success=False, message='Bạn cần tài khoản hành khách để đặt vé.'), 403
        return book_trip(request.get_json(silent=True), user_id=user.id if user else None)

    @app.post('/api/v1/assistant/book')
    def mobile_assistant_book():
        if 'Authorization' in request.headers:
            return jwt_required()(serve_mobile_checkout)()
        return serve_mobile_checkout()
