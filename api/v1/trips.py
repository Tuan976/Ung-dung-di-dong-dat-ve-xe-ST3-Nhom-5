from flask import request
from sqlalchemy import func
from datetime import datetime
from models import Trip, Route, Bus, Company
from extensions import db
from constants import VIETNAM_PROVINCES
from ai_service import ai_service
import json

from . import api_v1_bp
from .errors import api_success, api_error


def _normalize_loc(value):
    if not value:
        return ""
    norm = ai_service.normalize_text(value)
    for prefix in ("tp ", "thanh pho ", "tinh "):
        if norm.startswith(prefix):
            norm = norm[len(prefix):].strip()
    if norm in ("sai gon", "hcm", "tphcm"):
        return "ho chi minh"
    return norm


def _loc_matches(actual, expected):
    if not expected:
        return True
    a = _normalize_loc(actual)
    e = _normalize_loc(expected)
    if not e:
        return True
    return e in a or a in e


@api_v1_bp.route('/locations', methods=['GET'])
def get_locations():
    """Trả về danh sách tỉnh/thành phố từ database + danh sách 63 tỉnh thành."""
    starts = db.session.query(Route.start_point).distinct().all()
    ends = db.session.query(Route.end_point).distinct().all()
    db_locations = [r[0].strip() for r in starts if r[0]] + [r[0].strip() for r in ends if r[0]]
    combined = sorted(set(db_locations + list(VIETNAM_PROVINCES)))
    return api_success(data={"locations": combined})


@api_v1_bp.route('/trips', methods=['GET'])
def get_trips():
    from_loc = request.args.get('from', '').strip()
    to_loc = request.args.get('to', '').strip()
    date_str = request.args.get('date', '').strip()
    page = request.args.get('page', 1, type=int)
    limit = request.args.get('limit', 50, type=int)

    query = Trip.query.join(Route).filter(Trip.status == 'Scheduled')

    # Lọc tuyến đường bằng Python Unicode + bỏ dấu tiếng Việt
    # để tránh lỗi SQLite LOWER() không hỗ trợ chữ in hoa tiếng Việt (Đ, Ấ, Ố, Ư...)
    if from_loc or to_loc:
        all_routes = Route.query.all()
        matching_route_ids = [
            r.id for r in all_routes
            if _loc_matches(r.start_point, from_loc) and _loc_matches(r.end_point, to_loc)
        ]
        if not matching_route_ids:
            return api_success(
                data={
                    "items": [],
                    "pagination": {
                        "page": page,
                        "limit": limit,
                        "total": 0,
                        "total_pages": 0,
                    },
                }
            )
        query = query.filter(Trip.route_id.in_(matching_route_ids))

    if date_str:
        try:
            target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            query = query.filter(func.date(Trip.departure_time) == target_date)
        except ValueError:
            return api_error(message="Ngày không hợp lệ (định dạng YYYY-MM-DD)", error_code="INVALID_DATE", status=400)

    query = query.order_by(Trip.departure_time)
    paginated = query.paginate(page=page, per_page=limit, error_out=False)

    items = []
    for trip in paginated.items:
        booked_count = sum(1 for b in trip.bookings if b.status in ['CONFIRMED', 'HOLD'])
        total_seats = trip.bus.total_seats if trip.bus else 34
        available_seats = max(0, total_seats - booked_count)

        items.append({
            "id": trip.id,
            "route_name": f"{trip.route.start_point} - {trip.route.end_point}",
            "company_name": trip.route.company.name if trip.route and trip.route.company else "Nhà xe Triply",
            "departure_date": trip.departure_time.strftime('%Y-%m-%d'),
            "departure_time": trip.departure_time.strftime('%H:%M'),
            "arrival_time": trip.arrival_time.strftime('%H:%M') if trip.arrival_time else "",
            "departure_station": trip.route.start_point,
            "arrival_station": trip.route.end_point,
            "price": (trip.route.base_price or 0) * (trip.price_multiplier or 1.0),
            "available_seats": available_seats,
            "total_seats": total_seats,
            "bus_type": trip.bus.bus_type if trip.bus else "sleeper",
        })

    return api_success(
        data={
            "items": items,
            "pagination": {
                "page": paginated.page,
                "limit": paginated.per_page,
                "total": paginated.total,
                "total_pages": paginated.pages,
            },
        }
    )


@api_v1_bp.route('/trips/<int:trip_id>', methods=['GET'])
def get_trip_detail(trip_id):
    trip = Trip.query.get(trip_id)
    if not trip:
        return api_error(message="Không tìm thấy chuyến xe", error_code="TRIP_NOT_FOUND", status=404)

    booked_seats = [b.seat_number for b in trip.bookings if b.status in ['CONFIRMED', 'HOLD']]

    try:
        raw_seat_map = json.loads(trip.bus.seat_map) if trip.bus and trip.bus.seat_map else None
        if isinstance(raw_seat_map, dict) and 'seats' in raw_seat_map:
            seat_map = [str(s['id']) for s in raw_seat_map['seats'] if isinstance(s, dict) and s.get('id')]
        elif isinstance(raw_seat_map, list):
            if raw_seat_map and isinstance(raw_seat_map[0], dict) and 'rows' in raw_seat_map[0]:
                seat_map = [
                    str(s['id'])
                    for floor in raw_seat_map
                    for row in floor.get('rows', [])
                    for s in row
                    if isinstance(s, dict) and s.get('id')
                ]
            else:
                seat_map = [str(s['id'] if isinstance(s, dict) else s) for s in raw_seat_map if s]
        else:
            seat_map = []
    except Exception:
        seat_map = []

    total_seats = trip.bus.total_seats if trip.bus and trip.bus.total_seats else 34
    if not seat_map:
        half = (total_seats + 1) // 2
        seat_map = [f"A{i:02d}" for i in range(1, half + 1)] + [f"B{i:02d}" for i in range(1, total_seats - half + 1)]

    available_seats = max(0, total_seats - len(booked_seats))

    return api_success(
        data={
            "id": trip.id,
            "route_name": f"{trip.route.start_point} - {trip.route.end_point}",
            "company_name": trip.route.company.name if trip.route and trip.route.company else "Nhà xe Triply",
            "departure_date": trip.departure_time.strftime('%Y-%m-%d'),
            "departure_time": trip.departure_time.strftime('%H:%M'),
            "arrival_time": trip.arrival_time.strftime('%H:%M') if trip.arrival_time else "",
            "departure_station": trip.route.start_point,
            "arrival_station": trip.route.end_point,
            "price": (trip.route.base_price or 0) * (trip.price_multiplier or 1.0),
            "available_seats": available_seats,
            "total_seats": total_seats,
            "booked_seats": booked_seats,
            "seat_map": seat_map,
            "bus_type": trip.bus.bus_type if trip.bus else "sleeper",
        }
    )
