from flask import request
from sqlalchemy import func
from datetime import datetime
from models import Trip, Route, Bus, Company
from extensions import db
from constants import VIETNAM_PROVINCES
import json

from . import api_v1_bp
from .errors import api_success, api_error

@api_v1_bp.route('/locations', methods=['GET'])
def get_locations():
    """Trả về danh sách tỉnh/thành phố từ database (điểm xuất phát/điểm đến thực tế)."""
    # Lấy các địa điểm thực sự có trong DB (từ các tuyến đường)
    starts = db.session.query(Route.start_point).distinct().all()
    ends = db.session.query(Route.end_point).distinct().all()
    db_locations = sorted(set(
        [r[0] for r in starts if r[0]] + [r[0] for r in ends if r[0]]
    ))
    # Nếu DB chưa có dữ liệu, fallback về VIETNAM_PROVINCES
    locations = db_locations if db_locations else sorted(VIETNAM_PROVINCES)
    return api_success(data={"locations": locations})


@api_v1_bp.route('/trips', methods=['GET'])
def get_trips():
    from_loc = request.args.get('from')
    to_loc = request.args.get('to')
    date_str = request.args.get('date')
    page = request.args.get('page', 1, type=int)
    limit = request.args.get('limit', 20, type=int)

    query = Trip.query.join(Route).filter(Trip.status == 'Scheduled')

    if from_loc:
        query = query.filter(func.lower(Route.start_point).like(f'%{from_loc.lower()}%'))
    if to_loc:
        query = query.filter(func.lower(Route.end_point).like(f'%{to_loc.lower()}%'))
    if date_str:
        try:
            target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            query = query.filter(func.date(Trip.departure_time) == target_date)
        except ValueError:
            return api_error(message="Ngày không hợp lệ (định dạng YYYY-MM-DD)", error_code="INVALID_DATE", status=400)

    # Order by departure time
    query = query.order_by(Trip.departure_time)

    paginated = query.paginate(page=page, per_page=limit, error_out=False)
    
    items = []
    for trip in paginated.items:
        # Calculate available seats
        booked_count = sum(1 for b in trip.bookings if b.status in ['CONFIRMED', 'HOLD'])
        total_seats = trip.bus.total_seats
        available_seats = total_seats - booked_count

        items.append({
            "id": trip.id,
            "route_name": f"{trip.route.start_point} - {trip.route.end_point}",
            "company_name": trip.route.company.name,
            "departure_date": trip.departure_time.strftime('%Y-%m-%d'),
            "departure_time": trip.departure_time.strftime('%H:%M'),
            "arrival_time": trip.arrival_time.strftime('%H:%M') if trip.arrival_time else "",
            "departure_station": trip.route.start_point,
            "arrival_station": trip.route.end_point,
            "price": trip.route.base_price * trip.price_multiplier,
            "available_seats": available_seats,
            "total_seats": total_seats,
            "bus_type": trip.bus.bus_type
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

@api_v1_bp.route('/trips/<int:trip_id>', methods=['GET'])
def get_trip_detail(trip_id):
    trip = Trip.query.get(trip_id)
    if not trip:
        return api_error(message="Không tìm thấy chuyến xe", error_code="TRIP_NOT_FOUND", status=404)

    # Calculate available seats (assuming bookings are in models)
    booked_seats = [b.seat_number for b in trip.bookings if b.status in ['CONFIRMED', 'HOLD']]
    
    try:
        raw_seat_map = json.loads(trip.bus.seat_map)
        if isinstance(raw_seat_map, dict) and 'seats' in raw_seat_map:
            seat_map = [s['id'] for s in raw_seat_map['seats']]
        elif isinstance(raw_seat_map, list):
            seat_map = raw_seat_map
        else:
            seat_map = []
    except:
        seat_map = []

    total_seats = trip.bus.total_seats
    available_seats = total_seats - len(booked_seats)

    return api_success(
        data={
            "id": trip.id,
            "route_name": f"{trip.route.start_point} - {trip.route.end_point}",
            "company_name": trip.route.company.name,
            "departure_date": trip.departure_time.strftime('%Y-%m-%d'),
            "departure_time": trip.departure_time.strftime('%H:%M'),
            "arrival_time": trip.arrival_time.strftime('%H:%M') if trip.arrival_time else "",
            "departure_station": trip.route.start_point,
            "arrival_station": trip.route.end_point,
            "price": trip.route.base_price * trip.price_multiplier,
            "available_seats": available_seats,
            "total_seats": total_seats,
            "booked_seats": booked_seats,
            "seat_map": seat_map,
            "bus_type": trip.bus.bus_type
        }
    )
