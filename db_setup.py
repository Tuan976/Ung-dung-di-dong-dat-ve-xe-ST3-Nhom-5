import os
from sqlalchemy import text
from extensions import db

def init_database(app):
    try:
        os.makedirs(os.path.join(app.root_path, app.config.get('UPLOAD_FOLDER', 'static/uploads')), exist_ok=True)
    except Exception as e:
        print(f"Warning: Could not create upload folder: {e}")

    with app.app_context():
        db.create_all()

        # Danh sách tất cả các câu lệnh nâng cấp bảng
        upgrades = [
            "ALTER TABLE trip ADD COLUMN driver_id INTEGER REFERENCES driver(id)",
            "ALTER TABLE trip ADD COLUMN assistant_id INTEGER REFERENCES assistant(id)",
            "ALTER TABLE trip ADD COLUMN actual_departure DATETIME",
            "ALTER TABLE trip ADD COLUMN actual_arrival DATETIME",
            "ALTER TABLE trip ADD COLUMN delay_minutes INTEGER DEFAULT 0",
            "ALTER TABLE trip ADD COLUMN cancellation_reason TEXT",
            "ALTER TABLE trip ADD COLUMN canceled_at DATETIME",
            "ALTER TABLE trip ADD COLUMN canceled_by_id INTEGER REFERENCES staff(id)",
            "ALTER TABLE trip ADD COLUMN price_multiplier REAL DEFAULT 1.0",
            
            "ALTER TABLE booking ADD COLUMN payment_id VARCHAR(50)",
            "ALTER TABLE booking ADD COLUMN boarding_status TEXT DEFAULT 'NOT_BOARDED'",
            "ALTER TABLE booking ADD COLUMN check_in_time DATETIME",
            "ALTER TABLE booking ADD COLUMN checked_in_by_id INTEGER REFERENCES staff(id)",
            
            "ALTER TABLE menu_item ADD COLUMN image_url VARCHAR(200)",
            "ALTER TABLE cargo ADD COLUMN company_id INTEGER REFERENCES company(id)",
            "ALTER TABLE cargo ADD COLUMN sender_office_id INTEGER REFERENCES office(id)",
            "ALTER TABLE cargo ADD COLUMN receiver_office_id INTEGER REFERENCES office(id)",
            "ALTER TABLE cargo ADD COLUMN payment_status TEXT DEFAULT 'UNPAID'",
            "ALTER TABLE cargo ADD COLUMN cod_amount REAL DEFAULT 0",
            "ALTER TABLE staff ADD COLUMN status TEXT DEFAULT 'Active'",
            "ALTER TABLE driver ADD COLUMN status TEXT DEFAULT 'Active'",
            "ALTER TABLE driver ADD COLUMN joined_at DATETIME",
            "ALTER TABLE assistant ADD COLUMN status TEXT DEFAULT 'Active'",
            "ALTER TABLE assistant ADD COLUMN joined_at DATETIME"
        ]

        try:
            with db.engine.begin() as conn:
                for cmd in upgrades:
                    try:
                        conn.execute(text(cmd))
                    except Exception:
                        pass
        except Exception:
            pass
