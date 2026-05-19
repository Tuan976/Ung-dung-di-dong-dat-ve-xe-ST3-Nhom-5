from app import app
from extensions import db
from models import Company, Route, Bus, Trip, User
from datetime import datetime, timedelta
import random
from werkzeug.security import generate_password_hash

def seed_data():
    with app.app_context():
        print("Starting mock data seeding...")
        
        # 1. Create 5 Companies
        companies_data = [
            {"name": "Minh An Express", "email": "minhan@bus.com"},
            {"name": "Hutech Luxury", "email": "hutech@bus.com"},
            {"name": "FUTA Bus Lines", "email": "futa@bus.com"},
            {"name": "Thanh Buoi", "email": "thanhbuoi@bus.com"},
            {"name": "Hoang Long", "email": "hoanglong@bus.com"}
        ]
        
        companies = []
        for c in companies_data:
            existing = Company.query.filter_by(email=c['email']).first()
            if not existing:
                company = Company(
                    name=c['name'],
                    email=c['email'],
                    password=generate_password_hash('123456'),
                    phone=f"09{random.randint(10000000, 99999999)}",
                    address="TP. Ho Chi Minh"
                )
                db.session.add(company)
                companies.append(company)
            else:
                companies.append(existing)
        
        db.session.commit()
        print(f"Created/Verified {len(companies)} companies.")

        # 2. Create Routes
        provinces = ["TP. Hồ Chí Minh", "Đà Lạt", "Đà Nẵng", "Hà Nội", "Cần Thơ", "Cư Jut", "Nha Trang"]
        
        routes = []
        for i in range(len(provinces)):
            for j in range(len(provinces)):
                if i != j:
                    company = random.choice(companies)
                    existing = Route.query.filter_by(start_point=provinces[i], end_point=provinces[j], company_id=company.id).first()
                    if not existing:
                        route = Route(
                            company_id=company.id,
                            start_point=provinces[i],
                            end_point=provinces[j],
                            base_price=random.choice([200000, 250000, 300000, 450000, 600000]),
                            distance_km=random.randint(200, 1500),
                            duration_hours=random.randint(4, 20)
                        )
                        db.session.add(route)
                        routes.append(route)
                    else:
                        routes.append(existing)
        
        db.session.commit()
        print(f"Created/Verified {len(routes)} routes.")

        # 3. Create Buses
        bus_types = ['Sleeper', 'Limousine', 'VIP 34', 'Seat']
        buses = []
        for company in companies:
            # Check if company already has buses
            existing_buses = Bus.query.filter_by(company_id=company.id).count()
            if existing_buses < 5:
                for i in range(5 - existing_buses):
                    bus = Bus(
                        company_id=company.id,
                        license_plate=f"{random.randint(10, 99)}B-{random.randint(1000, 9999)}",
                        bus_type=random.choice(bus_types),
                        total_seats=random.choice([22, 34, 40]),
                        seat_map="[]"
                    )
                    db.session.add(bus)
                    buses.append(bus)
        
        db.session.commit()
        all_buses = Bus.query.all()
        print(f"Total buses in DB: {len(all_buses)}.")

        # 4. Create Trips
        now = datetime.now()
        trips_count = 0
        all_routes = Route.query.all()
        for route in all_routes:
            company_buses = Bus.query.filter_by(company_id=route.company_id).all()
            if not company_buses: continue
            
            # Check if trips already exist for this route today
            today = now.date()
            existing_trips = Trip.query.filter(Trip.route_id == route.id, db.func.date(Trip.departure_time) == today).count()
            
            if existing_trips == 0:
                for day in range(8):
                    departure_date = now + timedelta(days=day)
                    for hour in [8, 14, 20]:
                        departure_time = departure_date.replace(hour=hour, minute=random.choice([0, 15, 30, 45]), second=0)
                        trip = Trip(
                            route_id=route.id,
                            bus_id=random.choice(company_buses).id,
                            departure_time=departure_time,
                            status='Scheduled',
                            price_multiplier=random.choice([1.0, 1.1, 1.2])
                        )
                        db.session.add(trip)
                        trips_count += 1
        
        db.session.commit()
        print(f"Added {trips_count} new trips.")
        print("Mock data seeding completed!")

if __name__ == "__main__":
    seed_data()
