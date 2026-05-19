from datetime import datetime

from flask import jsonify, request, session

from ai_service import ai_service
from decorators import company_login_required
from extensions import db
from models import Booking, Route, Trip, User


ACTIVE_TRIP_STATUSES = ('Scheduled', 'Running')


def _default_ai_state():
    return {
        'from': None,
        'to': None,
        'date_iso': None,
        'date_label': None,
        'pax': None,
        'time_pref': None,
        'bus_type': None,
        'trip_options': []
    }


def _get_ai_state():
    state = session.get('ai_booking_state') or {}
    base = _default_ai_state()
    base.update({k: v for k, v in state.items() if k in base})
    return base


def _save_ai_state(state):
    session['ai_booking_state'] = state
    session.modified = True


def _get_known_locations():
    values = set()
    for route in Route.query.all():
        if route.start_point:
            values.add(route.start_point.strip())
        if route.end_point:
            values.add(route.end_point.strip())
    return sorted(values)


def _match_bus_type(requested_bus_type, actual_bus_type):
    if not requested_bus_type:
        return True
    actual = ai_service.normalize_text(actual_bus_type)
    if requested_bus_type == 'limousine':
        return 'limo' in actual or 'vip' in actual
    if requested_bus_type == 'cabin':
        return 'cabin' in actual or 'phong' in actual or 'luxury' in actual
    if requested_bus_type == 'sleeper':
        return 'sleeper' in actual or 'giuong' in actual
    if requested_bus_type == 'seat':
        return 'seat' in actual or 'ghe' in actual
    return True


def _route_match_score(route, start_value, end_value):
    start_score = ai_service.location_similarity(start_value, route.start_point)
    end_score = ai_service.location_similarity(end_value, route.end_point)
    return (start_score + end_score) / 2


def _time_score(trip, time_pref):
    if not time_pref:
        return 0
    departure_minutes = trip.departure_time.hour * 60 + trip.departure_time.minute
    target_minutes = time_pref.get('minutes')
    if target_minutes is None:
        return 0
    return abs(departure_minutes - target_minutes)


def _available_seats_for_trip(trip):
    confirmed_count = Booking.query.filter_by(trip_id=trip.id, status='CONFIRMED').count()
    hold_count = Booking.query.filter(
        Booking.trip_id == trip.id,
        Booking.status == 'HOLD',
        Booking.expires_at.isnot(None),
        Booking.expires_at > datetime.now()
    ).count()
    return max(0, trip.bus.total_seats - confirmed_count - hold_count)


def _price_text(trip):
    price = (trip.route.base_price or 0) * (trip.price_multiplier or 1)
    return f"{price:,.0f}đ"


def _trip_to_option(trip):
    price_value = (trip.route.base_price or 0) * (trip.price_multiplier or 1)
    return {
        'trip_id': trip.id,
        'route_text': f"{trip.route.start_point} → {trip.route.end_point}",
        'time_text': trip.departure_time.strftime('%H:%M %d/%m/%Y'),
        'available_seats': _available_seats_for_trip(trip),
        'bus_type_text': ai_service.human_bus_type(trip.bus.bus_type),
        'price_text': f"{price_value:,.0f}đ",
        'price_value': price_value,
        'departure_iso': trip.departure_time.isoformat(),
        'departure_minutes': trip.departure_time.hour * 60 + trip.departure_time.minute,
    }


def _search_trips(criteria, limit=5):
    try:
        target_date = datetime.fromisoformat(criteria['date_iso']).date()
    except Exception:
        return [], []

    matching_routes = []
    for route in Route.query.all():
        score = _route_match_score(route, criteria['from'], criteria['to'])
        if score >= 0.7:
            matching_routes.append((score, route))

    matching_routes.sort(key=lambda item: item[0], reverse=True)
    results = []

    for route_score, route in matching_routes:
        trips = Trip.query.filter(
            Trip.route_id == route.id,
            db.func.date(Trip.departure_time) == target_date,
            Trip.status.in_(ACTIVE_TRIP_STATUSES)
        ).order_by(Trip.departure_time.asc()).all()

        for trip in trips:
            if criteria.get('bus_type') and not _match_bus_type(criteria['bus_type'], trip.bus.bus_type):
                continue
            available_seats = _available_seats_for_trip(trip)
            if available_seats < int(criteria['pax'] or 1):
                continue
            results.append({
                'route_score': route_score,
                'time_score': _time_score(trip, criteria.get('time_pref')),
                'trip': trip,
            })

    results.sort(key=lambda item: (-item['route_score'], item['time_score'], item['trip'].departure_time))
    options = [_trip_to_option(item['trip']) for item in results[:limit]]

    alternative_dates = []
    if not options:
        for route_score, route in matching_routes[:3]:
            future_trips = Trip.query.filter(
                Trip.route_id == route.id,
                Trip.departure_time >= datetime.now(),
                Trip.status.in_(ACTIVE_TRIP_STATUSES)
            ).order_by(Trip.departure_time.asc()).limit(6).all()
            for trip in future_trips:
                date_label = trip.departure_time.strftime('%d/%m/%Y')
                if date_label not in alternative_dates:
                    alternative_dates.append(date_label)
    return options, alternative_dates


def _best_trip_response(criteria):
    options, alternative_dates = _search_trips(criteria, limit=1)
    if options:
        return options[0], None
    return None, ai_service.format_no_trip_response(criteria, alternative_dates)


def _resolve_trip_selection(selection, trip_options):
    if not selection or not trip_options:
        return None

    if selection.get('type') == 'index':
        index = int(selection.get('value') or 0) - 1
        if 0 <= index < len(trip_options):
            return trip_options[index]
        return None

    strategy = selection.get('value')
    if strategy == 'first':
        return trip_options[0]
    if strategy == 'last':
        return trip_options[-1]
    if strategy == 'cheapest':
        return min(trip_options, key=lambda item: (item.get('price_value') or 0, item.get('departure_iso') or ''))
    if strategy == 'earliest':
        return min(trip_options, key=lambda item: item.get('departure_iso') or '')
    if strategy == 'latest':
        return max(trip_options, key=lambda item: item.get('departure_iso') or '')
    return None


def register_ai_routes(app):
    def ai_chatbot():
        data = request.json or {}
        message = (data.get('message') or '').strip()
        if not message:
            return jsonify({'response': ai_service.default_message()})

        state = _get_ai_state()
        known_locations = _get_known_locations()
        parsed = ai_service.parse_message(message, state, known_locations)

        if parsed['reset']:
            state = _default_ai_state()
            _save_ai_state(state)
            return jsonify({
                'response': 'Dạ em đã xoá thông tin tìm chuyến trước đó. Mình nhập lại tuyến mới giúp em nhé.'
            })

        if parsed['show_tickets']:
            logged_in = bool(session.get('user_id'))
            return jsonify({
                'response': ai_service.my_tickets_message(logged_in),
                'action': {
                    'type': 'navigate',
                    'url': '/my-tickets' if logged_in else '/passenger/login',
                    'label': 'Vé của tôi' if logged_in else 'Đăng nhập'
                }
            })

        ui_action = ai_service.resolve_ui_action(
            message,
            data.get('page_actions') or [],
            data.get('current_path') or ''
        )
        if ui_action:
            return jsonify(ui_action)

        if parsed['selection'] and state.get('trip_options'):
            selected = _resolve_trip_selection(parsed['selection'], state['trip_options'])
            if selected:
                response = ai_service.format_booking_redirect(selected)
                _save_ai_state(state)
                return jsonify({
                    'response': response,
                    'action': {
                        'type': 'open_booking',
                        'trip_id': selected['trip_id']
                    }
                })
            return jsonify({'response': ai_service.selection_error(len(state['trip_options']))})

        state, _ = ai_service.merge_state(state, parsed['slots'])

        if parsed['greeting'] and not ai_service.booking_ready(state):
            _save_ai_state(state)
            return jsonify({'response': ai_service.greeting_message()})

        if not ai_service.detect_booking_interest(message, state) and not ai_service.booking_ready(state):
            _save_ai_state(state)
            return jsonify({'response': ai_service.default_message()})

        if not ai_service.booking_ready(state):
            _save_ai_state(state)
            return jsonify({'response': ai_service.next_question(state)})

        # Canonicalize again using DB values to avoid alias drift
        state['from'] = ai_service.canonicalize_location(state['from'], known_locations)
        state['to'] = ai_service.canonicalize_location(state['to'], known_locations)

        options, alternative_dates = _search_trips(state, limit=5)
        if not options:
            state['trip_options'] = []
            _save_ai_state(state)
            return jsonify({'response': ai_service.format_no_trip_response(state, alternative_dates)})

        state['trip_options'] = options
        _save_ai_state(state)

        if len(options) == 1:
            selected = options[0]
            return jsonify({
                'response': ai_service.format_booking_redirect(selected),
                'action': {
                    'type': 'open_booking',
                    'trip_id': selected['trip_id']
                }
            })

        return jsonify({'response': ai_service.format_trip_options(state, options)})

    def search_trip():
        data = request.json or {}
        criteria = _default_ai_state()
        criteria.update({
            'from': (data.get('from') or '').strip() or None,
            'to': (data.get('to') or '').strip() or None,
            'pax': int(data.get('pax') or 1),
        })

        known_locations = _get_known_locations()
        if criteria['from']:
            criteria['from'] = ai_service.canonicalize_location(criteria['from'], known_locations)
        if criteria['to']:
            criteria['to'] = ai_service.canonicalize_location(criteria['to'], known_locations)

        date_info = ai_service.parse_date(data.get('date') or '')
        if date_info:
            criteria['date_iso'] = date_info['date'].isoformat()
            criteria['date_label'] = date_info['label']
        else:
            return jsonify({'trip_id': None, 'message': 'Ngày đi chưa đúng định dạng. Anh/chị thử nhập hôm nay, ngày mai hoặc 15/04 giúp em nhé.'})

        best_trip, no_trip_message = _best_trip_response(criteria)
        if not best_trip:
            return jsonify({'trip_id': None, 'message': no_trip_message})

        return jsonify({
            'trip_id': best_trip['trip_id'],
            'route': best_trip['route_text'],
            'time': best_trip['time_text'],
            'available_seats': best_trip['available_seats']
        })

    def ai_admin_insights():
        company_id = session['company_id']

        revenue_tickets = db.session.query(db.func.sum(Booking.ticket_price)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id, Booking.status == 'CONFIRMED').scalar() or 0

        trips = Trip.query.join(Route).filter(Route.company_id == company_id).all()
        total_capacity = sum([t.bus.total_seats for t in trips])
        total_booked = Booking.query.join(Trip).join(Route)\
            .filter(Route.company_id == company_id, Booking.status == 'CONFIRMED').count()

        occupancy_rate = (total_booked / total_capacity * 100) if total_capacity > 0 else 0

        route_stats = db.session.query(
            Route.start_point, Route.end_point,
            db.func.count(Booking.id).label('booking_count'),
            db.func.sum(Booking.ticket_price).label('revenue')
        ).join(Trip).join(Booking).filter(Route.company_id == company_id, Booking.status == 'CONFIRMED')\
            .group_by(Route.id).all()

        company_data = {
            'total_revenue': revenue_tickets,
            'occupancy_rate': occupancy_rate,
            'total_trips': len(trips),
            'route_performance': [{
                'route': f"{r[0]} - {r[1]}",
                'bookings': r[2],
                'revenue': r[3] or 0
            } for r in route_stats]
        }

        analysis = ai_service.get_admin_insights(company_data)
        return jsonify({'analysis': analysis})

    def ai_suggestions_api():
        user_id = session.get('user_id')
        user_history = None
        if user_id:
            user = User.query.get(user_id)
            if user:
                user_history = list(set([f"{b.trip.route.start_point} - {b.trip.route.end_point}" for b in user.bookings[-5:]]))

        upcoming_trips = Trip.query.filter(Trip.departure_time >= datetime.now()).order_by(Trip.departure_time).limit(20).all()
        trips_data = [{
            'id': t.id,
            'route': f"{t.route.start_point} - {t.route.end_point}",
            'time': t.departure_time.strftime('%d/%m %H:%M'),
            'price': t.route.base_price * t.price_multiplier,
            'type': t.bus.bus_type
        } for t in upcoming_trips]

        suggestions = ai_service.get_smart_suggestions(trips_data, user_history)
        return jsonify({'suggestions': suggestions})

    app.add_url_rule('/api/ai/chatbot', view_func=ai_chatbot, methods=['POST'])
    app.add_url_rule('/api/search-trip', view_func=search_trip, methods=['POST'])
    app.add_url_rule('/api/ai/admin-insights', view_func=company_login_required(ai_admin_insights), methods=['GET'])
    app.add_url_rule('/api/ai/suggestions', view_func=ai_suggestions_api, methods=['GET'])
