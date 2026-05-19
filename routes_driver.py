from flask import Blueprint, flash, jsonify, redirect, render_template, request, session, url_for
from datetime import datetime
from extensions import db, socketio
from models import Trip, Booking, Cargo, TripIncident, Staff, Driver
from decorators import driver_required

driver_bp = Blueprint('driver', __name__)

@driver_bp.route('/driver/dashboard')
@driver_required
def dashboard():
    staff_id = session.get('staff_id')
    staff = Staff.query.get(staff_id)
    
    if not staff or not staff.driver_id:
        if session.get('role') != 'ADMIN':
            flash('Tài khoản của bạn chưa được liên kết với hồ sơ tài xế!')
            return redirect(url_for('admin'))
        # Admin can see all trips for demo
        trips = Trip.query.filter(Trip.status != 'Completed').order_by(Trip.departure_time.asc()).all()
    else:
        trips = Trip.query.filter_by(driver_id=staff.driver_id).filter(Trip.status != 'Completed').order_by(Trip.departure_time.asc()).all()
        
    return render_template('driver/dashboard.html', trips=trips, active_page='driver_dashboard')

@driver_bp.route('/driver/trip/<int:trip_id>')
@driver_required
def trip_detail(trip_id):
    trip = Trip.query.get_or_404(trip_id)
    bookings = Booking.query.filter_by(trip_id=trip_id).order_by(Booking.seat_number).all()
    cargos = Cargo.query.filter_by(trip_id=trip_id).all()
    
    return render_template('driver/trip_detail.html', trip=trip, bookings=bookings, cargos=cargos)

@driver_bp.route('/driver/check-in/<int:booking_id>', methods=['POST'])
@driver_required
def check_in(booking_id):
    booking = Booking.query.get_or_404(booking_id)
    status = request.form.get('status')
    
    if status not in ['BOARDED', 'ABSENT', 'PENDING', 'DROPPED_OFF']:
        return jsonify({'success': False, 'message': 'Trạng thái không hợp lệ'})
    
    booking.boarding_status = status
    if status == 'BOARDED':
        booking.check_in_time = datetime.utcnow()
        booking.checked_in_by_id = session.get('staff_id')
        
    db.session.commit()
    
    # Broadcast to admin dashboard
    socketio.emit('seat_update', {
        'trip_id': booking.trip_id,
        'seat_number': booking.seat_number,
        'status': status
    }, namespace='/ops')
    
    return jsonify({'success': True, 'new_status': status})

@driver_bp.route('/driver/report-incident/<int:trip_id>', methods=['GET', 'POST'])
@driver_required
def report_incident(trip_id):
    trip = Trip.query.get_or_404(trip_id)
    
    if request.method == 'POST':
        incident_type = request.form.get('type')
        description = request.form.get('description')
        location = request.form.get('location')
        
        incident = TripIncident(
            trip_id=trip_id,
            staff_id=session.get('staff_id'),
            type=incident_type,
            description=description,
            location=location
        )
        db.session.add(incident)
        
        # If severe, mark trip as 'Broken' or similar
        if incident_type in ['BREAKDOWN', 'ACCIDENT']:
            trip.status = 'Broken'
            
        db.session.commit()
        flash('Đã gửi báo cáo sự cố về trung tâm điều hành.')
        return redirect(url_for('driver.trip_detail', trip_id=trip_id))
        
    return render_template('driver/report_incident.html', trip=trip)

@driver_bp.route('/driver/trip/complete/<int:trip_id>', methods=['POST'])
@driver_required
def complete_trip(trip_id):
    trip = Trip.query.get_or_404(trip_id)
    trip.status = 'Completed'
    trip.actual_arrival = datetime.utcnow()
    
    # Clear driver/assistant from trip to make them free
    trip.driver_id = None
    trip.assistant_id = None
    
    db.session.commit()
    flash('Đã xác nhận hoàn thành chuyến đi.')
    return redirect(url_for('driver.dashboard'))

def register_driver_routes(app):
    app.register_blueprint(driver_bp)
