import io
import json
import uuid
import qrcode
from datetime import datetime


from flask import Blueprint, flash, jsonify, redirect, render_template, request, send_file, session, url_for
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage

from extensions import db, socketio
from models import Trip, Booking, Cargo, Staff, TransportOrder, CargoHistory, AuditLog

ops_bp = Blueprint('ops', __name__)

# --- UTILITIES ---

def log_audit(action, table_name, record_id, old_val=None, new_val=None):
    """Utility to log system changes for 'Admin tổng'."""
    log = AuditLog(
        user_id=session.get('user_id') or session.get('staff_id') or session.get('company_id'),
        user_type=session.get('role', 'SYSTEM'),
        table_name=table_name,
        record_id=record_id,
        action=action,
        old_values=json.dumps(old_val) if old_val else None,
        new_values=json.dumps(new_val) if new_val else None,
        ip_address=request.remote_addr
    )
    db.session.add(log)

def get_vietnamese_font():
    """Try to register Arial for Vietnamese PDF support."""
    try:
        pdfmetrics.registerFont(TTFont('Arial', 'C:\\Windows\\Fonts\\arial.ttf'))
        return 'Arial'
    except:
        return 'Helvetica'

# --- MODULE 1: IN PHƠI (PRINTING MANIFESTS) ---

@ops_bp.route('/ops/print/passengers/<int:trip_id>')
def print_passengers(trip_id):
    trip = Trip.query.get_or_404(trip_id)
    bookings = Booking.query.filter_by(trip_id=trip_id).order_by(Booking.seat_number).all()
    
    font_name = get_vietnamese_font()
    styles = getSampleStyleSheet()
    title_style = styles['Heading1']
    title_style.fontName = font_name
    title_style.alignment = 1 # Center
    
    normal_style = styles['Normal']
    normal_style.fontName = font_name

    f = io.BytesIO()
    doc = SimpleDocTemplate(f, pagesize=A4)
    elements = []

    # Header
    elements.append(Paragraph(f"DANH SÁCH HÀNH KHÁCH (PHƠI XE)", title_style))
    elements.append(Spacer(1, 12))
    
    info_text = f"<b>Tuyến:</b> {trip.route.start_point} - {trip.route.end_point} | <b>Xe:</b> {trip.bus.license_plate}<br/>"
    info_text += f"<b>Tài xế:</b> {trip.driver_name or '...'} | <b>Phụ xe:</b> {trip.assistant_name or '...'}<br/>"
    info_text += f"<b>Giờ xuất bến:</b> {trip.departure_time.strftime('%H:%M %d/%m/%Y')}"
    elements.append(Paragraph(info_text, normal_style))
    elements.append(Spacer(1, 20))

    # Table
    data = [['Ghế', 'Khách hàng', 'SĐT', 'Điểm lên', 'Điểm xuống', 'Trạng thái']]
    for b in bookings:
        data.append([
            b.seat_number,
            b.passenger_name,
            b.passenger_phone,
            Paragraph(b.pickup_point or '', normal_style),
            Paragraph(b.dropoff_point or '', normal_style),
            b.boarding_status
        ])

    t = Table(data, colWidths=[40, 100, 80, 120, 120, 60])
    t.setStyle(TableStyle([
        ('FONTNAME', (0,0), (-1,-1), font_name),
        ('INNERGRID', (0,0), (-1,-1), 0.25, colors.black),
        ('BOX', (0,0), (-1,-1), 0.25, colors.black),
        ('BACKGROUND', (0,0), (-1,0), colors.lightgrey),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    elements.append(t)
    
    doc.build(elements)
    f.seek(0)
    from flask import make_response
    response = make_response(f.read())
    response.headers.set('Content-Type', 'application/pdf')
    response.headers.set('Content-Disposition', 'attachment', filename=f'phoi_khach_{trip_id}.pdf')
    return response

@ops_bp.route('/ops/print/cargo/<int:trip_id>')
def print_cargo(trip_id):
    trip = Trip.query.get_or_404(trip_id)
    cargos = Cargo.query.filter_by(trip_id=trip_id).all()
    
    font_name = get_vietnamese_font()
    styles = getSampleStyleSheet()
    title_style = styles['Heading1']
    title_style.fontName = font_name
    title_style.alignment = 1
    
    normal_style = styles['Normal']
    normal_style.fontName = font_name

    f = io.BytesIO()
    doc = SimpleDocTemplate(f, pagesize=A4)
    elements = []

    elements.append(Paragraph(f"DANH SÁCH HÀNG HÓA KÝ GỬI", title_style))
    elements.append(Spacer(1, 12))
    
    info_text = f"<b>Tuyến:</b> {trip.route.start_point} - {trip.route.end_point} | <b>Xe:</b> {trip.bus.license_plate}<br/>"
    info_text += f"<b>Ngày:</b> {trip.departure_time.strftime('%d/%m/%Y')}"
    elements.append(Paragraph(info_text, normal_style))
    elements.append(Spacer(1, 20))

    data = [['Mã vận đơn', 'Người gửi/SĐT', 'Người nhận/SĐT', 'Loại hàng', 'Cước phí', 'Trạng thái']]
    for c in cargos:
        data.append([
            c.tracking_number or f"CG-{c.id}",
            f"{c.sender_name}\n{c.sender_phone}",
            f"{c.receiver_name}\n{c.receiver_phone}",
            c.cargo_type,
            "{:,.0f}".format(c.cost),
            c.status
        ])

    t = Table(data, colWidths=[80, 120, 120, 70, 70, 70])
    t.setStyle(TableStyle([
        ('FONTNAME', (0,0), (-1,-1), font_name),
        ('INNERGRID', (0,0), (-1,-1), 0.25, colors.black),
        ('BOX', (0,0), (-1,-1), 0.25, colors.black),
        ('BACKGROUND', (0,0), (-1,0), colors.lightgrey),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    elements.append(t)
    
    doc.build(elements)
    f.seek(0)
    from flask import make_response
    response = make_response(f.read())
    response.headers.set('Content-Type', 'application/pdf')
    response.headers.set('Content-Disposition', 'attachment', filename=f'phoi_hang_{trip_id}.pdf')
    return response

# --- MODULE 3: HỦY CHUYẾN (TRIP CANCELLATION) ---

@ops_bp.route('/ops/trip/cancel/<int:trip_id>', methods=['POST'])
def cancel_trip(trip_id):
    trip = Trip.query.get_or_404(trip_id)
    reason = request.form.get('reason', 'Lý do khác')
    
    if trip.status == 'Cancelled':
        flash('Chuyến xe này đã được hủy trước đó.')
        return redirect(url_for('admin_trips_page'))

    # Record old state for audit
    old_status = trip.status
    
    # Update trip status
    trip.status = 'Cancelled'
    trip.cancellation_reason = reason
    trip.canceled_at = datetime.utcnow()
    trip.canceled_by_id = session.get('staff_id')
    
    # Release resources
    trip.driver_id = None
    trip.assistant_id = None
    
    # Handle refunds (Logically mark bookings as cancelled)
    for booking in trip.bookings:
        if booking.status == 'CONFIRMED':
            booking.status = 'CANCELLED'
            # Here you would trigger PayOS refund if implemented
    
    log_audit('CANCEL', 'trip', trip_id, {'status': old_status}, {'status': 'Cancelled', 'reason': reason})
    db.session.commit()
    
    # Notify via SocketIO
    socketio.emit('trip_update', {'trip_id': trip_id, 'status': 'Cancelled'}, namespace='/ops')
    
    flash(f'Đã hủy chuyến #{trip_id} thành công.')
    return redirect(url_for('admin_trips_page'))

# --- MODULE 4: LỆNH VẬN CHUYỂN (TRANSPORT ORDERS) ---

@ops_bp.route('/ops/trip/issue-order/<int:trip_id>', methods=['POST'])
def issue_transport_order(trip_id):
    trip = Trip.query.get_or_404(trip_id)
    
    # Check if already exists
    existing = TransportOrder.query.filter_by(trip_id=trip_id, status='ACTIVE').first()
    if existing:
        flash('Lệnh vận chuyển cho chuyến này đã tồn tại.')
        return redirect(url_for('admin_trips_page'))

    order_code = f"LVC-{datetime.now().strftime('%y%m%d')}-{trip_id}"
    new_order = TransportOrder(
        trip_id=trip_id,
        order_code=order_code,
        issued_by_id=session.get('staff_id') or 1, # Fallback
        notes=request.form.get('notes', '')
    )
    db.session.add(new_order)
    db.session.commit()
    
    flash(f'Đã tạo lệnh vận chuyển {order_code}.')
    return redirect(url_for('admin_trips_page'))

# --- MODULE 6: QUẢN LÝ HÀNG HÓA (CARGO MGMT) ---

@ops_bp.route('/ops/cargo/update-status/<int:cargo_id>', methods=['POST'])
def update_cargo_status(cargo_id):
    cargo = Cargo.query.get_or_404(cargo_id)
    new_status = request.form.get('status')
    location = request.form.get('location', 'Kho bến xe')
    remarks = request.form.get('remarks', '')
    
    old_status = cargo.status
    cargo.status = new_status
    
    # Add to history
    history = CargoHistory(
        cargo_id=cargo_id,
        status=new_status,
        location=location,
        updated_by_id=session.get('staff_id'),
        remarks=remarks
    )
    db.session.add(history)
    
    if new_status == 'DELIVERED':
        cargo.collected_at = datetime.utcnow()
        
    log_audit('UPDATE', 'cargo', cargo_id, {'status': old_status}, {'status': new_status})
    db.session.commit()
    
    return jsonify({'success': True, 'new_status': new_status})

# --- BOARDING STATUS ---

@ops_bp.route('/ops/booking/check-in/<int:booking_id>', methods=['POST'])
def check_in_passenger(booking_id):
    booking = Booking.query.get_or_404(booking_id)
    status = request.form.get('status', 'BOARDED') # BOARDED, ABSENT, DROPPED_OFF
    
    booking.boarding_status = status
    if status == 'BOARDED':
        booking.check_in_time = datetime.utcnow()
    
    db.session.commit()
    
    # Real-time update for seat map
    socketio.emit('seat_update', {
        'trip_id': booking.trip_id,
        'seat_number': booking.seat_number,
        'status': status
    }, namespace='/ops')
    
    return jsonify({'success': True, 'status': status})

# --- MODULE 8: TRUY XUẤT LỊCH SỬ (HISTORY RETRIEVAL) ---

@ops_bp.route('/admin/audit-logs')
def admin_audit_logs():
    logs = AuditLog.query.order_by(AuditLog.created_at.desc()).limit(200).all()
    return render_template('admin/audit_logs.html', logs=logs, active_page='audit_logs')

@ops_bp.route('/admin/vehicle-history/<int:bus_id>')
def admin_vehicle_history(bus_id):
    from models import Bus
    bus = Bus.query.get_or_404(bus_id)
    trips = Trip.query.filter_by(bus_id=bus_id).order_by(Trip.departure_time.desc()).all()
    return render_template('admin/vehicle_history.html', bus=bus, trips=trips, active_page='buses')

@ops_bp.route('/ops/cargo/history/<int:cargo_id>')
def cargo_tracking_history(cargo_id):
    cargo = Cargo.query.get_or_404(cargo_id)
    history = CargoHistory.query.filter_by(cargo_id=cargo_id).order_by(CargoHistory.timestamp.desc()).all()
    return render_template('admin/cargo_history.html', cargo=cargo, history=history, active_page='trips')

@ops_bp.route('/admin/departure-history')
def admin_departure_history():
    # Only show Completed or Cancelled trips as "history"
    trips = Trip.query.filter(Trip.status.in_(['Completed', 'Cancelled'])).order_by(Trip.departure_time.desc()).all()
    return render_template('admin/departure_history.html', trips=trips, active_page='departure_history')

def register_ops_routes(app):
    app.register_blueprint(ops_bp)
