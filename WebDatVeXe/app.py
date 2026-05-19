from dotenv import load_dotenv
import os

from flask import Flask

from helpers import from_json, timedelta_hours_jinja
from db_setup import init_database
from extensions import init_extensions


load_dotenv()

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('SQLALCHEMY_DATABASE_URI', 'sqlite:///bus_booking.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = os.getenv('UPLOAD_FOLDER', 'static/uploads/food')

# Secrets/config from .env only
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
app.config['MAIL_PORT'] = int(os.getenv('MAIL_PORT', '587'))
app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS', 'True').lower() == 'true'
app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD')
app.config['MAIL_DEFAULT_SENDER'] = (
    os.getenv('MAIL_DEFAULT_SENDER_NAME', 'HUTECH BUS'),
    os.getenv('MAIL_DEFAULT_SENDER_EMAIL') or os.getenv('MAIL_USERNAME'),
)

app.config['PAYOS_CLIENT_ID'] = os.getenv('PAYOS_CLIENT_ID')
app.config['PAYOS_API_KEY'] = os.getenv('PAYOS_API_KEY')
app.config['PAYOS_CHECKSUM_KEY'] = os.getenv('PAYOS_CHECKSUM_KEY')

required_env = ['SECRET_KEY']
missing_required_env = [name for name in required_env if not os.getenv(name)]
if missing_required_env:
    raise RuntimeError(
        'Thiếu biến môi trường bắt buộc trong file .env: ' + ', '.join(missing_required_env)
    )

init_extensions(app)
app.add_template_filter(from_json, 'from_json')
app.add_template_filter(timedelta_hours_jinja, 'timedelta_hours')

from routes_admin import register_admin_routes
from routes_ai import register_ai_routes
from routes_auth import register_auth_routes
from routes_booking import register_booking_routes
from routes_public import register_public_routes

register_auth_routes(app)
register_public_routes(app)
register_admin_routes(app)
register_booking_routes(app)
register_ai_routes(app)
init_database(app)


if __name__ == '__main__':
    app.run(debug=True, port=5000)
