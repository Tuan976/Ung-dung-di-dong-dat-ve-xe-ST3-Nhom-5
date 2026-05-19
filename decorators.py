import functools

from flask import flash, redirect, session, url_for


def _redirect_company_login():
    flash('Vui lòng đăng nhập!')
    return redirect(url_for('company_login'))


def _redirect_admin_dashboard(message):
    flash(message)
    return redirect(url_for('admin'))


def passenger_login_required(f):
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Vui lòng đăng nhập tài khoản hành khách!')
            return redirect(url_for('passenger_login'))
        return f(*args, **kwargs)
    return decorated_function


def company_login_required(f):
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        from flask import request, jsonify
        if 'company_id' not in session:
            if request.is_json or request.path.startswith('/api/'):
                return jsonify({'error': 'Unauthorized'}), 401
            return _redirect_company_login()
        return f(*args, **kwargs)
    return decorated_function


def admin_only(f):
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        from flask import request, jsonify
        if 'company_id' not in session:
            if request.is_json or request.path.startswith('/api/'):
                return jsonify({'error': 'Unauthorized'}), 401
            return _redirect_company_login()
        if session.get('role') != 'ADMIN':
            if request.is_json or request.path.startswith('/api/'):
                return jsonify({'error': 'Forbidden'}), 403
            return _redirect_admin_dashboard('Quyền hạn này chỉ dành cho quản trị viên!')
        return f(*args, **kwargs)
    return decorated_function


def staff_role_required(*allowed_staff_roles, allow_admin=True):
    """
    Cho phép ADMIN và/hoặc STAFF theo loại vai trò chi tiết.
    Ví dụ:
        staff_role_required('STATION_STAFF')(view_func)
        staff_role_required('STATION_STAFF', 'TICKET_OFFICE')(view_func)
    """
    allowed_staff_roles = {role.upper() for role in allowed_staff_roles}

    def decorator(f):
        @functools.wraps(f)
        def decorated_function(*args, **kwargs):
            if 'company_id' not in session:
                return _redirect_company_login()

            current_role = session.get('role')
            current_staff_role = (session.get('staff_role') or '').upper()

            if current_role == 'ADMIN' and allow_admin:
                return f(*args, **kwargs)

            if current_role != 'STAFF':
                return _redirect_admin_dashboard('Bạn không có quyền truy cập chức năng này!')

            if allowed_staff_roles and current_staff_role not in allowed_staff_roles:
                return _redirect_admin_dashboard('Bạn không có quyền truy cập chức năng này!')

            return f(*args, **kwargs)
        return decorated_function
    return decorator


def driver_required(f):
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        if 'company_id' not in session:
            return redirect(url_for('company_login'))
        if session.get('staff_role') != 'DRIVER' and session.get('role') != 'ADMIN':
            flash('Chức năng này chỉ dành cho tài xế!')
            return redirect(url_for('admin'))
        return f(*args, **kwargs)
    return decorated_function


def assistant_required(f):
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        if 'company_id' not in session:
            return redirect(url_for('company_login'))
        if session.get('staff_role') != 'ASSISTANT' and session.get('role') != 'ADMIN':
            flash('Chức năng này chỉ dành cho phụ xe!')
            return redirect(url_for('admin'))
        return f(*args, **kwargs)
    return decorated_function
