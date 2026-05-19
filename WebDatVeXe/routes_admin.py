import csv
import io
import json
import os
import time
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

from constants import VIETNAM_PROVINCES
from decorators import admin_only, company_login_required, staff_role_required
from extensions import db, mail
from models import Assistant, Booking, Bus, Cargo, Driver, FoodOrder, MenuItem, RestStop, Route, Trip


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
    def run_auto_complete():
        """Chạy auto-complete trước mỗi request vào admin (không lồng app_context)."""
        if request.path.startswith('/admin'):
            auto_complete_trips()

    def admin_reports():
        company_id = session['company_id']
    
        # 1. Revenue
        # Join Trip -> Route -> Company
        revenue_tickets = db.session.query(db.func.sum(Booking.ticket_price)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id, Booking.status == 'CONFIRMED').scalar() or 0
        
        revenue_cargo = db.session.query(db.func.sum(Cargo.cost)).join(Trip).join(Route)\
            .filter(Route.company_id == company_id).scalar() or 0
        
        total_revenue = revenue_tickets + revenue_cargo
    
        # 2. Occupancy Rate
        # Total seats available in all past/future trips
        # This is a simple approx for demo
        trips = Trip.query.join(Route).filter(Route.company_id == company_id).all()
        total_capacity = sum([t.bus.total_seats for t in trips])
        total_booked = Booking.query.join(Trip).join(Route)\
            .filter(Route.company_id == company_id, Booking.status == 'CONFIRMED').count()
        
        occupancy_rate = (total_booked / total_capacity * 100) if total_capacity > 0 else 0
    
        return render_template('reports.html', 
                               revenue_tickets=revenue_tickets, 
                               revenue_cargo=revenue_cargo,
                               total_revenue=total_revenue,
                               occupancy_rate=occupancy_rate)

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
        # Check ownership
        if trip.route.company_id != session['company_id']:
            flash('Truy cập bị từ chối!')
            return redirect(url_for('admin'))
    
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(['Số ghế', 'Tên hành khách', 'Số điện thoại', 'Điểm đón', 'Trạng thái', 'Thanh toán'])
    
        bookings = Booking.query.filter_by(trip_id=trip_id).all()
        for b in bookings:
            writer.writerow([
                b.seat_number, 
                b.passenger_name, 
                b.passenger_phone, 
                b.pickup_point,
                b.status,
                b.payment_status
            ])
    
        writer.writerow([])
        writer.writerow(['DANH SÁCH HÀNG HÓA KÝ GỬI'])
        writer.writerow(['Người gửi', 'SĐT Gửi', 'Người nhận', 'SĐT Nhận', 'Mô tả', 'Cước phí'])
        cargos = Cargo.query.filter_by(trip_id=trip_id).all()
        for c in cargos:
            writer.writerow([c.sender_name, c.sender_phone, c.receiver_name, c.receiver_phone, c.description, c.cost])

        output.seek(0)
        return send_file(
            io.BytesIO(output.getvalue().encode('utf-8-sig')),
            mimetype='text/csv',
            as_attachment=True,
            download_name=f'manifest_{trip.bus.license_plate}_{trip.departure_time.strftime("%Y%m%d")}.csv'
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

    app.add_url_rule('/admin/reports', view_func=admin_only(admin_reports))
    app.add_url_rule('/admin/trip/<int:trip_id>/complete', view_func=staff_role_required('STATION_STAFF')(complete_trip), methods=['POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/status', view_func=staff_role_required('STATION_STAFF')(update_trip_status), methods=['POST'])
    app.add_url_rule('/admin', view_func=company_login_required(admin))
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
    app.add_url_rule('/admin/trip/<int:trip_id>/download', view_func=staff_role_required('STATION_STAFF')(download_manifest))
    app.add_url_rule('/admin/food', view_func=admin_only(admin_food))
    app.add_url_rule('/admin/rest_stop/add', view_func=admin_only(add_rest_stop), methods=['POST'])
    app.add_url_rule('/admin/menu_item/add', view_func=admin_only(add_menu_item), methods=['POST'])
    app.add_url_rule('/admin/trip/<int:trip_id>/cargo/pdf', view_func=staff_role_required('STATION_STAFF')(download_cargo_pdf))
    app.add_url_rule('/admin/optimization', view_func=admin_only(admin_optimization))
    app.add_url_rule('/api/predict/bus-type', view_func=admin_only(predict_bus_type), methods=['POST'])
