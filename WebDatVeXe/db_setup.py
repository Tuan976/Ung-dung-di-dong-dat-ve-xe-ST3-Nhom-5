import os

from sqlalchemy import text

from extensions import db


def init_database(app):
    os.makedirs(os.path.join(app.root_path, app.config['UPLOAD_FOLDER']), exist_ok=True)
    with app.app_context():
        db.create_all()

        try:
            with db.engine.connect() as conn:
                conn.execute(text("ALTER TABLE trip ADD COLUMN driver_id INTEGER REFERENCES driver(id)"))
                conn.execute(text("ALTER TABLE trip ADD COLUMN assistant_id INTEGER REFERENCES assistant(id)"))
                conn.commit()
        except Exception:
            pass

        try:
            with db.engine.connect() as conn:
                conn.execute(text("ALTER TABLE menu_item ADD COLUMN image_url VARCHAR(200)"))
                conn.commit()
        except Exception:
            pass

        try:
            with db.engine.connect() as conn:
                conn.execute(text("ALTER TABLE booking ADD COLUMN payment_id VARCHAR(50)"))
                conn.commit()
        except Exception:
            pass
