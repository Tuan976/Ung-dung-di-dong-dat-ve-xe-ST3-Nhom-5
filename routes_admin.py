import csv
import io
import json
import os
import time
from docx import Document
from docx.shared import Inches, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH
from datetime import datetime, timedelta

from flask import flash, jsonify, redirect, render_template, request, send_file, session, url_for
from flask_mail import Message
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash

from constants import VIETNAM_PROVINCES
from decorators import admin_only, company_login_required, staff_role_required
from extensions import db, mail
from models import Assistant, Booking, Bus, Cargo, Driver, FoodOrder, MenuItem, Office, RestStop, Route, Staff, Trip


def auto_complete_trips():
    """
    Tự động đánh dấu 'Completed' và giải phóng tài xế/phụ xe
    cho những chuyến đã qua thời gian đến dự kiến.
    """
    now = datetime.now()  # Dùng local time - khớp với departure_time trong DB
    
    # Tìm các chuyến Scheduled/Running mà đã qua giờ đến (có arrival_time)
    trips_to_complete = Trip.query.filter(
        Trip.status.in_(['Scheduled', 'Running']),
        Trip.arrival_time != None,
        Trip.arrival_time <= now
    ).all()

    # Fallback: không có arrival_time thì tính từ departure + duration
    trips_no_arrival = Trip.query.filter(
        Trip.status.in_(['Scheduled', 'Running']),
        Trip.arrival_time == None
    ).all()

    for trip in trips_no_arrival:
        duration_h = trip.route.duration_hours or 0
        if duration_h > 0:  # Chỉ auto-complete nếu biết duration
            estimated_arrival = trip.departure_time + timedelta(hours=duration_h)
            if estimated_arrival <= now:
                trips_to_complete.append(trip)

    if trips_to_complete:
        for trip in trips_to_complete:
            trip.status = 'Completed'
            trip.driver_id = None
            trip.assistant_id = None
            if trip.driver_ref:
                trip.driver_name = trip.driver_ref.name
            if trip.assistant_ref:
                trip.assistant_name = trip.assistant_ref.name
        try:
            db.session.commit()
        except Exception:
            db.session.rollback()




def register_admin_routes(app):
    def admin_trips_data():
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        
        trips = Trip.query.join(Route).filter(Route.company_id == company_id)\
                .order_by(Trip.departure_time.desc()).all()
        
        return jsonify([{
            'id': t.id,
            'route_id': t.route_id,
            'route': f"{t.route.start_point} - {t.route.end_point}",
            'bus': t.bus.license_plate,
            'departure_time': t.departure_time.isoformat(),
            'status': t.status,
            'price': t.route.base_price * t.price_multiplier,
            'occupancy': f"{Booking.query.filter_by(trip_id=t.id, status='CONFIRMED').count()}/{t.bus.total_seats}"
        } for t in trips])

    def admin_stats_data():
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        
        now = datetime.now()
        
        # 1. Basic Stats
        revenue_tickets = db.session.query(db.func.sum(Booking.ticket_price)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id, Booking.status == 'CONFIRMED').scalar() or 0
        
        revenue_cargo = db.session.query(db.func.sum(Cargo.cost)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id).scalar() or 0
            
        active_trips = Trip.query.join(Route).filter(Route.company_id == company_id, Trip.status == 'Running').count()
        cargo_count = Cargo.query.join(Trip).join(Route).filter(Route.company_id == company_id).count()
        
        # 2. Revenue Trend (Last 7 days)
        labels = []
        revenue_data = []
        for i in range(6, -1, -1):
            day = now - timedelta(days=i)
            labels.append(day.strftime('%d/%m'))
            
            daily_rev = db.session.query(db.func.sum(Booking.ticket_price)).join(Trip).join(Route)\
                .filter(Route.company_id == company_id, 
                        Booking.status == 'CONFIRMED',
                        db.func.date(Trip.departure_time) == day.date()).scalar() or 0
            revenue_data.append(daily_rev)

        # 3. Booking Status Distribution
        booking_stats = db.session.query(Booking.status, db.func.count(Booking.id)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id).group_by(Booking.status).all()
        booking_dist = {s: c for s, c in booking_stats}

        # 4. Top Routes
        top_routes_query = db.session.query(
            Route.start_point, Route.end_point, db.func.count(Booking.id).label('total_bookings')
        ).select_from(Route).join(Trip).join(Booking).filter(Route.company_id == company_id, Booking.status == 'CONFIRMED')\
        .group_by(Route.id).order_by(db.text('total_bookings DESC')).limit(5).all()
        
        top_routes = [{
            'route': f"{r[0]} - {r[1]}",
            'bookings': r[2]
        } for r in top_routes_query]

        # 5. Recent Activity (Simplified from bookings/trips)
        recent_bookings = Booking.query.join(Trip).join(Route).filter(Route.company_id == company_id)\
            .order_by(Booking.booking_time.desc()).limit(5).all()
        
        activities = []
        for b in recent_bookings:
            activities.append({
                'type': 'booking',
                'title': f"Vé mới: {b.passenger_name}",
                'subtitle': f"{b.trip.route.start_point} → {b.trip.route.end_point}",
                'time': b.booking_time.isoformat() if b.booking_time else now.isoformat()
            })
            
        recent_trips = Trip.query.join(Route).filter(Route.company_id == company_id, Trip.status != 'Scheduled')\
            .order_by(Trip.departure_time.desc()).limit(5).all()
            
        for t in recent_trips:
            activities.append({
                'type': 'trip',
                'title': f"Chuyến xe {t.status}",
                'subtitle': f"{t.route.start_point} → {t.route.end_point}",
                'time': t.departure_time.isoformat()
            })
            
        # Sort combined activities by time
        activities.sort(key=lambda x: x['time'], reverse=True)
        
        return jsonify({
            'total_revenue': revenue_tickets + revenue_cargo,
            'active_trips': active_trips,
            'cargo_items': cargo_count,
            'occupancy': '82%', 
            'trends': {
                'labels': labels,
                'data': revenue_data
            },
            'booking_dist': booking_dist,
            'top_routes': top_routes,
            'activities': activities[:10]
        })

    def admin_routes_data():
        try:
            company_id = session.get('company_id')
            if not company_id: return jsonify({'error': 'Unauthorized'}), 401
            routes = Route.query.filter_by(company_id=company_id).all()
            return jsonify([{
                'id': r.id,
                'start_point': r.start_point,
                'end_point': r.end_point,
                'base_price': r.base_price,
                'distance': r.distance_km,
                'duration': r.duration_hours
            } for r in routes])
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    def admin_cargo_data():
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        
        cargos = Cargo.query.filter_by(company_id=company_id).all()
        return jsonify([{
            'id': c.id,
            'trip_id': c.trip_id,
            'sender_name': c.sender_name,
            'sender_phone': c.sender_phone,
            'receiver_name': c.receiver_name,
            'receiver_phone': c.receiver_phone,
            'description': c.description,
            'weight': c.weight_kg,
            'cost': c.cost,
            'status': c.status,
            'tracking_number': c.tracking_number,
            'type': c.cargo_type,
            'sender_office': c.sender_office.name if c.sender_office else 'N/A',
            'receiver_office': c.receiver_office.name if c.receiver_office else 'N/A',
            'sender_office_id': c.sender_office_id,
            'receiver_office_id': c.receiver_office_id,
            'payment_status': c.payment_status,
            'cod_amount': c.cod_amount,
            'collected_at': c.collected_at.isoformat() if c.collected_at else None
        } for c in cargos])

    def admin_trip_passengers(trip_id):
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        
        trip = Trip.query.get_or_404(trip_id)
        if trip.route.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
        
        bookings = Booking.query.filter_by(trip_id=trip_id).filter(
            Booking.status.in_(['CONFIRMED', 'HOLD'])
        ).all()
        return jsonify([{
            'id': b.id,
            'ticket_code': b.ticket_code,
            'name': b.passenger_name,
            'phone': b.passenger_phone,
            'seat': b.seat_number,
            'boarding_status': b.boarding_status,
            'pickup': b.pickup_point,
            'dropoff': b.dropoff_point,
            'price': b.ticket_price or 0,
            'status': b.status,
            'payment_status': b.payment_status or 'Pending'
        } for b in bookings])


    def admin_buses_data():
        try:
            company_id = session.get('company_id')
            if not company_id: return jsonify({'error': 'Unauthorized'}), 401
            buses = Bus.query.filter_by(company_id=company_id).order_by(Bus.id.desc()).all()
            return jsonify([{
                'id': b.id,
                'license_plate': b.license_plate,
                'type': b.bus_type,
                'color': b.color or 'Xanh HUTECH',
                'total_seats': b.total_seats
            } for b in buses])
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    def admin_manage_bus(bus_id=None):
        try:
            company_id = session.get('company_id')
            if not company_id: return jsonify({'error': 'Unauthorized'}), 401
            
            data = request.json or {}
            action = request.method
            
            if action == 'POST':
                license_plate = data.get('license_plate')
                bus_type = data.get('bus_type')
                color = data.get('color', 'Xanh HUTECH')
                try:
                    total_seats = int(data.get('total_seats', 34))
                except:
                    total_seats = 34
                
                if not license_plate or not bus_type:
                    return jsonify({'error': 'Thiếu thông tin bắt buộc!'}), 400
                
                existing = Bus.query.filter_by(company_id=company_id, license_plate=license_plate).first()
                if existing:
                    return jsonify({'error': 'Biển số xe này đã tồn tại trong hệ thống!'}), 400
                
                seat_map = {
                    "type": bus_type,
                    "floors": 1,
                    "cols": 3,
                    "rows": 0,
                    "seats": []
                }
                
                if bus_type == 'standard_sleeper':
                    seat_map["floors"] = 2
                    seat_map["cols"] = 5
                    for floor_code in ['A', 'B']:
                        f_idx = 0 if floor_code == 'A' else 1
                        count = 0
                        limit = total_seats // 2
                        for r in range(7):
                            cols = [0, 2, 4] if r < 6 else [0, 1, 2, 3, 4]
                            for c in cols:
                                if count < limit:
                                    count += 1
                                    seat_id = f"{floor_code}{count:02d}"
                                    seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "standard"})
                elif bus_type == 'vip_34':
                    seat_map["floors"] = 2
                    seat_map["cols"] = 5
                    for floor_code in ['A', 'B']:
                        f_idx = 0 if floor_code == 'A' else 1
                        count = 0
                        limit = 17
                        for r in range(6):
                            for c in [0, 2, 4]:
                                if count < limit:
                                    count += 1
                                    seat_id = f"{floor_code}{count:02d}"
                                    seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "vip"})
                elif bus_type == 'luxury_cabin':
                    seat_map["floors"] = 2
                    seat_map["cols"] = 3
                    for floor_code in ['A', 'B']:
                        f_idx = 0 if floor_code == 'A' else 1
                        count = 0
                        limit = 11
                        for r in range(6):
                            for c in [0, 2]:
                                if count < limit:
                                    count += 1
                                    seat_id = f"{floor_code}{count:02d}"
                                    seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "cabin", "is_double": (r == 5)})
                else:
                    seat_map["cols"] = 4 if total_seats > 16 else 3
                    for r in range(10):
                        for c in range(seat_map["cols"]):
                            if c == 1: continue
                            if len(seat_map['seats']) < total_seats:
                                count = len(seat_map['seats']) + 1
                                seat_id = f"{count:02d}"
                                seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": 0, "type": "chair"})
                
                new_bus = Bus(
                    company_id=company_id,
                    license_plate=license_plate,
                    bus_type=bus_type,
                    color=color,
                    total_seats=total_seats,
                    seat_map=json.dumps(seat_map)
                )
                db.session.add(new_bus)
                db.session.commit()
                return jsonify({'message': 'Thêm xe mới thành công'})
                
            elif action == 'PUT':
                bus = Bus.query.get_or_404(bus_id)
                if bus.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
                
                license_plate = data.get('license_plate')
                if license_plate and license_plate != bus.license_plate:
                    existing = Bus.query.filter_by(company_id=company_id, license_plate=license_plate).first()
                    if existing:
                        return jsonify({'error': 'Biển số xe này đã tồn tại trong hệ thống!'}), 400
                    bus.license_plate = license_plate
                
                bus.bus_type = data.get('bus_type', bus.bus_type)
                bus.color = data.get('color', bus.color)
                
                total_seats = data.get('total_seats')
                if total_seats and int(total_seats) != bus.total_seats:
                    total_seats = int(total_seats)
                    bus.total_seats = total_seats
                    
                    bus_type = bus.bus_type
                    seat_map = {
                        "type": bus_type,
                        "floors": 1,
                        "cols": 3,
                        "rows": 0,
                        "seats": []
                    }
                    if bus_type == 'standard_sleeper':
                        seat_map["floors"] = 2
                        seat_map["cols"] = 5
                        for floor_code in ['A', 'B']:
                            f_idx = 0 if floor_code == 'A' else 1
                            count = 0
                            limit = total_seats // 2
                            for r in range(7):
                                cols = [0, 2, 4] if r < 6 else [0, 1, 2, 3, 4]
                                for c in cols:
                                    if count < limit:
                                        count += 1
                                        seat_id = f"{floor_code}{count:02d}"
                                        seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "standard"})
                    elif bus_type == 'vip_34':
                        seat_map["floors"] = 2
                        seat_map["cols"] = 5
                        for floor_code in ['A', 'B']:
                            f_idx = 0 if floor_code == 'A' else 1
                            count = 0
                            limit = 17
                            for r in range(6):
                                for c in [0, 2, 4]:
                                    if count < limit:
                                        count += 1
                                        seat_id = f"{floor_code}{count:02d}"
                                        seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "vip"})
                    elif bus_type == 'luxury_cabin':
                        seat_map["floors"] = 2
                        seat_map["cols"] = 3
                        for floor_code in ['A', 'B']:
                            f_idx = 0 if floor_code == 'A' else 1
                            count = 0
                            limit = 11
                            for r in range(6):
                                for c in [0, 2]:
                                    if count < limit:
                                        count += 1
                                        seat_id = f"{floor_code}{count:02d}"
                                        seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "cabin", "is_double": (r == 5)})
                    else:
                        seat_map["cols"] = 4 if total_seats > 16 else 3
                        for r in range(10):
                            for c in range(seat_map["cols"]):
                                if c == 1: continue
                                if len(seat_map['seats']) < total_seats:
                                    count = len(seat_map['seats']) + 1
                                    seat_id = f"{count:02d}"
                                    seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": 0, "type": "chair"})
                    bus.seat_map = json.dumps(seat_map)
                
                db.session.commit()
                return jsonify({'message': 'Cập nhật thông tin xe thành công'})
                
            elif action == 'DELETE':
                bus = Bus.query.get_or_404(bus_id)
                if bus.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
                
                trips_count = Trip.query.filter_by(bus_id=bus_id).filter(Trip.status.in_(['Scheduled', 'Running'])).count()
                if trips_count > 0:
                    return jsonify({'error': f'Không thể xóa: Có {trips_count} chuyến xe đang/sắp vận hành bằng xe này.'}), 400
                
                db.session.delete(bus)
                db.session.commit()
                return jsonify({'message': 'Đã xóa xe khỏi đội xe'})
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    def admin_staff_list(role):
        try:
            company_id = session.get('company_id')
            if not company_id: return jsonify({'error': 'Unauthorized'}), 401
            
            if role == 'DRIVER':
                # Ưu tiên lấy từ bảng Driver (Hồ sơ tài xế cũ)
                drivers = Driver.query.filter_by(company_id=company_id).all()
                if not drivers:
                    # Nếu không có Driver, thử tìm Staff có role DRIVER
                    staff = Staff.query.filter(Staff.company_id == company_id, Staff.role.ilike('%DRIVER%')).all()
                    return jsonify([{
                        'id': s.id,
                        'name': s.name,
                        'phone': s.phone,
                        'role': 'DRIVER'
                    } for s in staff])
            # Các vai trò khác lấy từ Staff
            staff = Staff.query.filter_by(company_id=company_id)
            if role != 'ALL':
                staff = staff.filter(Staff.role == role)
            staff = staff.all()
            
            return jsonify([{
                'id': s.id,
                'name': s.name,
                'email': s.email,
                'phone': s.phone,
                'role': s.role,
                'status': s.status,
                'joined_at': s.created_at.strftime('%Y-%m-%d') if s.created_at else 'N/A'
            } for s in staff])
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    def admin_manage_staff():
        try:
            company_id = session.get('company_id')
            if not company_id: return jsonify({'error': 'Unauthorized'}), 401
            
            data = request.json
            action = request.method
            
            if action == 'POST':
                # Kiểm tra email trùng lặp
                existing_staff = Staff.query.filter_by(email=data['email']).first()
                if existing_staff:
                    return jsonify({'error': 'Email này đã được sử dụng cho một nhân viên khác!'}), 400

                role = data.get('role', 'STATION_STAFF')
                new_staff = Staff(
                    company_id=company_id,
                    name=data['name'],
                    email=data['email'],
                    password=generate_password_hash(data.get('password', '123456')),
                    phone=data.get('phone', ''),
                    role=role,
                    status='Active'
                )
                
                if role == 'DRIVER':
                    d = Driver(company_id=company_id, name=data['name'], phone=data.get('phone', ''), license_number=data.get('license_number', ''))
                    db.session.add(d)
                    db.session.flush()
                    new_staff.driver_id = d.id
                elif role == 'ASSISTANT':
                    a = Assistant(company_id=company_id, name=data['name'], phone=data.get('phone', ''))
                    db.session.add(a)
                    db.session.flush()
                    new_staff.assistant_id = a.id
                    
                db.session.add(new_staff)
                db.session.commit()
                return jsonify({'message': 'Staff created successfully'})

            elif action == 'PUT':
                staff_id = data.get('id')
                staff = Staff.query.get_or_404(staff_id)
                if staff.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
                
                staff.name = data.get('name', staff.name)
                staff.email = data.get('email', staff.email)
                staff.phone = data.get('phone', staff.phone)
                staff.role = data.get('role', staff.role)
                staff.status = data.get('status', staff.status)
                
                if data.get('password'):
                    staff.password = generate_password_hash(data['password'])
                
                db.session.commit()
                return jsonify({'message': 'Staff updated successfully'})

            elif action == 'DELETE':
                staff_id = request.args.get('id') or data.get('id')
                staff = Staff.query.get_or_404(staff_id)
                if staff.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
                db.session.delete(staff)
                db.session.commit()
                return jsonify({'message': 'Staff deleted successfully'})

        except Exception as e:
            return jsonify({'error': str(e)}), 500

    def admin_create_route():
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        data = request.json
        new_route = Route(
            company_id=company_id,
            start_point=data['start_point'],
            end_point=data['end_point'],
            distance_km=float(data['distance_km'] or 0),
            duration_hours=float(data['duration_hours'] or 0),
            base_price=int(data['base_price'])
        )
        db.session.add(new_route)
        db.session.commit()
        return jsonify({'message': 'Route created successfully'})

    def admin_create_trip():
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        data = request.json
        new_trip = Trip(
            route_id=data['route_id'],
            bus_id=data['bus_id'],
            driver_id=data['driver_id'],
            departure_time=datetime.fromisoformat(data['departure_time']),
            status='Scheduled'
        )
        db.session.add(new_trip)
        db.session.commit()
        return jsonify({'message': 'Trip created successfully'})

    def admin_create_cargo():
        try:
            company_id = session.get('company_id')
            if not company_id: return jsonify({'error': 'Unauthorized'}), 401
            data = request.json
            
            import random
            import string
            # Generate unique tracking number with retry
            max_retries = 10
            tracking = None
            for _ in range(max_retries):
                temp_tracking = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))
                if not Cargo.query.filter_by(tracking_number=temp_tracking).first():
                    tracking = temp_tracking
                    break
            
            if not tracking:
                return jsonify({'error': 'Could not generate unique tracking number'}), 500

            # Safe numeric conversion
            def safe_float(val, default=0.0):
                try:
                    if val is None or val == "": return default
                    return float(val)
                except: return default

            def safe_int(val, default=0):
                try:
                    if val is None or val == "": return default
                    return int(float(val)) # Handle "10.0" as string
                except: return default

            new_cargo = Cargo(
                company_id=company_id,
                trip_id=data.get('trip_id') if data.get('trip_id') else None,
                sender_name=data.get('sender_name', ''),
                sender_phone=data.get('sender_phone', ''),
                receiver_name=data.get('receiver_name', ''),
                receiver_phone=data.get('receiver_phone', ''),
                sender_office_id=data.get('sender_office_id') if data.get('sender_office_id') else None,
                receiver_office_id=data.get('receiver_office_id') if data.get('receiver_office_id') else None,
                description=data.get('description', ''),
                weight_kg=safe_float(data.get('weight_kg')),
                cargo_type=data.get('cargo_type', 'NORMAL'),
                cost=safe_int(data.get('cost')),
                payment_status=data.get('payment_status', 'UNPAID'),
                cod_amount=safe_float(data.get('cod_amount')),
                status='Received',
                tracking_number=tracking
            )
            db.session.add(new_cargo)
            db.session.commit()
            return jsonify({'message': 'Cargo received successfully', 'tracking': tracking})
        except Exception as e:
            db.session.rollback()
            return jsonify({'error': str(e)}), 500

    def admin_delete_cargo(cargo_id):
        company_id = session.get('company_id')
        cargo = Cargo.query.filter_by(id=cargo_id, company_id=company_id).first_or_404()
        db.session.delete(cargo)
        db.session.commit()
        return jsonify({'message': 'Cargo deleted successfully'})

    def admin_update_cargo(cargo_id):
        try:
            company_id = session.get('company_id')
            cargo = Cargo.query.filter_by(id=cargo_id, company_id=company_id).first_or_404()
            data = request.json
            
            # Safe numeric conversion
            def safe_float(val, default_val):
                try:
                    if val is None or val == "": return default_val
                    return float(val)
                except: return default_val

            def safe_int(val, default_val):
                try:
                    if val is None or val == "": return default_val
                    return int(float(val))
                except: return default_val
            
            # Correctly handle trip_id (can be None for Warehouse)
            if 'trip_id' in data:
                cargo.trip_id = data['trip_id'] if data['trip_id'] != "" else None
                
            cargo.sender_name = data.get('sender_name', cargo.sender_name)
            cargo.sender_phone = data.get('sender_phone', cargo.sender_phone)
            cargo.receiver_name = data.get('receiver_name', cargo.receiver_name)
            cargo.receiver_phone = data.get('receiver_phone', cargo.receiver_phone)
            
            if 'sender_office_id' in data:
                cargo.sender_office_id = data['sender_office_id'] if data['sender_office_id'] else None
            if 'receiver_office_id' in data:
                cargo.receiver_office_id = data['receiver_office_id'] if data['receiver_office_id'] else None
                
            cargo.description = data.get('description', cargo.description)
            cargo.weight_kg = safe_float(data.get('weight_kg'), cargo.weight_kg)
            cargo.cargo_type = data.get('cargo_type', cargo.cargo_type)
            cargo.cost = safe_int(data.get('cost'), cargo.cost)
            cargo.payment_status = data.get('payment_status', cargo.payment_status)
            cargo.cod_amount = safe_float(data.get('cod_amount'), cargo.cod_amount)
            
            db.session.commit()
            return jsonify({'message': 'Cargo updated successfully'})
        except Exception as e:
            db.session.rollback()
            return jsonify({'error': str(e)}), 500

    def admin_batch_update_cargo():
        company_id = session.get('company_id')
        data = request.json
        ids = data.get('ids', [])
        trip_id = data.get('trip_id')
        
        if not ids: return jsonify({'error': 'No items selected'}), 400
        
        cargos = Cargo.query.filter(Cargo.id.in_(ids), Cargo.company_id == company_id).all()
        for c in cargos:
            c.trip_id = trip_id
            
        db.session.commit()
        return jsonify({'message': f'Updated {len(cargos)} items'})

    def admin_offices_data():
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        offices = Office.query.filter_by(company_id=company_id).all()
        return jsonify([{
            'id': o.id,
            'name': o.name,
            'address': o.address,
            'phone': o.phone,
            'is_active': o.is_active
        } for o in offices])

    def admin_create_office():
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        data = request.json
        new_office = Office(
            company_id=company_id,
            name=data['name'],
            address=data.get('address', ''),
            phone=data.get('phone', '')
        )
        db.session.add(new_office)
        db.session.commit()
        return jsonify({'message': 'Office created successfully'})

    def admin_update_office(office_id):
        company_id = session.get('company_id')
        office = Office.query.filter_by(id=office_id, company_id=company_id).first_or_404()
        data = request.json
        office.name = data.get('name', office.name)
        office.address = data.get('address', office.address)
        office.phone = data.get('phone', office.phone)
        db.session.commit()
        return jsonify({'message': 'Office updated successfully'})

    def admin_delete_office(office_id):
        company_id = session.get('company_id')
        office = Office.query.filter_by(id=office_id, company_id=company_id).first_or_404()
        db.session.delete(office)
        db.session.commit()
        return jsonify({'message': 'Office deleted successfully'})

    def run_auto_complete():
        """Chạy auto-complete trước mỗi request vào admin (không lồng app_context)."""
        if request.path.startswith('/admin'):
            auto_complete_trips()

    def admin_reports():
        company_id = session['company_id']
        
        # 1. Basic Totals
        revenue_tickets = db.session.query(db.func.sum(Booking.ticket_price)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id, Booking.status == 'CONFIRMED').scalar() or 0
        
        revenue_cargo = db.session.query(db.func.sum(Cargo.cost)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id).scalar() or 0
        
        total_revenue = revenue_tickets + revenue_cargo
    
        # 2. Occupancy Rate
        trips = Trip.query.join(Route).filter(Route.company_id == company_id).all()
        total_capacity = sum([t.bus.total_seats for t in trips])
        total_booked = Booking.query.join(Trip).join(Route)\
            .filter(Route.company_id == company_id, Booking.status == 'CONFIRMED').count()
        occupancy_rate = (total_booked / total_capacity * 100) if total_capacity > 0 else 0
    
        # 3. Last 7 Days Revenue Trend
        last_7_days_labels = []
        last_7_days_data = []
        for i in range(6, -1, -1):
            date = (datetime.now() - timedelta(days=i)).date()
            last_7_days_labels.append(date.strftime('%d/%m'))
            
            daily_rev = db.session.query(db.func.sum(Booking.ticket_price)).join(Trip).join(Route)\
                .filter(Route.company_id == company_id, 
                        Booking.status == 'CONFIRMED',
                        db.func.date(Trip.departure_time) == date).scalar() or 0
            last_7_days_data.append(daily_rev)

        # 4. Route Statistics
        routes = Route.query.filter_by(company_id=company_id).all()
        route_stats = []
        for r in routes:
            trip_count = Trip.query.filter_by(route_id=r.id).count()
            pax_count = Booking.query.join(Trip).filter(Trip.route_id == r.id, Booking.status == 'CONFIRMED').count()
            t_rev = db.session.query(db.func.sum(Booking.ticket_price)).join(Trip)\
                .filter(Trip.route_id == r.id, Booking.status == 'CONFIRMED').scalar() or 0
            c_rev = db.session.query(db.func.sum(Cargo.cost)).join(Trip)\
                .filter(Trip.route_id == r.id).scalar() or 0
            
            route_stats.append({
                'name': f"{r.start_point} - {r.end_point}",
                'trip_count': trip_count,
                'passenger_count': pax_count,
                'ticket_revenue': t_rev,
                'cargo_revenue': c_rev,
                'total': t_rev + c_rev
            })

        return render_template('admin/reports.html', 
                               revenue_tickets=revenue_tickets, 
                               revenue_cargo=revenue_cargo,
                               total_revenue=total_revenue,
                               occupancy_rate=occupancy_rate,
                               last_7_days_labels=last_7_days_labels,
                               last_7_days_data=last_7_days_data,
                               route_stats=route_stats,
                               active_page='reports')

    def complete_trip(trip_id):
        company_id = session['company_id']
        trip = Trip.query.get_or_404(trip_id)

        # Bảo vệ: chỉ cho phép nhà xe của mình
        if trip.route.company_id != company_id:
            flash('Không có quyền thực hiện thao tác này!')
            return redirect(url_for('admin_trips_page'))

        if trip.status in ['Completed', 'Cancelled']:
            flash(f'Chuyến #{trip_id} đã ở trạng thái {trip.status}, không thể thay đổi!')
            return redirect(url_for('admin_trips_page'))

        # Lưu tên trước khi xóa quan hệ
        driver_name = trip.driver_ref.name if trip.driver_ref else trip.driver_name or '(chưa gán)'
        assistant_name = trip.assistant_ref.name if trip.assistant_ref else trip.assistant_name or ''

        # Cập nhật trạng thái và NHẢTÀI XẾ / PHỤ XE
        trip.status = 'Completed'
        trip.arrival_time = datetime.utcnow()
        trip.driver_name = driver_name          # Giữ lại tên để lịch sử
        trip.assistant_name = assistant_name
        trip.driver_id = None                   # 🔓 Nhả tài xế
        trip.assistant_id = None                # 🔓 Nhả phụ xe

        db.session.commit()

        msg = f'✅ Chuyến #{trip_id} ({trip.route.start_point} → {trip.route.end_point}) đã hoàn thành!'
        if driver_name != '(chưa gán)':
            msg += f' Tài xế <strong>{driver_name}</strong> đã được giải phóng.'
        flash(msg)
        return redirect(url_for('admin_trips_page'))

    def update_trip_status(trip_id):
        company_id = session['company_id']
        trip = Trip.query.get_or_404(trip_id)

        if trip.route.company_id != company_id:
            flash('Không có quyền!')
            return redirect(url_for('admin_trips_page'))

        new_status = request.form.get('status')
        allowed = ['Scheduled', 'Running', 'Cancelled']
        if new_status not in allowed:
            flash('Trạng thái không hợp lệ!')
            return redirect(url_for('admin_trips_page'))

        # Chỉ ADMIN mới được hủy chuyến.
        if new_status == 'Cancelled' and session.get('role') != 'ADMIN':
            flash('Chỉ quản trị viên mới được hủy chuyến!')
            return redirect(url_for('admin_trips_page'))

        if new_status == 'Cancelled':
            # Nhả tài xế khi hủy
            trip.driver_name = trip.driver_ref.name if trip.driver_ref else trip.driver_name
            trip.assistant_name = trip.assistant_ref.name if trip.assistant_ref else trip.assistant_name
            trip.driver_id = None
            trip.assistant_id = None

        trip.status = new_status
        db.session.commit()
        flash(f'Đã cập nhật chuyến #{trip_id} → {new_status}')
        return redirect(url_for('admin_trips_page'))

    def admin():
        # Dashboard Overview
        company_id = session['company_id']
        routes = Route.query.filter_by(company_id=company_id).all()
        buses = Bus.query.filter_by(company_id=company_id).all()
        trips = Trip.query.join(Route).filter(Route.company_id == company_id)\
                .order_by(Trip.departure_time.desc()).all()
            
        # Simple Revenue Calculation
        total_revenue = 0
        all_bookings = Booking.query.join(Trip).join(Route).filter(Route.company_id == company_id).all()
        for b in all_bookings:
            if b.status == 'CONFIRMED':
                total_revenue += b.ticket_price
            
        return render_template('admin/dashboard.html', 
                                 routes=routes, 
                                 buses=buses, 
                                 trips=trips, 
                                 total_revenue=total_revenue,
                                 active_page='dashboard')

    def admin_routes_page():
        company_id = session['company_id']
        routes = Route.query.filter_by(company_id=company_id).all()
        return render_template('admin/routes.html', routes=routes, active_page='routes', vietnam_provinces=VIETNAM_PROVINCES)

    def admin_buses_page():
        company_id = session['company_id']
    
        # Filter & Sort
        search = request.args.get('search', '').strip()
        sort_by = request.args.get('sort_by', 'id_desc')
    
        query = Bus.query.filter_by(company_id=company_id)
    
        if search:
            search_term = f"%{search}%"
            query = query.filter(
                (Bus.license_plate.ilike(search_term)) | 
                (Bus.bus_type.ilike(search_term))
            )
    
        if sort_by == 'license_asc':
            query = query.order_by(Bus.license_plate.asc())
        elif sort_by == 'seats_desc':
            query = query.order_by(Bus.total_seats.desc())
        else:
            query = query.order_by(Bus.id.desc())
        
        buses = query.all()
        return render_template('admin/buses.html', buses=buses, active_page='buses', search=search, sort_by=sort_by)

    def admin_trips_page():
        company_id = session['company_id']
    
        # Filters
        start_point = request.args.get('start_point')
        end_point = request.args.get('end_point')
        date_str = request.args.get('date')
    
        query = Trip.query.join(Route).filter(Route.company_id == company_id)
    
        if start_point:
            query = query.filter(Route.start_point == start_point)
        if end_point:
            query = query.filter(Route.end_point == end_point)
        if date_str:
            try:
                search_date = datetime.strptime(date_str, '%Y-%m-%d').date()
                query = query.filter(db.func.date(Trip.departure_time) == search_date)
            except ValueError:
                pass
            
        trips = query.order_by(Trip.departure_time.desc()).all()
    
        # Data for the "Add Trip" form - Filter only FREE resources
        # A resource is busy if it's in a trip that is 'Scheduled' or 'Running'
        busy_trips = Trip.query.filter(Trip.status.in_(['Scheduled', 'Running'])).all()
        busy_buses_ids = [t.bus_id for t in busy_trips]
        busy_drivers_ids = [t.driver_id for t in busy_trips if t.driver_id]
        busy_assistants_ids = [t.assistant_id for t in busy_trips if t.assistant_id]

        routes = Route.query.filter_by(company_id=company_id).all()
    
        # Filter resources that are NOT busy
        buses = Bus.query.filter(Bus.id.notin_(busy_buses_ids), Bus.company_id == company_id).all()
        drivers = Driver.query.filter(Driver.id.notin_(busy_drivers_ids), Driver.company_id == company_id).all()
        assistants = Assistant.query.filter(Assistant.id.notin_(busy_assistants_ids), Assistant.company_id == company_id).all()
    
        # Distinct points for filter dropdowns
        all_company_routes = Route.query.filter_by(company_id=company_id).all()
        start_points = sorted(list(set([r.start_point for r in all_company_routes])))
        end_points = sorted(list(set([r.end_point for r in all_company_routes])))
    
        return render_template('admin/trips.html', 
                               trips=trips, 
                               routes=routes, 
                               buses=buses, 
                               drivers=drivers, 
                               assistants=assistants, 
                               start_points=start_points, 
                               end_points=end_points,
                               active_page='trips')

    def admin_staff_page():
        company_id = session['company_id']
        drivers = Driver.query.filter_by(company_id=company_id).all()
        assistants = Assistant.query.filter_by(company_id=company_id).all()
        return render_template('admin/staff.html', drivers=drivers, assistants=assistants, active_page='staff')

    def add_driver():
        company_id = session['company_id']
        name = request.form.get('name')
        phone = request.form.get('phone')
        license_number = request.form.get('license_number')
    
        new_driver = Driver(company_id=company_id, name=name, phone=phone, license_number=license_number)
        db.session.add(new_driver)
        db.session.commit()
        flash('Đã thêm tài xế thành công!')
        return redirect(url_for('admin_staff_page'))

    def add_assistant():
        company_id = session['company_id']
        name = request.form.get('name')
        phone = request.form.get('phone')
    
        new_assistant = Assistant(company_id=company_id, name=name, phone=phone)
        db.session.add(new_assistant)
        db.session.commit()
        flash('Đã thêm phụ xe thành công!')
        return redirect(url_for('admin_staff_page'))

    def admin_trip_breakdown(trip_id):
        company_id = session['company_id']
        trip = Trip.query.get_or_404(trip_id)
    
        if trip.route.company_id != company_id:
            flash('Unauthorized')
            return redirect(url_for('admin_trips_page'))

        # Mark as broken if it wasn't already (logical state)
        if trip.status != 'Broken':
            trip.status = 'Broken'
            db.session.commit()

        # Find replacement suggestions:
        # Strictly EXCLUDE buses that are:
        # 1. Currently in a trip that is 'Scheduled', 'Running', or 'Broken'
        # 2. Part of any trip within a +- 6 hour window (safety buffer)
        now = datetime.utcnow()
        busy_buses_ids = [t.bus_id for t in Trip.query.filter(
            (Trip.status.in_(['Scheduled', 'Running', 'Broken'])) |
            ((Trip.departure_time >= now - timedelta(hours=6)) & (Trip.departure_time <= now + timedelta(hours=6)))
        ).all()]
    
        # Also explicitly exclude the current broken bus just in case
        busy_buses_ids.append(trip.bus_id)
    
        available_buses = Bus.query.filter(
            Bus.company_id == company_id,
            Bus.id.notin_(busy_buses_ids),
            Bus.total_seats == trip.bus.total_seats, # Match exact capacity
            Bus.bus_type == trip.bus.bus_type # Match exact type (e.g. sleeper, limousine)
        ).all()

        # Find nearby drivers
        busy_drivers_ids = [t.driver_id for t in Trip.query.filter(
            Trip.departure_time >= now - timedelta(hours=4),
            Trip.departure_time <= now + timedelta(hours=4),
            Trip.status != 'Cancelled'
        ).all() if t.driver_id]
    
        available_drivers = Driver.query.filter(
            Driver.company_id == company_id,
            Driver.id.notin_(busy_drivers_ids)
        ).all()

        return render_template('admin/trip_breakdown.html', 
                               trip=trip, 
                               available_buses=available_buses,
                               available_drivers=available_drivers,
                               active_page='trips')

    def execute_transfer(trip_id):
        company_id = session['company_id']
        trip = Trip.query.get_or_404(trip_id)
    
        new_bus_id = request.form.get('new_bus_id')
        new_driver_id = request.form.get('new_driver_id')
    
        if not new_bus_id:
            flash('Vui lòng chọn xe thay thế!')
            return redirect(url_for('admin_trip_breakdown', trip_id=trip_id))

        # Update trip with new vehicle/driver
        old_bus_plate = trip.bus.license_plate
        trip.bus_id = new_bus_id
        if new_driver_id:
            trip.driver_id = new_driver_id
    
        trip.status = 'Running' # Back to running
    
        # Correctly fetch the NEW bus license plate
        new_bus = Bus.query.get(new_bus_id)
        new_bus_plate = new_bus.license_plate
    
        # Send Email Notifications to Passengers
        confirmed_bookings = [b for b in trip.bookings if b.status == 'CONFIRMED']
        for b in confirmed_bookings:
            # If the booking is linked to a registered user, they have an email
            recipient_email = None
            if b.user and b.user.email:
                recipient_email = b.user.email
            
            if recipient_email:
                try:
                    msg = Message(f"[THÔNG BÁO] Thay đổi phương tiện chuyến {trip.route.start_point} - {trip.route.end_point}",
                                  recipients=[recipient_email])
                    msg.html = f"""
                    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e1e1e1; border-radius: 8px; overflow: hidden;">
                        <div style="background-color: #DC2626; color: white; padding: 20px; text-align: center;">
                            <h2 style="margin: 0;">THÔNG BÁO SỰ CỐ & SANG XE</h2>
                        </div>
                        <div style="padding: 30px; line-height: 1.6; color: #333;">
                            <p>Xin chào <strong>{b.passenger_name}</strong>,</p>
                            <p>HUTECH BUS xin chân thành xin lỗi vì sự cố kỹ thuật xảy ra với xe <strong>{old_bus_plate}</strong> trên chuyến đi của bạn.</p>
                            <p>Để đảm bảo hành trình không bị gián đoạn, chúng tôi đã điều động xe thay thế:</p>
                            <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0;">
                                <p style="margin: 5px 0;"><strong>Xe mới:</strong> {new_bus_plate}</p>
                                <p style="margin: 5px 0;"><strong>Tuyến:</strong> {trip.route.start_point} - {trip.route.end_point}</p>
                                <p style="margin: 5px 0;"><strong>Vị trí ghế của bạn:</strong> {b.seat_number} (Không đổi)</p>
                            </div>
                            <p>Rất mong quý khách thông cảm cho sự bất tiện này. Chúc quý khách một chuyến đi an toàn.</p>
                            <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
                            <p style="font-size: 12px; color: #999; text-align: center;">Đây là email tự động từ hệ thống quản lý HUTECH BUS.</p>
                        </div>
                    </div>
                    """
                    mail.send(msg)
                except Exception as e:
                    print(f"Error sending transfer email to {recipient_email}: {e}")

        db.session.commit()
    
        flash(f'Đã sang xe thành công và gửi email thông báo cho {len(confirmed_bookings)} hành khách! Xe mới: {new_bus_plate} (thay cho {old_bus_plate}).')
        return redirect(url_for('admin_trips_page'))

    def add_route():
        company_id = session['company_id']
        start_point = request.form.get('start_point')
        end_point = request.form.get('end_point')
        base_price = float(request.form.get('base_price'))
        distance_km = float(request.form.get('distance_km', 0))
        duration_hours = float(request.form.get('duration_hours', 0))
    
        new_route = Route(company_id=company_id, start_point=start_point, end_point=end_point, 
                          base_price=base_price, distance_km=distance_km, duration_hours=duration_hours)
        db.session.add(new_route)
        db.session.commit()
        flash('Đã thêm tuyến đường thành công!')
        return redirect(url_for('admin_routes_page'))

    def delete_route(route_id):
        company_id = session['company_id']
        route = Route.query.filter_by(id=route_id, company_id=company_id).first_or_404()
    
        # Check if there are active trips on this route
        active_trips = Trip.query.filter_by(route_id=route_id, status='Scheduled').count()
        if active_trips > 0:
            flash(f'Không thể xóa! Tuyến này còn {active_trips} chuyến đang hoạt động. Hủy chuyến trước.')
            return redirect(url_for('admin_routes_page'))
    
        db.session.delete(route)
        db.session.commit()
        flash(f'Đã xóa tuyến {route.start_point} → {route.end_point}.')
        return redirect(url_for('admin_routes_page'))

    def add_bus():
        company_id = session['company_id']
        license_plate = request.form.get('license_plate')
        bus_type = request.form.get('bus_type')
        color = request.form.get('color', 'Học phí HUTECH')
        total_seats = int(request.form.get('total_seats'))
    
        # Sophisticated Seat Map Generation
        seat_map = {
            "type": bus_type,
            "floors": 1,
            "cols": 3,
            "rows": 0,
            "seats": []
        }
    
        if bus_type == 'standard_sleeper': # 40/44 seats
            seat_map["floors"] = 2
            seat_map["cols"] = 5 # S A S A S
            for floor_code in ['A', 'B']:
                f_idx = 0 if floor_code == 'A' else 1
                count = 0
                limit = total_seats // 2
                for r in range(7):
                    cols = [0, 2, 4] if r < 6 else [0, 1, 2, 3, 4]
                    for c in cols:
                        if count < limit:
                            count += 1
                            seat_id = f"{floor_code}{count:02d}"
                            seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "standard"})

        elif bus_type == 'vip_34':
            seat_map["floors"] = 2
            seat_map["cols"] = 5 # 3 dãy (Left, Middle, Right) + 2 lối đi = 5 cột grid
            for floor_code in ['A', 'B']:
                f_idx = 0 if floor_code == 'A' else 1
                count = 0
                limit = 17 # 34 / 2
                for r in range(6): # 6 hàng
                    for c in [0, 2, 4]: # 3 dãy ghế
                        if count < limit:
                            count += 1
                            seat_id = f"{floor_code}{count:02d}"
                            seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "vip"})

        elif bus_type == 'luxury_cabin': # 22 rooms
            seat_map["floors"] = 2
            seat_map["cols"] = 3 # 2 dãy (Left, Right) + 1 lối đi = 3 cột grid
            for floor_code in ['A', 'B']:
                f_idx = 0 if floor_code == 'A' else 1
                count = 0
                limit = 11 # 22 / 2
                for r in range(6): # 6 hàng
                    for c in [0, 2]: # 2 dãy ghế
                        if count < limit:
                            count += 1
                            seat_id = f"{floor_code}{count:02d}"
                            is_double = (r == 5) # Giả sử hàng cuối là cabin đôi nếu cần
                            seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": f_idx, "type": "cabin", "is_double": is_double})

        else: # chair_limo
            seat_map["cols"] = 4 if total_seats > 16 else 3
            # ... (keep existing chair logic)
            for r in range(10): # simplified safety
                for c in range(seat_map["cols"]):
                    if c == 1: continue 
                    if len(seat_map['seats']) < total_seats:
                        count = len(seat_map['seats']) + 1
                        seat_id = f"{count:02d}"
                        seat_map['seats'].append({"id": seat_id, "row": r, "col": c, "floor": 0, "type": "chair"})

        new_bus = Bus(company_id=company_id, license_plate=license_plate, bus_type=bus_type, 
                      color=color, total_seats=total_seats, seat_map=json.dumps(seat_map))
        db.session.add(new_bus)
        db.session.commit()
        flash('Đã thêm xe vào đội xe thành công!')
        return redirect(url_for('admin_buses_page'))

    def add_trip():
        route_id = request.form.get('route_id')
        bus_id = request.form.get('bus_id')
        driver_id = request.form.get('driver_id') # New fields
        assistant_id = request.form.get('assistant_id') # New fields
    
        departure_time_str = request.form.get('departure_time')
        departure_time = datetime.strptime(departure_time_str, '%Y-%m-%dT%H:%M')
    
        price_multiplier = float(request.form.get('price_multiplier', 1.0))
    
        # Store legacy names if needed, or rely on relationships
        # Ideally, we should fetch the objects
        driver = Driver.query.get(driver_id) if driver_id else None
        assistant = Assistant.query.get(assistant_id) if assistant_id else None
    
        new_trip = Trip(
            route_id=route_id, 
            bus_id=bus_id, 
            driver_id=driver_id,
            assistant_id=assistant_id,
            driver_name = driver.name if driver else None, # Legacy sync
            assistant_name = assistant.name if assistant else None, # Legacy sync
            departure_time=departure_time, 
            price_multiplier=price_multiplier
        )
        db.session.add(new_trip)
        db.session.commit()
        flash('Đã lên lịch chuyến đi thành công!')
        return redirect(url_for('admin_trips_page'))

    def edit_trip(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        company_id = session['company_id']
    
        # Check ownership
        if trip.route.company_id != company_id:
            flash('Không có quyền chỉnh sửa!')
            return redirect(url_for('admin_trips_page'))

        if request.method == 'POST':
            # Update basics
            trip.bus_id = request.form.get('bus_id')
            trip.driver_id = request.form.get('driver_id') or None
            trip.assistant_id = request.form.get('assistant_id') or None
        
            # Update names for legacy
            driver = Driver.query.get(trip.driver_id) if trip.driver_id else None
            assistant = Assistant.query.get(trip.assistant_id) if trip.assistant_id else None
            trip.driver_name = driver.name if driver else None
            trip.assistant_name = assistant.name if assistant else None

            # Update Time & Status
            dept_str = request.form.get('departure_time')
            if dept_str:
                 trip.departure_time = datetime.strptime(dept_str, '%Y-%m-%dT%H:%M')
        
            trip.status = request.form.get('status')
            trip.price_multiplier = float(request.form.get('price_multiplier', 1.0))
        
            db.session.commit()
            flash('Đã cập nhật thông tin chuyến đi!')
            return redirect(url_for('admin_trips_page'))

        # Prepare data for dropdowns
        buses = Bus.query.filter_by(company_id=company_id).all()
        drivers = Driver.query.filter_by(company_id=company_id).all()
        assistants = Assistant.query.filter_by(company_id=company_id).all()
    
        return render_template('admin/edit_trip.html', trip=trip, buses=buses, drivers=drivers, assistants=assistants)

    def trip_passengers(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        # Check ownership
        if trip.route.company_id != session['company_id']:
            flash('Truy cập bị từ chối!')
            return redirect(url_for('admin'))
        
        bookings = Booking.query.filter_by(trip_id=trip_id).all()
        return render_template('passengers.html', trip=trip, bookings=bookings)

    def trip_cargo(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        if trip.route.company_id != session['company_id']:
            flash('Truy cập bị từ chối!')
            return redirect(url_for('admin'))

        if request.method == 'POST':
            sender_name = request.form.get('sender_name')
            sender_phone = request.form.get('sender_phone')
            receiver_name = request.form.get('receiver_name')
            receiver_phone = request.form.get('receiver_phone')
            description = request.form.get('description')
            weight_kg = float(request.form.get('weight_kg'))
            cost = float(request.form.get('cost'))
        
            new_cargo = Cargo(trip_id=trip_id, sender_name=sender_name, sender_phone=sender_phone,
                              receiver_name=receiver_name, receiver_phone=receiver_phone,
                              description=description, weight_kg=weight_kg, cost=cost)
            db.session.add(new_cargo)
            db.session.commit()
            flash('Đã thêm đơn hàng ký gửi thành công!')
            return redirect(url_for('trip_cargo', trip_id=trip_id))
        
        cargos = Cargo.query.filter_by(trip_id=trip_id).all()
        return render_template('cargo.html', trip=trip, cargos=cargos)

    def download_manifest(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        if trip.route.company_id != session['company_id']:
            flash('Truy cập bị từ chối!')
            return redirect(url_for('admin'))
    
        doc = Document()
        header = doc.add_heading('DANH SÁCH HÀNH KHÁCH (PHƠI KHÁCH)', 0)
        header.alignment = WD_ALIGN_PARAGRAPH.CENTER
        
        p = doc.add_paragraph()
        p.add_run(f'Tuyến: {trip.route.start_point} - {trip.route.end_point}\n').bold = True
        p.add_run(f'Biển số xe: {trip.bus.license_plate}\n')
        p.add_run(f'Tài xế: {trip.driver_ref.name if trip.driver_ref else "N/A"}\n')
        p.add_run(f'Ngày khởi hành: {trip.departure_time.strftime("%d/%m/%Y %H:%M")}')
        
        table = doc.add_table(rows=1, cols=5)
        table.style = 'Table Grid'
        hdr_cells = table.rows[0].cells
        hdr_cells[0].text = 'Ghế'
        hdr_cells[1].text = 'Họ và tên'
        hdr_cells[2].text = 'Số điện thoại'
        hdr_cells[3].text = 'Điểm đón'
        hdr_cells[4].text = 'Ghi chú'
        
        bookings = Booking.query.filter_by(trip_id=trip_id).all()
        for b in bookings:
            row_cells = table.add_row().cells
            row_cells[0].text = b.seat_number
            row_cells[1].text = b.passenger_name
            row_cells[2].text = b.passenger_phone
            row_cells[3].text = b.pickup_point or ''
            row_cells[4].text = b.status
            
        doc.add_paragraph('\n')
        doc.add_paragraph('DANH SÁCH HÀNG HÓA KÝ GỬI').bold = True
        
        cargo_table = doc.add_table(rows=1, cols=4)
        cargo_table.style = 'Table Grid'
        chdr = cargo_table.rows[0].cells
        chdr[0].text = 'Người gửi/nhận'
        chdr[1].text = 'Mô tả hàng'
        chdr[2].text = 'Cước phí'
        chdr[3].text = 'Ký nhận'
        
        cargos = Cargo.query.filter_by(trip_id=trip_id).all()
        for c in cargos:
            row = cargo_table.add_row().cells
            row[0].text = f'G: {c.sender_name}\nN: {c.receiver_name}'
            row[1].text = c.description or ''
            row[2].text = "{:,.0f}".format(c.cost)
            row[3].text = ''

        doc.add_paragraph('\n\n')
        sig_table = doc.add_table(rows=2, cols=3)
        scells = sig_table.rows[0].cells
        scells[0].text = 'LỆNH TRƯỞNG'
        scells[1].text = 'ĐIỀU HÀNH BẾN'
        scells[2].text = 'TÀI XẾ'
        for cell in scells:
            cell.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
            cell.paragraphs[0].runs[0].bold = True

        f = io.BytesIO()
        doc.save(f)
        f.seek(0)
        return send_file(
            f,
            as_attachment=True,
            download_name=f'manifest_{trip_id}.docx',
            mimetype='application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )

    def download_order(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        if trip.route.company_id != session['company_id']:
            flash('Truy cập bị từ chối!')
            return redirect(url_for('admin'))
            
        doc = Document()
        doc.add_heading('LỆNH VẬN CHUYỂN', 0).alignment = WD_ALIGN_PARAGRAPH.CENTER
        
        doc.add_paragraph(f'Mã lệnh: HT-ORDER-{trip_id}-{int(time.time())}')
        doc.add_paragraph(f'Đơn vị vận tải: {trip.route.company.name}')
        doc.add_paragraph(f'Biển kiểm soát: {trip.bus.license_plate}')
        doc.add_paragraph(f'Tuyến đường: {trip.route.start_point} - {trip.route.end_point}')
        doc.add_paragraph(f'Cự ly: {trip.route.distance_km} km')
        doc.add_paragraph(f'Thời gian xuất bến: {trip.departure_time.strftime("%d/%m/%Y %H:%M")}')
        
        doc.add_paragraph('\nPHẦN DÀNH CHO BẾN XE XÁC NHẬN:').bold = True
        doc.add_paragraph('Giờ xe đến bến: ....................................')
        doc.add_paragraph('Giờ xe xuất bến: ...................................')
        doc.add_paragraph('Số khách thực tế: .................................')
        
        doc.add_paragraph('\nCAM KẾT CỦA LÁI XE:').bold = True
        doc.add_paragraph('Tôi cam đoan chạy đúng lộ trình, đúng tốc độ và không chở quá số người quy định.')
        
        doc.add_paragraph('\n\n')
        sig = doc.add_table(rows=1, cols=2)
        sig.rows[0].cells[0].text = 'ĐIỀU HÀNH BẾN'
        sig.rows[0].cells[1].text = 'LÁI XE KÝ TÊN'
        for cell in sig.rows[0].cells:
            cell.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
            
        f = io.BytesIO()
        doc.save(f)
        f.seek(0)
        return send_file(
            f,
            as_attachment=True,
            download_name=f'lenh_van_chuyen_{trip_id}.docx',
            mimetype='application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )
    def admin_food():
        # Show all RestStops (Global)
        stops = RestStop.query.all()
        return render_template('admin/food.html', stops=stops, active_page='food')

    def add_rest_stop():
        name = request.form.get('name')
        location = request.form.get('location')
    
        new_stop = RestStop(name=name, location=location)
        db.session.add(new_stop)
        db.session.commit()
        flash('Đã thêm trạm dừng chân mới!')
        return redirect(url_for('admin_food'))

    def add_menu_item():
        rest_stop_id = request.form.get('rest_stop_id')
        name = request.form.get('name')
        price = float(request.form.get('price'))
        description = request.form.get('description')
    
        image_url = None
        if 'image' in request.files:
            file = request.files['image']
            if file.filename != '':
                filename = secure_filename(file.filename)
                # Unique filename to prevent overwrite
                unique_filename = f"{int(time.time())}_{filename}"
                file.save(os.path.join(app.root_path, app.config['UPLOAD_FOLDER'], unique_filename))
                image_url = url_for('static', filename=f'uploads/food/{unique_filename}')

        new_item = MenuItem(rest_stop_id=rest_stop_id, name=name, price=price, 
                            description=description, image_url=image_url)
        db.session.add(new_item)
        db.session.commit()
        flash('Đã thêm món ăn vào thực đơn!')
        return redirect(url_for('admin_food'))

    def download_cargo_pdf(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        cargos = Cargo.query.filter_by(trip_id=trip_id).all()
    
        # Try to register Font for Vietnamese
        try:
            pdfmetrics.registerFont(TTFont('Arial', 'C:\\Windows\\Fonts\\arial.ttf'))
            font_name = 'Arial'
        except:
            font_name = 'Helvetica' # Fallback (might not show Vietnamese correctly)

        styles = getSampleStyleSheet()
        title_style = styles['Heading1']
        title_style.fontName = font_name
        title_style.alignment = 1 # Center
    
        normal_style = styles['Normal']
        normal_style.fontName = font_name

        def build_page_content(lien_text):
            elements = []
            elements.append(Paragraph(f"PHIẾU GIAO NHẬN HÀNG HÓA - {lien_text}", title_style))
            elements.append(Spacer(1, 12))
        
            info_text = f"Tuyến: {trip.route.start_point} - {trip.route.end_point} | Xe: {trip.bus.license_plate} | Ngày: {trip.departure_time.strftime('%d/%m/%Y')}"
            elements.append(Paragraph(info_text, normal_style))
            elements.append(Spacer(1, 12))
        
            # Table Header
            data = [['Người gửi', 'Người nhận', 'Mô tả', 'Nặng(kg)', 'Cước(đ)']]
            # Table Data
            for c in cargos:
                data.append([
                    Paragraph(c.sender_name + '\n' + c.sender_phone, normal_style),
                    Paragraph(c.receiver_name + '\n' + c.receiver_phone, normal_style),
                    Paragraph(c.description or '', normal_style),
                    str(c.weight_kg),
                    "{:,.0f}".format(c.cost)
                ])
            
            t = Table(data, colWidths=[120, 120, 150, 60, 80])
            t.setStyle(TableStyle([
                ('FONTNAME', (0,0), (-1,-1), font_name),
                ('INNERGRID', (0,0), (-1,-1), 0.25, colors.black),
                ('BOX', (0,0), (-1,-1), 0.25, colors.black),
                ('BACKGROUND', (0,0), (0,0), colors.lightgrey),
                ('ALIGN', (0,0), (-1,-1), 'LEFT'),
                ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ]))
        
            elements.append(t)
            return elements

        # Combine 2 copies
        story = []
        story.extend(build_page_content("LIÊN 1: NHÀ XE / TÀI XẾ"))
        story.append(Spacer(1, 30))
        story.append(Paragraph("-" * 60, normal_style)) # Cut line
        story.append(Spacer(1, 30))
        story.extend(build_page_content("LIÊN 2: KHÁCH HÀNG"))

        f = io.BytesIO()
        doc = SimpleDocTemplate(f, pagesize=A4)
        doc.build(story)
        f.seek(0)
    
        return send_file(f, as_attachment=True, download_name=f'cargo_manifest_{trip.id}.pdf', mimetype='application/pdf')

    def download_cargo_receipt(cargo_id):
        cargo = Cargo.query.get_or_404(cargo_id)
        if cargo.company_id != session['company_id']:
            return jsonify({'error': 'Unauthorized'}), 403
            
        # Try to register Font for Vietnamese
        try:
            pdfmetrics.registerFont(TTFont('Arial', 'C:\\Windows\\Fonts\\arial.ttf'))
            font_name = 'Arial'
        except:
            font_name = 'Helvetica'

        styles = getSampleStyleSheet()
        title_style = styles['Heading1']
        title_style.fontName = font_name
        title_style.fontSize = 14
        title_style.alignment = 1

        label_style = styles['Normal']
        label_style.fontName = font_name
        label_style.fontSize = 10
        label_style.leading = 14

        bold_style = styles['Normal']
        bold_style.fontName = font_name
        bold_style.fontSize = 10
        bold_style.leading = 14
        # Note: reportlab bold font would need TTFont registration for Arial-Bold. 
        # Using same font for simplicity or adding font registration if possible.

        def build_receipt_copy(copy_name):
            elements = []
            # Header
            elements.append(Paragraph(f"BIÊN NHẬN GIAO NHẬN HÀNG HÓA", title_style))
            elements.append(Paragraph(f"({copy_name})", label_style))
            elements.append(Spacer(1, 10))
            
            # Tracking & Date
            elements.append(Paragraph(f"<b>Mã vận đơn: {cargo.tracking_number}</b>", title_style))
            elements.append(Paragraph(f"Ngày nhận: {datetime.now().strftime('%d/%m/%Y %H:%M')}", label_style))
            elements.append(Spacer(1, 12))

            # Main Info Table
            data = [
                [Paragraph("<b>NGƯỜI GỬI</b>", label_style), Paragraph("<b>NGƯỜI NHẬN</b>", label_style)],
                [Paragraph(f"Tên: {cargo.sender_name}", label_style), Paragraph(f"Tên: {cargo.receiver_name}", label_style)],
                [Paragraph(f"SĐT: {cargo.sender_phone}", label_style), Paragraph(f"SĐT: {cargo.receiver_phone}", label_style)],
                [Paragraph(f"VP Gửi: {cargo.sender_office.name if cargo.sender_office else 'N/A'}", label_style), 
                 Paragraph(f"VP Nhận: {cargo.receiver_office.name if cargo.receiver_office else 'N/A'}", label_style)],
            ]
            t_info = Table(data, colWidths=[250, 250])
            t_info.setStyle(TableStyle([
                ('VALIGN', (0,0), (-1,-1), 'TOP'),
                ('LINEBELOW', (0,0), (-1,0), 0.5, colors.grey),
                ('BOTTOMPADDING', (0,0), (-1,0), 5),
            ]))
            elements.append(t_info)
            elements.append(Spacer(1, 15))

            # Cargo Details Table
            cargo_data = [
                ["Mô tả hàng hóa", "Loại", "Nặng(kg)", "Thanh toán", "Cước phí"],
                [cargo.description, cargo.cargo_type, f"{cargo.weight_kg} kg", cargo.payment_status, "{:,.0f} đ".format(cargo.cost)]
            ]
            if cargo.cod_amount > 0:
                cargo_data.append(["", "", "", "Thu hộ (COD):", "{:,.0f} đ".format(cargo.cod_amount)])

            t_cargo = Table(cargo_data, colWidths=[200, 80, 60, 80, 80])
            t_cargo.setStyle(TableStyle([
                ('FONTNAME', (0,0), (-1,-1), font_name),
                ('GRID', (0,0), (-1,-1), 0.5, colors.black),
                ('BACKGROUND', (0,0), (-1,0), colors.lightgrey),
                ('ALIGN', (0,0), (-1,-1), 'CENTER'),
                ('ALIGN', (0,1), (0,-1), 'LEFT'),
            ]))
            elements.append(t_cargo)
            elements.append(Spacer(1, 20))

            # Signatures
            sig_data = [
                ["Người gửi hàng", "Nhân viên nhận hàng", "Người nhận hàng"],
                ["(Ký và ghi rõ họ tên)", "(Ký và ghi rõ họ tên)", "(Ký và ghi rõ họ tên)"],
                ["", "", ""],
                ["", "", ""]
            ]
            t_sig = Table(sig_data, colWidths=[166, 166, 166], rowHeights=[15, 15, 50, 15])
            t_sig.setStyle(TableStyle([
                ('FONTNAME', (0,0), (-1,-1), font_name),
                ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ]))
            elements.append(t_sig)
            
            # Terms
            elements.append(Spacer(1, 10))
            terms = "Lưu ý: Quý khách vui lòng kiểm tra hàng hóa trước khi rời khỏi văn phòng. Mọi khiếu nại sau khi đã nhận hàng sẽ không được giải quyết."
            elements.append(Paragraph(f"<font size='8'><i>{terms}</i></font>", label_style))
            
            return elements

        story = []
        # Copy 1
        story.extend(build_receipt_copy("LIÊN 1: NHÀ XE LƯU"))
        story.append(Spacer(1, 40))
        story.append(Paragraph("-" * 120, label_style)) # Dash line
        story.append(Spacer(1, 40))
        # Copy 2
        story.extend(build_receipt_copy("LIÊN 2: KHÁCH HÀNG GIỮ"))

        f = io.BytesIO()
        doc = SimpleDocTemplate(f, pagesize=A4, rightMargin=30, leftMargin=30, topMargin=30, bottomMargin=30)
        doc.build(story)
        f.seek(0)

        return send_file(f, as_attachment=True, download_name=f'receipt_{cargo.tracking_number}.pdf', mimetype='application/pdf')

    def admin_optimization():
        bus_types = db.session.query(Bus.bus_type).distinct().all()
        # Mock data for demonstration if DB is empty
        return render_template('admin/optimization.html', bus_types=[b[0] for b in bus_types])

    def predict_bus_type():
        data = request.json
        # Instead of predicting, we now ask for input or use simple averages
        # But to be "intelligent" without AI, we use statistical heuristics
        hour = int(data.get('hour', 8))
        is_weekend = data.get('is_weekend', False) # New input
    
        # 1. Base Demand Calculation (Rule Based)
        # Peak hours: 07-09, 18-22
        base_demand = 15 # Minimum baseline
    
        if 7 <= hour <= 9: 
            base_demand += 15 # Morning rush
        elif 18 <= hour <= 22:
            base_demand += 20 # Evening rush
        elif 11 <= hour <= 13:
            base_demand += 5 # Noon
        
        if is_weekend:
            base_demand *= 1.3 # 30% increase on weekends
        
        estimated_pax = int(base_demand)
    
        # 2. Optimization Logic (Deterministic)
        if estimated_pax <= 29:
            rec_type = "Ghế ngồi 29 chỗ (Universe Mini)"
            fuel_mod = "Thấp (14L/100km)"
            savings = "30%"
            logic = f"Nhu cầu thấp (~{estimated_pax} khách). Sử dụng xe 29 chỗ lấp đầy {int(estimated_pax/29*100)}% ghế."
        elif 29 < estimated_pax <= 34:
            rec_type = "Limousine 34 Phòng"
            fuel_mod = "Trung bình (22L/100km)"
            savings = "10%"
            logic = f"Nhu cầu trung bình (~{estimated_pax} khách). Limousine 34 phòng là lựa chọn cân bằng nhất."
        else:
            rec_type = "Giường nằm 44 chỗ (Mobihome)"
            fuel_mod = "Cao (28L/100km)"
            savings = "0%"
            logic = f"Nhu cầu cao (~{estimated_pax} khách). Cần sử dụng xe lớn nhất để tránh mất doanh thu."
        
        recommendation = {
            "predicted_demand": estimated_pax,
            "recommended_bus_type": rec_type,
            "reason": logic,
            "fuel_saving_est": savings
        }
    
        return jsonify(recommendation)

    def admin_trip_detail(trip_id):
        trip = Trip.query.get_or_404(trip_id)
        if trip.route.company_id != session['company_id']:
            return jsonify({'error': 'Unauthorized'}), 403
            
        return jsonify({
            'id': trip.id,
            'route': f"{trip.route.start_point} - {trip.route.end_point}",
            'start_point': trip.route.start_point,
            'end_point': trip.route.end_point,
            'bus': trip.bus.license_plate,
            'bus_type': trip.bus.bus_type,
            'departure_time': trip.departure_time.isoformat(),
            'status': trip.status,
            'occupancy': f"{len(trip.bookings)}/{trip.bus.total_seats}",
            'driver': trip.driver_ref.name if trip.driver_ref else 'Chưa phân công'
        })

    def admin_search_passengers():
        company_id = session.get('company_id')
        query_text = request.args.get('q', '').strip()
        if not query_text: return jsonify([])
        
        bookings = Booking.query.join(Trip).join(Route).filter(
            Route.company_id == company_id,
            (Booking.passenger_name.ilike(f"%{query_text}%")) | 
            (Booking.passenger_phone.ilike(f"%{query_text}%"))
        ).limit(50).all()
        
        return jsonify([{
            'id': b.id,
            'name': b.passenger_name,
            'phone': b.passenger_phone,
            'seat': b.seat_number,
            'trip_id': b.trip_id,
            'trip_route': f"{b.trip.route.start_point} - {b.trip.route.end_point}",
            'departure_time': b.trip.departure_time.isoformat(),
            'status': b.status,
            'boarding_status': b.boarding_status
        } for b in bookings]), 200

    app.add_url_rule('/admin/reports', view_func=admin_only(admin_reports))
    app.add_url_rule('/admin/trip/<int:trip_id>/complete', view_func=staff_role_required('STATION_STAFF')(complete_trip), methods=['POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/status', view_func=staff_role_required('STATION_STAFF')(update_trip_status), methods=['POST'])
    app.add_url_rule('/legacy-admin', view_func=company_login_required(admin))
    app.add_url_rule('/admin/routes', view_func=admin_only(admin_routes_page))
    app.add_url_rule('/admin/buses', view_func=admin_only(admin_buses_page))
    app.add_url_rule('/admin/trips', view_func=company_login_required(admin_trips_page))
    app.add_url_rule('/admin/staff', view_func=admin_only(admin_staff_page))
    app.add_url_rule('/admin/driver/add', view_func=admin_only(add_driver), methods=['POST'])
    app.add_url_rule('/admin/assistant/add', view_func=admin_only(add_assistant), methods=['POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/breakdown', view_func=admin_only(admin_trip_breakdown), methods=['GET', 'POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/transfer', view_func=admin_only(execute_transfer), methods=['POST'])
    app.add_url_rule('/admin/route/add', view_func=admin_only(add_route), methods=['POST'])
    app.add_url_rule('/admin/route/delete/<int:route_id>', view_func=admin_only(delete_route), methods=['POST'])
    app.add_url_rule('/admin/bus/add', view_func=admin_only(add_bus), methods=['POST'])
    app.add_url_rule('/admin/trip/add', view_func=admin_only(add_trip), methods=['POST'])
    app.add_url_rule('/admin/trip/edit/<int:trip_id>', view_func=admin_only(edit_trip), methods=['GET', 'POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/passengers', view_func=company_login_required(trip_passengers))
    app.add_url_rule('/admin/trip/<int:trip_id>/cargo', view_func=staff_role_required('STATION_STAFF')(trip_cargo), methods=['GET', 'POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/download', view_func=staff_role_required('STATION_STAFF')(download_manifest), endpoint='admin_download_manifest')
    app.add_url_rule('/admin/food', view_func=admin_only(admin_food))
    app.add_url_rule('/admin/rest_stop/add', view_func=admin_only(add_rest_stop), methods=['POST'])
    app.add_url_rule('/admin/menu_item/add', view_func=admin_only(add_menu_item), methods=['POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/cargo/pdf', view_func=staff_role_required('STATION_STAFF')(download_cargo_pdf))
    app.add_url_rule('/admin/optimization', view_func=admin_only(admin_optimization))
    app.add_url_rule('/api/predict/bus-type', view_func=admin_only(predict_bus_type), methods=['POST'])

    def admin_manage_booking(booking_id=None):
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        
        data = request.get_json(silent=True) or {}
        action = request.method
        
        if action == 'PUT':
            booking = Booking.query.get_or_404(booking_id)
            if booking.trip.route.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
            
            booking.passenger_name = data.get('name', booking.passenger_name)
            booking.passenger_phone = data.get('phone', booking.passenger_phone)
            booking.pickup_point = data.get('pickup', booking.pickup_point)
            booking.dropoff_point = data.get('dropoff', booking.dropoff_point)
            try:
                booking.ticket_price = int(float(data.get('price', booking.ticket_price)))
            except: pass
            
            db.session.commit()
            return jsonify({'success': True, 'message': 'Cập nhật thành công'})
            
        elif action == 'DELETE':
            booking = Booking.query.get(booking_id)
            if not booking:
                with open('error_log.txt', 'a') as f: f.write(f'DELETE failed: Booking {booking_id} not found\n')
                return jsonify({'error': 'Not found'}), 404
            if booking.trip.route.company_id != company_id:
                with open('error_log.txt', 'a') as f: f.write(f'DELETE failed: Forbidden company_id {booking.trip.route.company_id} != {company_id}\n')
                return jsonify({'error': 'Forbidden'}), 403
            
            try:
                from routes_booking import _archive_booking_for_reuse
                _archive_booking_for_reuse(booking, reason='CANCELLED')
                db.session.commit()
                return jsonify({'success': True, 'message': 'Đã xóa vé'})
            except Exception as e:
                db.session.rollback()
                with open('error_log.txt', 'a') as f: f.write(f'DELETE failed Exception: {str(e)}\n')
                return jsonify({'success': False, 'message': str(e)}), 500

    def admin_manage_route(route_id=None):
        company_id = session.get('company_id')
        if not company_id: return jsonify({'error': 'Unauthorized'}), 401
        
        data = request.json
        action = request.method
        
        if action == 'PUT':
            route = Route.query.get_or_404(route_id)
            if route.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
            
            route.start_point = data.get('start_point', route.start_point)
            route.end_point = data.get('end_point', route.end_point)
            route.distance_km = float(data.get('distance_km', route.distance_km))
            route.duration_hours = float(data.get('duration_hours', route.duration_hours))
            route.base_price = int(data.get('base_price', route.base_price))
            
            db.session.commit()
            return jsonify({'message': 'Tuyến đường đã được cập nhật'})
            
        elif action == 'DELETE':
            route = Route.query.get_or_404(route_id)
            if route.company_id != company_id: return jsonify({'error': 'Forbidden'}), 403
            
            trips_count = Trip.query.filter_by(route_id=route_id).count()
            if trips_count > 0:
                return jsonify({'error': f'Không thể xóa: Có {trips_count} chuyến xe đang sử dụng tuyến này.'}), 400
                
            db.session.delete(route)
            db.session.commit()
            return jsonify({'message': 'Đã xóa tuyến đường'})
    
    # JSON API Endpoints for React
    app.add_url_rule('/api/admin/trips', view_func=company_login_required(admin_trips_data), methods=['GET'])
    app.add_url_rule('/api/admin/trips', view_func=company_login_required(admin_create_trip), methods=['POST'])
    app.add_url_rule('/api/admin/routes', view_func=company_login_required(admin_routes_data), methods=['GET'])
    app.add_url_rule('/api/admin/routes', view_func=company_login_required(admin_create_route), methods=['POST'])
    app.add_url_rule('/api/admin/cargo', view_func=company_login_required(admin_cargo_data), methods=['GET'])
    app.add_url_rule('/api/admin/cargo', view_func=company_login_required(admin_create_cargo), methods=['POST'])
    app.add_url_rule('/api/admin/cargo/batch', view_func=company_login_required(admin_batch_update_cargo), methods=['PUT'])
    app.add_url_rule('/api/admin/cargo/<int:cargo_id>/receipt', view_func=company_login_required(download_cargo_receipt))
    app.add_url_rule('/api/admin/cargo/<int:cargo_id>', view_func=company_login_required(admin_update_cargo), methods=['PUT'])
    app.add_url_rule('/api/admin/cargo/<int:cargo_id>', view_func=company_login_required(admin_delete_cargo), methods=['DELETE'])
    app.add_url_rule('/api/admin/trip/<int:trip_id>/passengers', view_func=company_login_required(admin_trip_passengers))
    app.add_url_rule('/api/admin/buses', view_func=company_login_required(admin_buses_data), methods=['GET'])
    app.add_url_rule('/api/admin/buses', view_func=company_login_required(admin_manage_bus), methods=['POST'], endpoint='admin_post_bus')
    app.add_url_rule('/api/admin/buses/<int:bus_id>', view_func=company_login_required(admin_manage_bus), methods=['PUT', 'DELETE'], endpoint='admin_put_delete_bus')
    app.add_url_rule('/api/admin/staff/<role>', view_func=company_login_required(admin_staff_list))
    app.add_url_rule('/api/admin/staff', view_func=company_login_required(admin_manage_staff), methods=['POST', 'PUT', 'DELETE'])
    app.add_url_rule('/api/admin/trip/<int:trip_id>/export/manifest', view_func=company_login_required(download_manifest), endpoint='api_admin_export_manifest')
    app.add_url_rule('/api/admin/trip/<int:trip_id>/export/order', view_func=company_login_required(download_order), endpoint='api_admin_export_order')
    app.add_url_rule('/api/admin/trip/<int:trip_id>', view_func=company_login_required(admin_trip_detail))
    app.add_url_rule('/api/admin/stats', view_func=company_login_required(admin_stats_data))
    
    app.add_url_rule('/api/admin/offices', view_func=company_login_required(admin_offices_data), methods=['GET'])
    app.add_url_rule('/api/admin/offices', view_func=company_login_required(admin_create_office), methods=['POST'])
    app.add_url_rule('/api/admin/offices/<int:office_id>', view_func=company_login_required(admin_update_office), methods=['PUT'])
    app.add_url_rule('/api/admin/offices/<int:office_id>', view_func=company_login_required(admin_delete_office), methods=['DELETE'])
    app.add_url_rule('/api/admin/passengers/search', view_func=company_login_required(admin_search_passengers), methods=['GET'])
    app.add_url_rule('/api/admin/bookings/<int:booking_id>', view_func=company_login_required(admin_manage_booking), methods=['PUT', 'DELETE'])
    app.add_url_rule('/api/admin/routes/<int:route_id>', view_func=company_login_required(admin_manage_route), methods=['PUT', 'DELETE'])
