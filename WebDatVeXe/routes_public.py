
import csv
import io
from datetime import datetime, timedelta

from flask import flash, redirect, render_template, request, session, url_for
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

        return render_template(
            'index.html',
            trips=trips,
            return_trips=return_trips,
            start_points=sorted(list(set([r.start_point for r in all_routes]))),
            end_points=sorted(list(set([r.end_point for r in all_routes]))),
            all_provinces=all_provinces,
            today=today,
            selected_start=start_point,
            selected_end=end_point,
            selected_date=date_str,
            selected_return_date=return_date_str,
        )

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
