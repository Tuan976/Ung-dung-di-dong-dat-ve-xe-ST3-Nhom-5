from flask_mail import Mail
from flask_sqlalchemy import SQLAlchemy
from flask_socketio import SocketIO
from itsdangerous import URLSafeTimedSerializer
from payos import PayOS


db = SQLAlchemy()
mail = Mail()
socketio = SocketIO(cors_allowed_origins="*", async_mode='threading')
payos_client = None
serializer = None


def init_extensions(app):
    global payos_client, serializer
    db.init_app(app)
    mail.init_app(app)
    socketio.init_app(app)
    serializer = URLSafeTimedSerializer(app.config['SECRET_KEY'])

    client_id = app.config.get('PAYOS_CLIENT_ID')
    api_key = app.config.get('PAYOS_API_KEY')
    checksum_key = app.config.get('PAYOS_CHECKSUM_KEY')

    if client_id and api_key and checksum_key:
        payos_client = PayOS(
            client_id=client_id,
            api_key=api_key,
            checksum_key=checksum_key,
        )
    else:
        payos_client = None
