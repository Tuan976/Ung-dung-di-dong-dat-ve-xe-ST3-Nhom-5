import os
import datetime
import jwt
import secrets
from flask import request
from werkzeug.security import check_password_hash, generate_password_hash
from models import User
from extensions import db

from . import api_v1_bp
from .errors import api_success, api_error
from .decorators import jwt_required, get_jwt_secret

# In-memory store for password reset tokens (production: use Redis/DB)
_reset_tokens = {}  # token -> {user_id, expires_at}


def _generate_access_token(user):
    expires_in = int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', 2592000))
    expiration = datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)
    payload = {
        'sub': str(user.id),
        'email': user.email,
        'type': 'access',
        'iat': datetime.datetime.utcnow(),
        'exp': expiration
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm='HS256'), expires_in

def _generate_refresh_token(user):
    expires_in = 365 * 24 * 3600  # 365 days
    expiration = datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)
    payload = {
        'sub': str(user.id),
        'type': 'refresh',
        'iat': datetime.datetime.utcnow(),
        'exp': expiration
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm='HS256')


@api_v1_bp.route('/auth/login', methods=['POST'])
def login():
    data = request.json or {}
    identifier = data.get('email') or data.get('phone')
    password = data.get('password')

    if not identifier or not password:
        return api_error(message="Vui lòng cung cấp thông tin đăng nhập", error_code="MISSING_CREDENTIALS", status=400)

    # Allow login by email or phone
    user = User.query.filter_by(email=identifier).first()
    if not user:
        user = User.query.filter_by(phone=identifier).first()

    if not user or not check_password_hash(user.password, password):
        return api_error(message="Thông tin đăng nhập không chính xác", error_code="INVALID_CREDENTIALS", status=401)

    access_token, expires_in = _generate_access_token(user)
    refresh_token = _generate_refresh_token(user)
    return api_success(
        message="Đăng nhập thành công",
        data={
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "Bearer",
            "expires_in": expires_in,
            "user": {"id": user.id, "name": user.name, "email": user.email, "phone": user.phone}
        }
    )


@api_v1_bp.route('/auth/register', methods=['POST'])
def register():
    data = request.json or {}
    name = data.get('name')
    email = data.get('email')
    password = data.get('password')
    phone = data.get('phone')

    errors = {}
    if not name: errors['name'] = 'Tên không được để trống'
    if not email: errors['email'] = 'Email không được để trống'
    if not password: errors['password'] = 'Mật khẩu không được để trống'

    if errors:
        return api_error(message="Dữ liệu không hợp lệ", error_code="VALIDATION_ERROR", status=422, errors=errors)

    if User.query.filter_by(email=email).first():
        return api_error(message="Email này đã được đăng ký", error_code="EMAIL_EXISTS", status=409)

    new_user = User(
        name=name,
        email=email,
        password=generate_password_hash(password),
        phone=phone
    )
    db.session.add(new_user)
    db.session.commit()

    return api_success(message="Đăng ký thành công", status=201)


@api_v1_bp.route('/auth/me', methods=['GET'])
@jwt_required()
def me():
    user = request.current_user
    return api_success(
        message="Lấy thông tin thành công",
        data={"user": {"id": user.id, "name": user.name, "email": user.email, "phone": user.phone}}
    )


@api_v1_bp.route('/auth/forgot-password', methods=['POST'])
def forgot_password():
    data = request.json or {}
    email = data.get('email', '').strip().lower()

    if not email:
        return api_error(message="Vui lòng cung cấp email", error_code="MISSING_EMAIL", status=400)

    user = User.query.filter_by(email=email).first()
    # Always return success to prevent email enumeration
    if not user:
        return api_success(message="Nếu email tồn tại, hướng dẫn đặt lại mật khẩu đã được gửi.")

    # Generate reset token (valid 30 minutes)
    token = secrets.token_urlsafe(32)
    expires_at = datetime.datetime.utcnow() + datetime.timedelta(minutes=30)
    _reset_tokens[token] = {'user_id': user.id, 'expires_at': expires_at}

    # Send email
    try:
        from flask_mail import Message
        from extensions import mail
        reset_link = f"{os.getenv('DOMAIN', 'http://127.0.0.1:5000')}/reset-password?token={token}"
        msg = Message(
            subject="Đặt lại mật khẩu VéXe",
            recipients=[user.email],
            html=f"""
            <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;">
              <h2 style="color:#0B192C;">Đặt lại mật khẩu</h2>
              <p>Xin chào <b>{user.name}</b>,</p>
              <p>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản của bạn.</p>
              <p>Mã xác nhận của bạn: <b style="font-size:24px;letter-spacing:4px;color:#0B192C;">{token[:6].upper()}</b></p>
              <p style="color:#94A3B8;font-size:12px;">Mã có hiệu lực trong 30 phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.</p>
            </div>
            """
        )
        mail.send(msg)
    except Exception as e:
        import logging
        logging.warning(f"Failed to send reset email: {e}")

    return api_success(message="Hướng dẫn đặt lại mật khẩu đã được gửi tới email của bạn.")


@api_v1_bp.route('/auth/reset-password', methods=['POST'])
def reset_password():
    data = request.json or {}
    token = data.get('token', '').strip()
    new_password = data.get('password', '')

    if not token or not new_password:
        return api_error(message="Thiếu thông tin", error_code="MISSING_DATA", status=400)

    if len(new_password) < 6:
        return api_error(message="Mật khẩu tối thiểu 6 ký tự", error_code="WEAK_PASSWORD", status=400)

    # Check token (support full token or 6-char code)
    record = None
    if token in _reset_tokens:
        record = _reset_tokens[token]
        token_key = token
    else:
        # Match by 6-char prefix
        for k, v in _reset_tokens.items():
            if k[:6].upper() == token.upper():
                record = v
                token_key = k
                break

    if not record:
        return api_error(message="Mã xác nhận không hợp lệ", error_code="INVALID_TOKEN", status=400)

    if datetime.datetime.utcnow() > record['expires_at']:
        _reset_tokens.pop(token_key, None)
        return api_error(message="Mã xác nhận đã hết hạn", error_code="TOKEN_EXPIRED", status=400)

    user = User.query.get(record['user_id'])
    if not user:
        return api_error(message="Người dùng không tồn tại", error_code="USER_NOT_FOUND", status=404)

    user.password = generate_password_hash(new_password)
    db.session.commit()
    _reset_tokens.pop(token_key, None)

    return api_success(message="Đặt lại mật khẩu thành công! Vui lòng đăng nhập.")


@api_v1_bp.route('/auth/google', methods=['POST'])
def google_login():
    """Login/Register with Google ID Token."""
    data = request.json or {}
    id_token_str = data.get('id_token') or data.get('access_token')
    google_id = data.get('google_id')
    name = data.get('name', '')
    email = data.get('email', '')
    photo = data.get('photo', '')

    if not email:
        return api_error(message="Thiếu thông tin từ Google", error_code="MISSING_GOOGLE_DATA", status=400)

    # Find or create user
    user = User.query.filter_by(email=email).first()
    if not user:
        user = User(
            name=name or email.split('@')[0],
            email=email,
            password=generate_password_hash(secrets.token_hex(16)),  # Random password
            phone='',
        )
        db.session.add(user)
        db.session.commit()

    access_token, expires_in = _generate_access_token(user)
    refresh_token = _generate_refresh_token(user)
    return api_success(
        message="Đăng nhập Google thành công",
        data={
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "Bearer",
            "expires_in": expires_in,
            "user": {"id": user.id, "name": user.name, "email": user.email, "phone": user.phone or ""}
        }
    )

@api_v1_bp.route('/auth/refresh', methods=['POST'])
def refresh():
    auth_header = request.headers.get('Authorization')
    refresh_token = None
    
    if auth_header:
        parts = auth_header.split()
        if len(parts) == 2 and parts[0].lower() == 'bearer':
            refresh_token = parts[1]
            
    if not refresh_token:
        data = request.json or {}
        refresh_token = data.get('refresh_token')
        
    if not refresh_token:
        return api_error(message="Missing Refresh Token", error_code="MISSING_TOKEN", status=401)
        
    try:
        payload = jwt.decode(refresh_token, get_jwt_secret(), algorithms=['HS256'], leeway=60)
        
        if payload.get('type') != 'refresh':
            return api_error(message="Invalid token type", error_code="INVALID_TOKEN_TYPE", status=401)
            
        user_id = payload.get('sub')
        if not user_id:
            return api_error(message="Invalid token payload", error_code="INVALID_TOKEN", status=401)
            
        user = User.query.get(int(user_id))
        if not user:
            return api_error(message="User not found", error_code="USER_NOT_FOUND", status=401)
            
        access_token, expires_in = _generate_access_token(user)
        return api_success(
            message="Refresh token thành công",
            data={
                "access_token": access_token,
                "expires_in": expires_in
            }
        )
        
    except jwt.ExpiredSignatureError:
        return api_error(message="Refresh token has expired", error_code="TOKEN_EXPIRED", status=401)
    except jwt.InvalidTokenError as e:
        import logging
        logging.exception("Refresh token verification failed: %s", type(e).__name__)
        return api_error(message=f"Invalid refresh token: {type(e).__name__}", error_code="INVALID_TOKEN", status=401)
    except Exception as e:
        import logging
        logging.exception("Refresh token Unknown Error: %s", type(e).__name__)
        return api_error(message=str(e), error_code="UNKNOWN_ERROR", status=500)
