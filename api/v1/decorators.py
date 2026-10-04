import os
from functools import wraps
from flask import request
import jwt
from models import User
from extensions import db
from .errors import api_error

def get_jwt_secret():
    return os.getenv('JWT_SECRET_KEY', 'local-dev-jwt-secret-key-12345')

def jwt_required():
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            auth_header = request.headers.get('Authorization')
            
            if not auth_header:
                return api_error(message="Missing Authorization Header", error_code="MISSING_AUTH_HEADER", status=401)
            
            parts = auth_header.split()
            if parts[0].lower() != 'bearer' or len(parts) != 2:
                return api_error(message="Invalid Authorization Header Format", error_code="INVALID_AUTH_HEADER", status=401)
            
            token = parts[1]
            try:
                # Add leeway=60 to handle clock skew (e.g. InvalidIssuedAtError if iat is slightly in the future)
                payload = jwt.decode(token, get_jwt_secret(), algorithms=['HS256'], leeway=60)
                
                if payload.get('type') != 'access':
                    return api_error(message="Invalid token type. Expected access token.", error_code="INVALID_TOKEN_TYPE", status=401)
                    
                user_id = payload.get('sub')
                if not user_id:
                    return api_error(message="Invalid token payload", error_code="INVALID_TOKEN", status=401)
                
                # Fetch user
                user = User.query.get(int(user_id))
                if not user:
                    return api_error(message="User not found", error_code="USER_NOT_FOUND", status=401)
                
                # Attach user to request context
                request.current_user = user
                
            except jwt.ExpiredSignatureError:
                return api_error(message="Token has expired", error_code="TOKEN_EXPIRED", status=401)
            except jwt.InvalidTokenError as e:
                import logging
                logging.exception("JWT verification failed: %s", type(e).__name__)
                return api_error(message=f"Invalid token: {type(e).__name__}", error_code="INVALID_TOKEN", status=401)
            except Exception as e:
                import logging
                logging.exception("JWT Unknown Error: %s", type(e).__name__)
                return api_error(message=str(e), error_code="UNKNOWN_ERROR", status=500)

            return f(*args, **kwargs)
        return decorated_function
    return decorator
