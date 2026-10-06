import os
from flask import Flask, send_from_directory, jsonify, request, session
from flask_cors import CORS
from extensions import db, mail, socketio, init_extensions
from db_setup import init_database
from dotenv import load_dotenv

# Tải cấu hình từ file .env
load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# --- HÀM TỰ ĐỘNG TÌM ĐƯỜNG DẪN CHÍNH XÁC ---
def find_path(folder_name):
    path = os.path.join(BASE_DIR, folder_name)
    if os.path.exists(path): return path
    path = os.path.join(BASE_DIR, 'WebDatVeXe', folder_name)
    if os.path.exists(path): return path
    return os.path.join(BASE_DIR, folder_name)

static_dir = find_path('static')
template_dir = find_path('templates')

app = Flask(__name__, 
            static_folder=static_dir, 
            static_url_path='/static', 
            template_folder=template_dir)

# --- TEST CỰC MẠNH: ĐẶT NGAY ĐẦU APP ---
@app.route('/api/test-now')
def test_now():
    return jsonify({'message': 'Day dung la file app.py chung ta dang sua!', 'path': __file__})

# Cấu hình CORS chuẩn: Cho phép tất cả để test local không bị chặn
CORS(app, resources={r"/api/*": {"origins": "*"}}, supports_credentials=False)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-key-123')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('SQLALCHEMY_DATABASE_URI', 'sqlite:///bus_booking.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = os.getenv('UPLOAD_FOLDER', 'static/uploads')

# Cấu hình Email & PayOS
app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
app.config['MAIL_PORT'] = int(os.getenv('MAIL_PORT', 587))
app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS', 'True') == 'True'
app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD')
app.config['MAIL_DEFAULT_SENDER'] = (os.getenv('MAIL_DEFAULT_SENDER_NAME', 'HUTECH BUS'), os.getenv('MAIL_DEFAULT_SENDER_EMAIL'))
app.config['PAYOS_CLIENT_ID'] = os.getenv('PAYOS_CLIENT_ID')
app.config['PAYOS_API_KEY'] = os.getenv('PAYOS_API_KEY')
app.config['PAYOS_CHECKSUM_KEY'] = os.getenv('PAYOS_CHECKSUM_KEY')

init_extensions(app)
init_database(app)

# Helper cho Jinja2
from helpers import from_json, timedelta_hours_jinja
app.add_template_filter(from_json, 'from_json')
app.add_template_filter(timedelta_hours_jinja, 'timedelta_hours')

# --- Khởi tạo Firebase Admin SDK ---
try:
    import firebase_admin
    from firebase_admin import credentials
    firebase_cred_path = os.path.join(BASE_DIR, 'firebase-adminsdk.json')
    if os.path.exists(firebase_cred_path):
        cred = credentials.Certificate(firebase_cred_path)
        firebase_admin.initialize_app(cred)
        print("Firebase Admin SDK initialized successfully.")
    else:
        print("WARNING: firebase-adminsdk.json not found! FCM notifications will not work.")
except Exception as e:
    print(f"Failed to initialize Firebase Admin: {e}")

# React assets will be served via the 404 handler in routes_public.py

@app.route('/api/ai/chatbot', methods=['GET', 'POST'])
def ai_chatbot_direct():
    if request.method == 'GET':
        return jsonify({'status': 'API Chatbot is active'})
    from ai_service import ai_service
    from routes_ai import _get_ai_state, _get_known_locations, _resolve_trip_selection, _default_ai_state, _save_ai_state, _search_trips
    data = request.json or {}
    message = (data.get('message') or '').strip()
    state = _get_ai_state()
    known_locations = _get_known_locations()
    parsed = ai_service.parse_message(message, state, known_locations)
    if parsed['reset']:
        state = _default_ai_state()
        _save_ai_state(state)
        return jsonify({'response': 'Dạ em đã xoá thông tin tìm chuyến trước đó.'})
    state, _ = ai_service.merge_state(state, parsed['slots'])
    if not ai_service.booking_ready(state):
        return jsonify({'response': ai_service.next_question(state)})
    options, alt = _search_trips(state, limit=5)
    return jsonify({'response': ai_service.format_trip_options(state, options) if options else 'Không có chuyến'})

# Đăng ký các Route khác
from routes_public import register_public_routes
from routes_auth import register_auth_routes
from routes_admin import register_admin_routes
from routes_ops import register_ops_routes
from routes_driver import register_driver_routes
from routes_booking import register_booking_routes
from routes_ai import register_ai_routes

register_auth_routes(app)
register_admin_routes(app)
register_ops_routes(app)
register_driver_routes(app)
register_booking_routes(app)
register_ai_routes(app)
register_public_routes(app)

# --- Register New Mobile API Blueprint ---
from api.v1 import api_v1_bp
app.register_blueprint(api_v1_bp)

if __name__ == '__main__':
    socketio.run(app, debug=True, use_reloader=False, host='0.0.0.0', port=5000, allow_unsafe_werkzeug=True)
