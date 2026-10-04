from flask import jsonify

def api_success(data=None, message="OK", status=200):
    response = {
        "success": True,
        "message": message,
        "data": data if data is not None else {}
    }
    return jsonify(response), status

def api_error(message="Đã có lỗi xảy ra", error_code="UNKNOWN_ERROR", status=400, errors=None):
    response = {
        "success": False,
        "message": message,
        "error": {
            "code": error_code
        }
    }
    if errors:
        response["errors"] = errors
    return jsonify(response), status

from . import api_v1_bp

@api_v1_bp.errorhandler(400)
def bad_request(e):
    return api_error(message="Bad Request", error_code="BAD_REQUEST", status=400)

@api_v1_bp.errorhandler(401)
def unauthorized(e):
    return api_error(message="Unauthorized", error_code="UNAUTHORIZED", status=401)

@api_v1_bp.errorhandler(403)
def forbidden(e):
    return api_error(message="Forbidden", error_code="FORBIDDEN", status=403)

@api_v1_bp.errorhandler(404)
def not_found(e):
    return api_error(message="Not Found", error_code="NOT_FOUND", status=404)

@api_v1_bp.errorhandler(422)
def unprocessable_entity(e):
    return api_error(message="Unprocessable Entity", error_code="UNPROCESSABLE_ENTITY", status=422)

@api_v1_bp.errorhandler(500)
def internal_server_error(e):
    return api_error(message="Internal Server Error", error_code="INTERNAL_SERVER_ERROR", status=500)
