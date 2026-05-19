
import csv
import io
from datetime import datetime, timedelta

from flask import flash, jsonify, redirect, render_template, request, session, url_for, send_from_directory
from werkzeug.security import generate_password_hash

from constants import VIETNAM_PROVINCES
from decorators import company_login_required, passenger_login_required
from extensions import db
from models import Booking, Bus, FoodOrder, Route, Trip, User


INVALID_TRIP_STATUSES = {'Cancelled', 'Completed', 'Broken'}


def _now():
    return datetime.now()


def _extract_display_seat_number(seat_number):
    seat_str = str(seat_number or '')
    if seat_str.startswith('~') and seat_str.count('~') >= 2:
        parts = seat_str.split('~')
        if len(parts) >= 3 and parts[1]:
            return parts[1]
    return seat_str


def _normalize_booking_for_display(booking):
    if booking is not None:
        booking.seat_number = _extract_display_seat_number(booking.seat_number)
    return booking


def _archive_booking_for_reuse(booking, reason='EXPIRED'):
    if booking is None:
        return False

    seat_str = str(booking.seat_number or '')
    if seat_str.startswith('~') and booking.status == 'CANCELLED':
        booking.expires_at = None
        return False

    original = _extract_display_seat_number(booking.seat_number) or 'SEAT'
    encoded = format(int(booking.id), 'x').upper()
    archived = f'~{original}~{encoded}'
    if len(archived) > 10:
        archived = f'~{original[:3]}~{encoded[-5:]}'[:10]

    booking.seat_number = archived
    booking.status = 'CANCELLED'
    booking.expires_at = None

    if reason == 'EXPIRED':
        if booking.payment_status != 'Paid':
            booking.payment_status = 'Expired'
        booking.payment_id = None
    elif reason == 'CANCELLED':
        if booking.payment_status == 'Paid':
            booking.payment_status = 'Refund Pending'
        else:
            booking.payment_status = 'Cancelled'
        booking.payment_id = None

    return True


def _cleanup_expired_holds_for_user(user_id):
    now = _now()
    stale_holds = Booking.query.filter(
        Booking.user_id == user_id,
        Booking.status == 'HOLD',
        Booking.expires_at.isnot(None),
        Booking.expires_at <= now
    ).all()

    changed = False
    for booking in stale_holds:
        changed = _archive_booking_for_reuse(booking, reason='EXPIRED') or changed

    if changed:
        db.session.commit()

    return changed


def _booking_is_active_hold(booking, now):
    return (
        booking.status == 'HOLD'
        and booking.expires_at is not None
        and booking.expires_at > now
        and booking.trip.departure_time > now
        and booking.trip.status not in INVALID_TRIP_STATUSES
    )


def _booking_is_active_confirmed(booking, now):
    return (
        booking.status == 'CONFIRMED'
        and booking.payment_status == 'Paid'
        and booking.trip.departure_time > now
        and booking.trip.status not in INVALID_TRIP_STATUSES
    )


def _can_view_ticket(booking):
    return booking.status == 'CONFIRMED' and booking.payment_status == 'Paid'


def register_public_routes(app):
    def index():
        start_point = request.args.get('start_point', '').strip()
        end_point = request.args.get('end_point', '').strip()
        date_str = request.args.get('date', '').strip()

        query = Trip.query.join(Route).filter(
            Trip.status.notin_(list(INVALID_TRIP_STATUSES))
        )

        if date_str:
            try:
                search_date = datetime.strptime(date_str, '%Y-%m-%d').date()
                query = query.filter(db.func.date(Trip.departure_time) == search_date)
            except ValueError:
                pass
        else:
            query = query.filter(Trip.departure_time > _now())

        if start_point:
            query = query.filter(Route.start_point.ilike(f'{start_point}'))

        if end_point:
            query = query.filter(Route.end_point.ilike(f'{end_point}'))

        trips = query.order_by(Trip.departure_time).all()

        return_date_str = request.args.get('return_date', '').strip()
        return_trips = []
        if return_date_str and start_point and end_point:
            try:
                r_date = datetime.strptime(return_date_str, '%Y-%m-%d').date()
                r_query = Trip.query.join(Route).filter(
                    Trip.status.notin_(list(INVALID_TRIP_STATUSES)),
                    db.func.date(Trip.departure_time) == r_date,
                    Route.start_point.ilike(f'{end_point}'),
                    Route.end_point.ilike(f'{start_point}')
                ).order_by(Trip.departure_time)
                return_trips = r_query.all()
            except ValueError:
                pass

        all_routes = Route.query.all()
        db_points = sorted(list(set(
            [r.start_point for r in all_routes] + [r.end_point for r in all_routes]
        )))
        all_provinces_set = list(dict.fromkeys(db_points + [p for p in VIETNAM_PROVINCES if p not in db_points]))
        all_provinces = sorted(all_provinces_set)

        today = _now().strftime('%Y-%m-%d')

        # Try to serve React index.html first
        try:
            return send_from_directory(app.static_folder, 'index.html')
        except:
            # Fallback to Jinja2 template index.html if React build is missing
            return render_template('index.html')

    def logout():
        session.clear()
        flash('Đã đăng xuất thành công.')
        return redirect(url_for('index'))

    def terms():
        return render_template('terms.html')

    def privacy():
        return render_template('privacy.html')

    def my_tickets():
        user_id = session['user_id']
        user = User.query.get(user_id)

        _cleanup_expired_holds_for_user(user_id)

        now = _now()
        all_bookings = Booking.query.filter_by(user_id=user_id).join(Trip).order_by(Trip.departure_time.desc()).all()

        active_bookings = []
        history_bookings = []

        for booking in all_bookings:
            booking.food_orders = FoodOrder.query.filter_by(booking_id=booking.id).all()
            _normalize_booking_for_display(booking)

            if _booking_is_active_hold(booking, now) or _booking_is_active_confirmed(booking, now):
                active_bookings.append(booking)
            else:
                history_bookings.append(booking)

        return render_template(
            'my_tickets.html',
            active_bookings=active_bookings,
            history_bookings=history_bookings,
            user=user,
            active_page='history'
        )

    def admin_bus_schedule(bus_id):
        bus = Bus.query.get_or_404(bus_id)
        if bus.company_id != session['company_id']:
            flash('Truy cập bị từ chối!')
            return redirect(url_for('admin_buses_page'))

        search = request.args.get('search', '').strip()
        sort_by = request.args.get('sort_by', 'date_desc')

        query = Trip.query.filter_by(bus_id=bus_id).join(Route)

        if search:
            search_term = f'%{search}%'
            query = query.filter(
                (Route.start_point.ilike(search_term))
                | (Route.end_point.ilike(search_term))
                | (Trip.driver_name.ilike(search_term))
                | (Trip.assistant_name.ilike(search_term))
            )

        if sort_by == 'date_asc':
            query = query.order_by(Trip.departure_time.asc())
        elif sort_by == 'status':
            query = query.order_by(Trip.status)
        else:
            query = query.order_by(Trip.departure_time.desc())

        trips = query.all()

        return render_template(
            'admin/bus_schedule_plan.html',
            bus=bus,
            trips=trips,
            now=_now(),
            search=search,
            sort_by=sort_by
        )

    def export_bus_schedule(bus_id):
        bus = Bus.query.get_or_404(bus_id)
        trips = Trip.query.filter_by(bus_id=bus_id).order_by(Trip.departure_time).all()

        def generate():
            data = io.StringIO()
            w = csv.writer(data)

            w.writerow(('Mã chuyến', 'Tuyến đường', 'Ngày đi', 'Giờ đi', 'Tài xế', 'Phụ xe', 'Trạng thái', 'Doanh thu vé'))
            yield data.getvalue()
            data.seek(0)
            data.truncate(0)

            for trip in trips:
                revenue = 0
                for booking in trip.bookings:
                    if booking.status == 'CONFIRMED' and booking.payment_status == 'Paid':
                        revenue += booking.ticket_price

                w.writerow((
                    trip.id,
                    f'{trip.route.start_point} - {trip.route.end_point}',
                    trip.departure_time.strftime('%d/%m/%Y'),
                    trip.departure_time.strftime('%H:%M'),
                    trip.driver_name or 'N/A',
                    trip.assistant_name or 'N/A',
                    trip.status,
                    revenue
                ))
                yield data.getvalue()
                data.seek(0)
                data.truncate(0)

        response = app.response_class(generate(), mimetype='text/csv')
        response.headers.set('Content-Disposition', 'attachment', filename=f'lich_trinh_xe_{bus.license_plate}.csv')
        return response

    def my_profile():
        user = User.query.get(session['user_id'])
        if request.method == 'POST':
            user.name = request.form.get('name')
            user.phone = request.form.get('phone')

            new_pass = request.form.get('new_password')
            if new_pass:
                user.password = generate_password_hash(new_pass)

            db.session.commit()
            flash('Đã cập nhật hồ sơ thành công!')
            return redirect(url_for('my_profile'))

        return render_template('passenger/profile.html', user=user, active_page='profile')

    def view_ticket(booking_id):
        booking = Booking.query.get_or_404(booking_id)
        if booking.user_id != session['user_id']:
            flash('Không tìm thấy vé!')
            return redirect(url_for('index'))

        if not _can_view_ticket(booking):
            if booking.status == 'HOLD' and booking.expires_at and booking.expires_at > _now():
                flash('Vé này đang chờ thanh toán. Vui lòng hoàn tất thanh toán để xem vé điện tử.')
                return redirect(url_for('payment', booking_id=booking.id))

            flash('Vé này chưa hợp lệ để xem dưới dạng vé điện tử.')
            return redirect(url_for('my_tickets'))

        _normalize_booking_for_display(booking)
        return render_template('ticket.html', booking=booking)

    def cancel_ticket(booking_id):
        booking = Booking.query.get_or_404(booking_id)
        if booking.user_id != session['user_id']:
            return 'Unauthorized', 403

        now = _now()

        if booking.status == 'HOLD':
            _archive_booking_for_reuse(booking, reason='CANCELLED')
            db.session.commit()
            flash('Đã hủy giữ chỗ thành công.')
            return redirect(url_for('my_tickets'))

        if booking.status != 'CONFIRMED' or booking.payment_status != 'Paid':
            flash('Vé này không còn hợp lệ để hủy.')
            return redirect(url_for('my_tickets'))

        if booking.trip.departure_time - now < timedelta(hours=24):
            flash('Không thể hủy vé trước giờ khởi hành dưới 24h!')
            return redirect(url_for('my_tickets'))

        _archive_booking_for_reuse(booking, reason='CANCELLED')
        db.session.commit()
        flash('Đã hủy vé thành công.')
        return redirect(url_for('my_tickets'))

    def api_provinces():
        try:
            all_routes = Route.query.all()
            points = []
            for r in all_routes:
                if r.start_point: points.append(r.start_point.strip())
                if r.end_point: points.append(r.end_point.strip())
            
            db_points = sorted(list(set(points)))
            return jsonify(db_points)
        except Exception as e:
            print(f"API Provinces Error: {e}")
            return jsonify([]), 200

    def api_search_trips():
        try:
            start_point = request.args.get('start_point', '').strip()
            end_point = request.args.get('end_point', '').strip()
            date_str = request.args.get('date', '').strip()

            query = Trip.query.join(Route).filter(
                Trip.status.notin_(list(INVALID_TRIP_STATUSES))
            )

            if date_str:
                try:
                    search_date = datetime.strptime(date_str, '%Y-%m-%d').date()
                    query = query.filter(db.func.date(Trip.departure_time) == search_date)
                except ValueError:
                    pass
            else:
                query = query.filter(Trip.departure_time > _now())

            if start_point:
                query = query.filter(Route.start_point.ilike(f'{start_point}'))
            if end_point:
                query = query.filter(Route.end_point.ilike(f'{end_point}'))

            trips = query.order_by(Trip.departure_time).all()
            
            results = []
            for t in trips:
                try:
                    # Defensive data gathering
                    bus_type = t.bus.bus_type if t.bus else "Ghế ngồi"
                    company_name = "Hutech Bus"
                    if t.bus and t.bus.company:
                        company_name = t.bus.company.name
                    
                    total_seats = t.bus.total_seats if t.bus else 45
                    base_price = t.route.base_price if t.route else 200000
                    
                    results.append({
                        'id': t.id,
                        'start_point': t.route.start_point if t.route else "Unknown",
                        'end_point': t.route.end_point if t.route else "Unknown",
                        'departure_time': t.departure_time.isoformat() if t.departure_time else datetime.now().isoformat(),
                        'price': base_price * (t.price_multiplier or 1.0),
                        'bus_type': bus_type,
                        'company_name': company_name,
                        'rating': 4.9,
                        'available_seats': total_seats - Booking.query.filter_by(trip_id=t.id, status='CONFIRMED').count()
                    })
                except Exception as e:
                    print(f"Error processing trip {t.id}: {e}")
                    continue
            
            return jsonify(results)
        except Exception as e:
            print(f"API Search Error: {e}")
            return jsonify([]), 500

    app.add_url_rule('/', view_func=index)
    app.add_url_rule('/logout', view_func=logout)
    app.add_url_rule('/terms', view_func=terms)
    app.add_url_rule('/privacy', view_func=privacy)
    app.add_url_rule('/my-tickets', view_func=passenger_login_required(my_tickets))
    app.add_url_rule('/admin/bus/<int:bus_id>/schedule', view_func=company_login_required(admin_bus_schedule))
    app.add_url_rule('/admin/bus/<int:bus_id>/export', view_func=company_login_required(export_bus_schedule))
    app.add_url_rule('/profile', view_func=passenger_login_required(my_profile), methods=['GET', 'POST'])
    app.add_url_rule('/ticket/<int:booking_id>', view_func=passenger_login_required(view_ticket))
    app.add_url_rule('/api/cancel/<int:booking_id>', view_func=passenger_login_required(cancel_ticket), methods=['POST'])

    @app.errorhandler(404)
    def handle_404(e):
        if request.path.startswith('/api/'):
            return jsonify({"error": "API route not found"}), 404
        return send_from_directory(app.static_folder, 'index.html')
    
    def api_popular_routes():
        try:
            # Lấy 4 tuyến đường có sẵn
            routes = Route.query.limit(4).all()
            results = []
            for i, r in enumerate(routes):
                results.append({
                    'id': r.id,
                    'from': r.start_point or "Chưa xác định",
                    'to': r.end_point or "Chưa xác định",
                    'price': "{:,.0f}".format(r.base_price or 0).replace(',','.'),
                    'image': f"/routes/{i+1}.png"
                })
            return jsonify(results)
        except Exception as e:
            print(f"API Popular Routes Error: {e}")
            return jsonify([]), 200

    def api_book():
        data = request.json
        trip_id = data.get('trip_id')
        seats = data.get('seats', []) # List of seat IDs like ['A1', 'A2']
        name = data.get('name')
        phone = data.get('phone')
        pickup = data.get('pickup')
        dropoff = data.get('dropoff')
        payment_method = data.get('payment_method', 'cash')

        if not trip_id or not seats or not name or not phone:
            return jsonify({'success': False, 'message': 'Thiếu thông tin bắt buộc'}), 200

        trip = Trip.query.get(trip_id)
        if not trip:
            return jsonify({'success': False, 'message': 'Chuyến xe không tồn tại'}), 200

        try:
            import random
            import string
            import time
            from extensions import payos_client
            from payos.type import ItemData, PaymentData
            
            is_payos = (payment_method == 'payos')
            order_code = int(time.time() * 1000) + random.randint(1, 1000) if is_payos else None
            
            ticket_price = trip.route.base_price * trip.price_multiplier
            total_amount = int(ticket_price) * len(seats)
            
            # Check if seats are already occupied
            existing_bookings = Booking.query.filter(
                Booking.trip_id == trip_id,
                Booking.seat_number.in_(seats),
                Booking.status.in_(['CONFIRMED', 'HOLD'])
            ).all()
            if existing_bookings:
                return jsonify({'success': False, 'message': 'Một hoặc nhiều ghế đã được người khác đặt. Vui lòng chọn ghế khác.'}), 200
            
            # Lưu từng ghế thành một bản ghi Booking
            booked_ticket_codes = []
            for seat_code in seats:
                ticket_code = 'HT' + ''.join(random.choices(string.digits, k=8))
                booked_ticket_codes.append(ticket_code)
                new_booking = Booking(
                    ticket_code=ticket_code,
                    trip_id=trip_id,
                    user_id=session.get('user_id'),
                    passenger_name=name,
                    passenger_phone=phone,
                    seat_number=seat_code,
                    pickup_point=pickup,
                    dropoff_point=dropoff,
                    status='HOLD' if is_payos else 'CONFIRMED',
                    payment_status='Unpaid' if is_payos else 'Pending',
                    payment_method='PayOS' if is_payos else 'Tiền mặt',
                    payment_id=str(order_code) if is_payos else None,
                    ticket_price=ticket_price,
                    booking_time=datetime.now()
                )
                db.session.add(new_booking)
            
            db.session.commit()
            
            if is_payos:
                if payos_client is None:
                    return jsonify({'success': False, 'message': 'Cổng thanh toán PayOS chưa được cấu hình.'}), 200
                    
                domain = request.host_url.rstrip('/')
                # Return frontend URL for success/cancel
                # React frontend is typically on port 5173
                react_domain = domain.replace('5000', '5173')
                
                item = ItemData(
                    name=f"Ve xe {trip.route.start_point} - {trip.route.end_point} ({len(seats)} ghe)",
                    quantity=1,
                    price=total_amount
                )

                payment_data = PaymentData(
                    orderCode=order_code,
                    amount=total_amount,
                    description=f"Thanh toan Hutech Bus",
                    items=[item],
                    cancelUrl=f"{domain}/api/payos/cancel/{order_code}?redirect={react_domain}/",
                    returnUrl=f"{react_domain}/check-ticket?phone={phone}&code={booked_ticket_codes[0]}"
                )
                
                response = payos_client.createPaymentLink(payment_data)
                return jsonify({'success': True, 'checkoutUrl': response.checkoutUrl})
            return jsonify({'success': True, 'message': 'Đặt vé thành công!', 'ticket_codes': booked_ticket_codes})
        except Exception as e:
            db.session.rollback()
            return jsonify({'success': False, 'message': str(e)}), 200

    def api_payos_cancel(order_code):
        bookings = Booking.query.filter_by(payment_id=str(order_code)).all()
        from routes_booking import _archive_booking_for_reuse
        for b in bookings:
            if b.payment_status != 'Paid':
                _archive_booking_for_reuse(b, reason='CANCELLED')
        db.session.commit()
        redirect_url = request.args.get('redirect', '/')
        return redirect(redirect_url)

    def api_check_ticket():
        phone = request.args.get('phone')
        code = request.args.get('code')
        if not phone or not code:
            return jsonify({'success': False, 'message': 'Vui lòng cung cấp số điện thoại và mã vé'})
            
        booking = Booking.query.filter_by(passenger_phone=phone, ticket_code=code).first()
        if not booking:
            return jsonify({'success': False, 'message': 'Không tìm thấy vé. Vui lòng kiểm tra lại.'})
            
        return jsonify({
            'success': True,
            'ticket': {
                'ticket_code': booking.ticket_code,
                'passenger_name': booking.passenger_name,
                'route': f"{booking.trip.route.start_point} - {booking.trip.route.end_point}",
                'departure_time': booking.trip.departure_time.isoformat(),
                'seat_number': booking.seat_number,
                'pickup_point': booking.pickup_point,
                'ticket_price': booking.ticket_price,
                'status': booking.status,
                'payment_status': booking.payment_status
            }
        })

    def api_trip_details(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        occupied_seats = [b.seat_number for b in Booking.query.filter_by(trip_id=trip_id).filter(Booking.status != 'CANCELLED').all()]
        
        # Sơ đồ ghế mặc định nếu không có trong DB
        import json
        raw_seat_map = None
        try:
            if trip.bus and trip.bus.seat_map:
                raw_seat_map = json.loads(trip.bus.seat_map)
        except:
            pass

        def normalize_seat_map(raw, occupied):
            """Convert any seat_map format to [{floor, rows:[[seat]]}]"""
            if not raw:
                return None
            
            # Format 1: Already correct array format [{floor, rows}]
            if isinstance(raw, list) and len(raw) > 0 and isinstance(raw[0], dict) and 'rows' in raw[0]:
                # Attach status to each seat
                for floor_data in raw:
                    for row in floor_data.get('rows', []):
                        for seat in row:
                            seat['status'] = 'occupied' if seat.get('id') in occupied else 'available'
                return raw
            
            # Format 2: Object with seats list {seats:[{id, floor, row, col}], floors, cols}
            if isinstance(raw, dict) and 'seats' in raw:
                seats_list = raw['seats']
                num_floors = raw.get('floors', 1)
                floor_names = ['Tầng dưới', 'Tầng trên', 'Tầng 3']
                
                # Group seats by floor then by row
                floors_dict = {}
                for seat in seats_list:
                    f = seat.get('floor', 0)
                    r = seat.get('row', 0)
                    if f not in floors_dict:
                        floors_dict[f] = {}
                    if r not in floors_dict[f]:
                        floors_dict[f][r] = []
                    floors_dict[f][r].append({
                        'id': seat.get('id', '??'),
                        'name': seat.get('id', '??'),
                        'status': 'occupied' if seat.get('id') in occupied else 'available',
                        'type': seat.get('type', 'standard')
                    })
                
                result = []
                for fi in sorted(floors_dict.keys()):
                    floor_rows = []
                    for ri in sorted(floors_dict[fi].keys()):
                        floor_rows.append(floors_dict[fi][ri])
                    result.append({
                        'floor': floor_names[fi] if fi < len(floor_names) else f'Tầng {fi+1}',
                        'rows': floor_rows
                    })
                return result
            
            return None

        seat_map_normalized = normalize_seat_map(raw_seat_map, occupied_seats)
        
        if not seat_map_normalized:
            # Default 2-floor sleeper layout
            seat_map_normalized = []
            for floor in ['Tầng dưới', 'Tầng trên']:
                rows = []
                for r in range(1, 7):
                    cols = []
                    for c in ['A', 'B', 'C']:
                        seat_code = f"{c}{r}{'D' if floor == 'Tầng dưới' else 'T'}"
                        cols.append({
                            'id': seat_code,
                            'name': f"{c}{r}",
                            'status': 'occupied' if seat_code in occupied_seats else 'available',
                            'type': 'vip' if r <= 2 else 'standard'
                        })
                    rows.append(cols)
                seat_map_normalized.append({'floor': floor, 'rows': rows})
        
        seat_map = seat_map_normalized

        bus_type = trip.bus.bus_type if trip.bus else "Giường nằm"
        company_name = "Hutech Bus"
        if trip.bus and trip.bus.company:
            company_name = trip.bus.company.name
            
        base_price = trip.route.base_price if trip.route else 200000

        return jsonify({
            'id': trip.id,
            'bus_type': bus_type,
            'company_name': company_name,
            'departure_time': trip.departure_time.isoformat() if trip.departure_time else datetime.now().isoformat(),
            'price': base_price * (trip.price_multiplier or 1.0),
            'seat_map': seat_map,
            'occupied_seats': occupied_seats
        })

    # React API Endpoints
    app.add_url_rule('/api/provinces', view_func=api_provinces)
    app.add_url_rule('/api/search', view_func=api_search_trips)
    app.add_url_rule('/api/trip/<int:trip_id>', view_func=api_trip_details)
    app.add_url_rule('/api/popular-routes', view_func=api_popular_routes)
    app.add_url_rule('/api/book', view_func=api_book, methods=['POST'])
    app.add_url_rule('/api/payos/cancel/<int:order_code>', view_func=api_payos_cancel, methods=['GET'])
    app.add_url_rule('/api/check-ticket', view_func=api_check_ticket, methods=['GET'])
