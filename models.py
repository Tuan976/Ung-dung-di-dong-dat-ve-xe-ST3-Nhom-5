import uuid
from datetime import datetime


from extensions import db


route_stops = db.Table('route_stops',
    db.Column('route_id', db.Integer, db.ForeignKey('route.id'), primary_key=True),
    db.Column('rest_stop_id', db.Integer, db.ForeignKey('rest_stop.id'), primary_key=True)
)


class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    phone = db.Column(db.String(20))
    
    # New fields for SOS & Location tracking
    fcm_token = db.Column(db.String(255), nullable=True)
    last_lat = db.Column(db.Float, nullable=True)
    last_lng = db.Column(db.Float, nullable=True)
    last_location_time = db.Column(db.DateTime, nullable=True)
    
    bookings = db.relationship('Booking', backref='user', lazy=True)


class Company(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    phone = db.Column(db.String(20))
    address = db.Column(db.String(200))
    routes = db.relationship('Route', backref='company', lazy=True)
    buses = db.relationship('Bus', backref='company', lazy=True)


class Staff(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    phone = db.Column(db.String(20))
    role = db.Column(db.String(20), default='STATION_STAFF') # STATION_STAFF, TICKET_OFFICE, DRIVER, ASSISTANT
    status = db.Column(db.String(20), default='Active') # Active, Inactive
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Optional link to personnel records
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True)
    assistant_id = db.Column(db.Integer, db.ForeignKey('assistant.id'), nullable=True)

    company = db.relationship('Company', backref=db.backref('staff_members', lazy=True))


class Route(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    start_point = db.Column(db.String(100), nullable=False)
    end_point = db.Column(db.String(100), nullable=False)
    waypoints = db.Column(db.Text, nullable=True) # JSON list of stops
    distance_km = db.Column(db.Float, nullable=True)
    duration_hours = db.Column(db.Float, nullable=True)
    base_price = db.Column(db.Float, nullable=False)
    trips = db.relationship('Trip', backref='route', lazy=True)
    stops = db.relationship('RestStop', secondary='route_stops', backref='routes', lazy='subquery')


class Bus(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    license_plate = db.Column(db.String(20), nullable=False)
    bus_type = db.Column(db.String(50), nullable=False) # 'sleeper', 'seat', 'limousine'
    color = db.Column(db.String(30)) # New field
    total_seats = db.Column(db.Integer, nullable=False)
    seat_map = db.Column(db.Text, nullable=False) # JSON structure of seats
    driver_name = db.Column(db.String(100))
    driver_phone = db.Column(db.String(20))
    last_maintenance = db.Column(db.Date, nullable=True)
    registration_expiry = db.Column(db.Date, nullable=True)
    trips = db.relationship('Trip', backref='bus', lazy=True)


class Driver(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    license_number = db.Column(db.String(50))
    status = db.Column(db.String(20), default='Active')
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Account link
    staff_account = db.relationship('Staff', backref='driver_personnel', lazy=True, foreign_keys='Staff.driver_id')

    # Relationship to Trip
    trips = db.relationship('Trip', backref='driver_ref', lazy=True)


class Assistant(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    status = db.Column(db.String(20), default='Active')
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Account link
    staff_account = db.relationship('Staff', backref='assistant_personnel', lazy=True, foreign_keys='Staff.assistant_id')

    trips = db.relationship('Trip', backref='assistant_ref', lazy=True)


class Trip(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    route_id = db.Column(db.Integer, db.ForeignKey('route.id'), nullable=False)
    bus_id = db.Column(db.Integer, db.ForeignKey('bus.id'), nullable=False)
    
    # New relationships for Staff
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True) 
    assistant_id = db.Column(db.Integer, db.ForeignKey('assistant.id'), nullable=True)
    
    departure_time = db.Column(db.DateTime, nullable=False)
    arrival_time = db.Column(db.DateTime, nullable=True)
    
    # Legacy/Fallback fields (can be kept for display or compatibility)
    driver_name = db.Column(db.String(100)) 
    assistant_name = db.Column(db.String(100))
    
    status = db.Column(db.String(20), default='Scheduled') # Scheduled, Running, Completed, Cancelled
    
    # New fields for operational tracking
    actual_departure = db.Column(db.DateTime, nullable=True)
    actual_arrival = db.Column(db.DateTime, nullable=True)
    delay_minutes = db.Column(db.Integer, default=0)
    cancellation_reason = db.Column(db.String(255), nullable=True)
    canceled_at = db.Column(db.DateTime, nullable=True)
    canceled_by_id = db.Column(db.Integer, db.ForeignKey('staff.id'), nullable=True) # Linked to Staff who canceled

    bookings = db.relationship('Booking', backref='trip', lazy=True)
    cargos = db.relationship('Cargo', backref='trip', lazy=True)
    transport_orders = db.relationship('TransportOrder', backref='trip', lazy=True)

    # Pricing modifiers specific to this trip (e.g., holiday surge)
    price_multiplier = db.Column(db.Float, default=1.0)


class Booking(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    ticket_code = db.Column(db.String(10), unique=True, nullable=True) # HT12345678
    trip_id = db.Column(db.Integer, db.ForeignKey('trip.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    seat_number = db.Column(db.String(10), nullable=False)
    seat_type = db.Column(db.String(20), default='standard') # standard, vip, sleeper_lower, sleeper_upper
    passenger_name = db.Column(db.String(100), nullable=False)
    passenger_phone = db.Column(db.String(20), nullable=False)
    pickup_point = db.Column(db.String(200))
    dropoff_point = db.Column(db.String(200))
    booking_time = db.Column(db.DateTime, default=datetime.now)
    status = db.Column(db.String(20), default='HOLD') # HOLD, CONFIRMED, CANCELLED
    expires_at = db.Column(db.DateTime, nullable=True) # For holds
    ticket_price = db.Column(db.Float, nullable=False)
    payment_method = db.Column(db.String(50))
    payment_status = db.Column(db.String(20), default='Unpaid')
    payment_id = db.Column(db.String(50), nullable=True) # PayOS orderCode
    
    # New fields for boarding tracking
    boarding_status = db.Column(db.String(20), default='PENDING') # PENDING, BOARDED, DROPPED_OFF, ABSENT
    check_in_time = db.Column(db.DateTime, nullable=True)
    checked_in_by_id = db.Column(db.Integer, db.ForeignKey('staff.id'), nullable=True)
    
    __table_args__ = (db.UniqueConstraint('trip_id', 'seat_number', name='unique_seat_per_trip'),)


class Office(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    address = db.Column(db.String(200))
    phone = db.Column(db.String(20))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    company = db.relationship('Company', backref=db.backref('offices', lazy=True))


class Cargo(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_id = db.Column(db.Integer, db.ForeignKey('company.id'), nullable=False)
    trip_id = db.Column(db.Integer, db.ForeignKey('trip.id'), nullable=True)
    sender_name = db.Column(db.String(100), nullable=False)
    sender_phone = db.Column(db.String(20), nullable=False)
    receiver_name = db.Column(db.String(100), nullable=False)
    receiver_phone = db.Column(db.String(20), nullable=False)
    description = db.Column(db.Text)
    weight_kg = db.Column(db.Float)
    cost = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(20), default='Received')
    
    # New fields for professional cargo management
    uuid = db.Column(db.String(36), default=lambda: str(uuid.uuid4()), unique=True)
    tracking_number = db.Column(db.String(20), unique=True, nullable=False)
    cargo_type = db.Column(db.String(20), default='NORMAL') # SMALL, MEDIUM, LARGE, FRAGILE, HIGH_VALUE
    dimensions = db.Column(db.String(50), nullable=True) # LxWxH
    volume_m3 = db.Column(db.Float, nullable=True)
    qr_code_data = db.Column(db.Text, nullable=True)
    collected_at = db.Column(db.DateTime, nullable=True)
    
    payment_status = db.Column(db.String(20), default='UNPAID') # UNPAID, PAID
    cod_amount = db.Column(db.Float, default=0)
    
    # Office tracking
    sender_office_id = db.Column(db.Integer, db.ForeignKey('office.id'), nullable=True)
    receiver_office_id = db.Column(db.Integer, db.ForeignKey('office.id'), nullable=True)

    sender_office = db.relationship('Office', foreign_keys=[sender_office_id])
    receiver_office = db.relationship('Office', foreign_keys=[receiver_office_id])

    history = db.relationship('CargoHistory', backref='cargo', lazy=True)


class Review(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    booking_id = db.Column(db.Integer, db.ForeignKey('booking.id'), nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class RestStop(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    location = db.Column(db.String(200))
    image_url = db.Column(db.String(200)) # Placeholder for image
    items = db.relationship('MenuItem', backref='rest_stop', lazy=True)
    reviews = db.relationship('RestStopReview', backref='rest_stop', lazy=True)


class MenuItem(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    rest_stop_id = db.Column(db.Integer, db.ForeignKey('rest_stop.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    price = db.Column(db.Float, nullable=False)
    description = db.Column(db.String(200))
    image_url = db.Column(db.String(200))


class FoodOrder(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    booking_id = db.Column(db.Integer, db.ForeignKey('booking.id'), nullable=False)
    # JSON: {"Item Name": {"qty": 2, "price": 50000}}
    order_details = db.Column(db.Text, nullable=False) 
    total_price = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(20), default='Ordered')


class RestStopReview(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    booking_id = db.Column(db.Integer, db.ForeignKey('booking.id'), nullable=False)
    rest_stop_id = db.Column(db.Integer, db.ForeignKey('rest_stop.id'), nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class TransportOrder(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    uuid = db.Column(db.String(36), default=lambda: str(uuid.uuid4()), unique=True)
    trip_id = db.Column(db.Integer, db.ForeignKey('trip.id'), nullable=False)
    order_code = db.Column(db.String(20), unique=True, nullable=False)
    issued_at = db.Column(db.DateTime, default=datetime.utcnow)
    issued_by_id = db.Column(db.Integer, db.ForeignKey('staff.id'), nullable=False)
    status = db.Column(db.String(20), default='ACTIVE') # ACTIVE, COMPLETED, VOID
    notes = db.Column(db.Text)

class CargoHistory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    cargo_id = db.Column(db.Integer, db.ForeignKey('cargo.id'), nullable=False)
    status = db.Column(db.String(20), nullable=False)
    location = db.Column(db.String(100))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    updated_by_id = db.Column(db.Integer, db.ForeignKey('staff.id'), nullable=True)
    remarks = db.Column(db.Text)

class AuditLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, nullable=True) # Can be User, Company, or Staff ID
    user_type = db.Column(db.String(20)) # USER, COMPANY, STAFF
    table_name = db.Column(db.String(50), nullable=False)
    record_id = db.Column(db.Integer, nullable=False)
    action = db.Column(db.String(10), nullable=False) # CREATE, UPDATE, DELETE
    old_values = db.Column(db.Text) # JSON string
    new_values = db.Column(db.Text) # JSON string
    ip_address = db.Column(db.String(45))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class TripIncident(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    trip_id = db.Column(db.Integer, db.ForeignKey('trip.id'), nullable=False)
    staff_id = db.Column(db.Integer, db.ForeignKey('staff.id'), nullable=False)
    type = db.Column(db.String(50), nullable=False) # BREAKDOWN, ACCIDENT, DELAY, OTHER
    description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(200))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    status = db.Column(db.String(20), default='REPORTED') # REPORTED, RESOLVING, RESOLVED

class PassengerSOS(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    passenger_name = db.Column(db.String(100))
    passenger_phone = db.Column(db.String(20))
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    message = db.Column(db.Text)
    status = db.Column(db.String(20), default='PENDING') # PENDING, RESOLVED
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    resolved_at = db.Column(db.DateTime, nullable=True)
    resolved_by_id = db.Column(db.Integer, db.ForeignKey('staff.id'), nullable=True)

class Notification(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True) # null for broadcast
    type = db.Column(db.String(50), nullable=False, default='INFO') # SUCCESS, PROMO, REMINDER, SYSTEM
    title = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'type': self.type,
            'title': self.title,
            'message': self.message,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat() + 'Z' if self.created_at else None
        }
