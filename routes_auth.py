import random
import string
import time

from flask import flash, jsonify, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash
from flask_mail import Message

from decorators import admin_only, company_login_required
from extensions import db, mail
from models import Booking, Company, Staff, User

otp_store = {}

def register_auth_routes(app):
    def passenger_register():
        if request.method == 'POST':
            name = request.form.get('name')
            email = request.form.get('email')
            password = request.form.get('password')
            phone = request.form.get('phone')
        
            if User.query.filter_by(email=email).first():
                flash('Email này đã được đăng ký!')
                return redirect(url_for('passenger_register'))
            
            new_user = User(name=name, email=email, password=generate_password_hash(password), phone=phone)
            db.session.add(new_user)
            db.session.commit()
            flash('Đăng ký hành khách thành công! Vui lòng đăng nhập.')
            return redirect(url_for('passenger_login'))
        return render_template('auth/passenger_register.html')

    def passenger_login():
        if request.method == 'POST':
            email = request.form.get('email')
            password = request.form.get('password')
            user = User.query.filter_by(email=email).first()
            if user and check_password_hash(user.password, password):
                session['user_id'] = user.id
                session['user_name'] = user.name
                session['role'] = 'passenger'
                flash(f'Chào mừng {user.name} đã quay lại!')
                return redirect(url_for('index'))
            flash('Email hoặc mật khẩu không chính xác!')
        return render_template('auth/passenger_login.html')

    def company_register():
        if request.method == 'POST':
            name = request.form.get('name')
            email = request.form.get('email')
            password = request.form.get('password')
            phone = request.form.get('phone')
            address = request.form.get('address')
        
            if Company.query.filter_by(email=email).first():
                flash('Email nhà xe này đã được đăng ký!')
                return redirect(url_for('company_register'))
            
            new_company = Company(name=name, email=email, password=generate_password_hash(password), 
                                  phone=phone, address=address)
            db.session.add(new_company)
            db.session.commit()
            flash('Đăng ký nhà xe thành công! Vui lòng đăng nhập.')
            return redirect(url_for('company_login'))
        return render_template('auth/company_register.html')

    def company_login():
        if request.method == 'POST':
            email = request.form.get('email')
            password = request.form.get('password')
            company = Company.query.filter_by(email=email).first()
            if company and check_password_hash(company.password, password):
                session['company_id'] = company.id
                session['company_name'] = company.name
                session['role'] = 'ADMIN'
                flash(f'Chào mừng nhà xe {company.name} (Quản trị viên)!')
                return redirect(url_for('admin'))
            flash('Email hoặc mật khẩu không chính xác!')
        return render_template('auth/company_login.html')

    def staff_login():
        if request.method == 'POST':
            email = request.form.get('email')
            password = request.form.get('password')
            staff = Staff.query.filter_by(email=email).first()
            if staff and check_password_hash(staff.password, password):
                session['company_id'] = staff.company_id
                session['staff_id'] = staff.id
                session['company_name'] = staff.company.name
                session['user_name'] = staff.name
                session['role'] = 'STAFF'
                session['staff_role'] = (staff.role or 'STATION_STAFF').upper()
                role_label = 'Nhân viên trạm / kiểm soát' if session['staff_role'] == 'STATION_STAFF' else 'Nhân viên phòng vé / đặt giữ chỗ'
                flash(f'Chào mừng nhân viên {staff.name}! ({role_label})')
                return redirect(url_for('admin'))
            flash('Email hoặc mật khẩu không chính xác!')
        return render_template('auth/staff_login.html')

    def admin_staff_accounts():
        company_id = session['company_id']
        if request.method == 'POST':
            name = request.form.get('name')
            email = request.form.get('email')
            password = request.form.get('password')
            phone = request.form.get('phone')
            role = (request.form.get('role', 'STATION_STAFF') or 'STATION_STAFF').upper()
            allowed_staff_roles = {'STATION_STAFF', 'TICKET_OFFICE'}

            if role not in allowed_staff_roles:
                flash('Vai trò nhân viên không hợp lệ!')
                return redirect(url_for('admin_staff_accounts'))

            if Staff.query.filter_by(email=email).first():
                flash('Email này đã được sử dụng!')
            else:
                new_staff = Staff(company_id=company_id, name=name, email=email, 
                                  password=generate_password_hash(password), phone=phone, role=role)
                db.session.add(new_staff)
                db.session.commit()
                flash('Đã tạo tài khoản nhân viên thành công!')
            
        staff_members = Staff.query.filter_by(company_id=company_id).all()
        return render_template('admin/staff_accounts.html', staff_members=staff_members, active_page='staff_accounts')


    def admin_check_ticket():
        booking = None
        search_code = request.args.get('ticket_id') or request.form.get('ticket_id')

        if search_code:
            booking = Booking.query.filter_by(ticket_code=search_code.upper()).first()
            if not booking and search_code.isdigit():
                booking = Booking.query.get(int(search_code))

            if booking:
                if booking.trip.route.company_id != session['company_id']:
                    booking = None
                    flash('Không tìm thấy vé hoặc vé không thuộc nhà xe này!')
            else:
                flash('Mã vé không tồn tại!')

        return render_template('admin/check_ticket.html', booking=booking, active_page='check_ticket')

    def admin_logout():
        session.clear()
        flash('Đã đăng xuất thành công.')
        return redirect(url_for('company_login'))

    app.add_url_rule('/admin/logout', view_func=admin_logout)

    def forgot_password():
        if request.method == 'POST':
            role = request.form.get('role')
            email = request.form.get('email')
        
            user = None
            if role == 'passenger':
                user = User.query.filter_by(email=email).first()
            elif role == 'company':
                user = Company.query.filter_by(email=email).first()
            
            if user:
                # Generate OTP
                otp = ''.join(random.choices(string.digits, k=6))
            
                # Store in Session (Expires in 5 mins)
                session['reset_email'] = email
                session['reset_role'] = role
                session['reset_otp'] = otp
                session['reset_expiry'] = time.time() + 300 # 5 minutes
            
                msg = Message('Mã xác thực OTP - HUTECH BUS', recipients=[email])
                msg.body = f'Xin chào {user.name},\n\nMã xác thực (OTP) để đặt lại mật khẩu của bạn là: {otp}\n\nMã này sẽ hết hạn sau 5 phút. Vui lòng không chia sẻ cho bất kỳ ai.'
            
                # HTML Email Template
                msg.html = f"""
                <div style="font-family: 'Helvetica', 'Arial', sans-serif; max-width: 600px; margin: 0 auto; background-color: #F9F6F2; padding: 40px; border-radius: 16px;">
                    <div style="text-align: center; margin-bottom: 30px;">
                        <h2 style="color: #B8641A; margin: 0; font-size: 28px; font-weight: 800; letter-spacing: -1px;">HUTECH BUS</h2>
                    </div>
                
                    <div style="background-color: #FFFFFF; padding: 40px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
                        <p style="color: #6B5D4F; font-size: 16px; margin-top: 0;">Xin chào <strong>{user.name}</strong>,</p>
                    
                        <p style="color: #6B5D4F; font-size: 16px; line-height: 1.6;">
                            Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản HUTECH Bus. 
                            Sử dụng mã OTP dưới đây để hoàn tất quá trình xác thực:
                        </p>
                    
                        <div style="text-align: center; margin: 32px 0;">
                            <span style="display: inline-block; background-color: #FFF0E6; color: #B8641A; font-size: 32px; font-weight: 700; padding: 16px 32px; border-radius: 8px; letter-spacing: 8px; border: 1px dashed #B8641A;">
                                {otp}
                            </span>
                        </div>
                    
                        <p style="color: #6B5D4F; font-size: 14px; text-align: center;">
                            Mã này sẽ hết hạn sau <strong>5 phút</strong>.
                        </p>
                    
                        <div style="border-top: 1px solid #E8DCC8; margin-top: 32px; padding-top: 24px; text-align: center;">
                            <p style="color: #999; font-size: 12px; margin: 0;">
                                Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email hoặc liên hệ bộ phận hỗ trợ.
                            </p>
                        </div>
                    </div>
                
                    <div style="text-align: center; margin-top: 24px; color: #999; font-size: 12px;">
                        &copy; 2026 HUTECH BUS Transport Service.
                    </div>
                </div>
                """
                try:
                    mail.send(msg)
                    flash('Mã OTP đã được gửi đến email của bạn!')
                    return redirect(url_for('verify_otp'))
                except Exception as e:
                    flash(f'Lỗi gửi email: {str(e)}')
            else:
                flash('Email không tồn tại trong hệ thống!')
            
        return render_template('auth/forgot_password.html')

    def verify_otp():
        if 'reset_email' not in session:
            return redirect(url_for('forgot_password'))
        
        if request.method == 'POST':
            input_otp = request.form.get('otp')
        
            if time.time() > session.get('reset_expiry', 0):
                flash('Mã OTP đã hết hạn! Vui lòng thử lại.')
                return redirect(url_for('forgot_password'))
            
            if input_otp == session.get('reset_otp'):
                session['reset_verified'] = True
                return redirect(url_for('reset_new_password'))
            else:
                flash('Mã OTP không chính xác!')
            
        return render_template('auth/verify_otp.html', email=session['reset_email'])

    def reset_new_password():
        if not session.get('reset_verified'):
            return redirect(url_for('forgot_password'))
        
        if request.method == 'POST':
            password = request.form.get('password')
            role = session.get('reset_role')
            email = session.get('reset_email')
        
            if role == 'passenger':
                user = User.query.filter_by(email=email).first()
            else:
                user = Company.query.filter_by(email=email).first()
            
            if user:
                user.password = generate_password_hash(password)
                db.session.commit()
            
                # Clear session
                session.pop('reset_email', None)
                session.pop('reset_role', None)
                session.pop('reset_otp', None)
                session.pop('reset_expiry', None)
                session.pop('reset_verified', None)
            
                flash('Đổi mật khẩu thành công! Vui lòng đăng nhập lại.')
                if role == 'passenger':
                    return redirect(url_for('passenger_login'))
                else:
                    return redirect(url_for('company_login'))
                
        return render_template('auth/reset_password.html')



    def api_login():
        try:
            data = request.json
            if not data:
                return jsonify({'success': False, 'message': 'Không nhận được dữ liệu!'}), 400
                
            email = data.get('email')
            password = data.get('password')
            role = data.get('role', 'passenger') # passenger, company

            if role == 'passenger':
                user = User.query.filter_by(email=email).first()
                if user and check_password_hash(user.password, password):
                    session['user_id'] = user.id
                    session['user_name'] = user.name
                    session['role'] = 'passenger'
                    return jsonify({'success': True, 'user': {'name': user.name, 'role': 'passenger'}})
            else:
                # Check Company
                company = Company.query.filter_by(email=email).first()
                if company and check_password_hash(company.password, password):
                    session['company_id'] = company.id
                    session['company_name'] = company.name
                    session['role'] = 'ADMIN'
                    return jsonify({'success': True, 'user': {'name': company.name, 'role': 'company'}})
                
                # Check Staff
                staff = Staff.query.filter_by(email=email).first()
                if staff and check_password_hash(staff.password, password):
                    session['company_id'] = staff.company_id
                    session['staff_id'] = staff.id
                    session['company_name'] = staff.company.name
                    session['user_name'] = staff.name
                    session['role'] = 'STAFF'
                    session['staff_role'] = (staff.role or 'STATION_STAFF').upper()
                    return jsonify({'success': True, 'user': {'name': staff.name, 'role': 'staff', 'staff_role': session['staff_role']}})
            
            return jsonify({'success': False, 'message': 'Email hoặc mật khẩu không chính xác!'}), 401
        except Exception as e:
            print(f"API Login Error: {e}")
            return jsonify({'success': False, 'message': 'Lỗi hệ thống khi đăng nhập!'}), 500

    def api_google_login():
        data = request.json
        email = data.get('email')
        name = data.get('name')
        role = data.get('role', 'passenger')
        google_id = data.get('google_id')
        
        if role == 'passenger':
            user = User.query.filter_by(email=email).first()
            if not user:
                # Auto register if not exists
                user = User(name=name, email=email, password=generate_password_hash(google_id), phone='')
                db.session.add(user)
                db.session.commit()
            
            session['user_id'] = user.id
            session['user_name'] = user.name
            session['role'] = 'passenger'
            return jsonify({'success': True, 'user': {'name': user.name, 'role': 'passenger'}})
        else:
            # Check Company
            company = Company.query.filter_by(email=email).first()
            if company:
                session['company_id'] = company.id
                session['company_name'] = company.name
                session['role'] = 'ADMIN'
                return jsonify({'success': True, 'user': {'name': company.name, 'role': 'company'}})
                
            # Check Staff
            staff = Staff.query.filter_by(email=email).first()
            if staff:
                session['company_id'] = staff.company_id
                session['staff_id'] = staff.id
                session['company_name'] = staff.company.name
                session['user_name'] = staff.name
                session['role'] = 'STAFF'
                session['staff_role'] = (staff.role or 'STATION_STAFF').upper()
                return jsonify({'success': True, 'user': {'name': staff.name, 'role': 'staff', 'staff_role': session['staff_role']}})
                
            return jsonify({'success': False, 'message': 'Email đối tác không tồn tại trên hệ thống!'})

    def api_register():
        data = request.json
        name = data.get('name')
        email = data.get('email')
        password = data.get('password')
        phone = data.get('phone')
        role = data.get('role', 'passenger')

        if role == 'passenger':
            if User.query.filter_by(email=email).first():
                return jsonify({'success': False, 'message': 'Email này đã được đăng ký!'}), 400
            new_user = User(name=name, email=email, password=generate_password_hash(password), phone=phone)
            db.session.add(new_user)
        else:
            if Company.query.filter_by(email=email).first():
                return jsonify({'success': False, 'message': 'Email nhà xe này đã được đăng ký!'}), 400
            new_company = Company(name=name, email=email, password=generate_password_hash(password), phone=phone)
            db.session.add(new_company)
        
        db.session.commit()
        return jsonify({'success': True, 'message': 'Đăng ký thành công! Vui lòng đăng nhập.'})

    def api_forgot_password():
        data = request.json
        email = data.get('email')
        
        user = User.query.filter_by(email=email).first()
        role = 'passenger'
        
        if not user:
            user = Company.query.filter_by(email=email).first()
            role = 'company'
            
        if not user:
            user = Staff.query.filter_by(email=email).first()
            role = 'staff'
            
        if not user:
            return jsonify({'success': False, 'message': 'Email không tồn tại trong hệ thống!'})
            
        otp = ''.join(random.choices(string.digits, k=6))
        otp_store[email] = {
            'otp': otp,
            'expiry': time.time() + 300,
            'role': role
        }
        
        msg = Message('Mã xác thực OTP - HUTECH BUS', recipients=[email])
        msg.html = f"""
        <div style="font-family: 'Helvetica', 'Arial', sans-serif; max-width: 600px; margin: 0 auto; background-color: #F9F6F2; padding: 40px; border-radius: 16px;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h2 style="color: #B8641A; margin: 0; font-size: 28px; font-weight: 800; letter-spacing: -1px;">HUTECH BUS</h2>
            </div>
            <div style="background-color: #FFFFFF; padding: 40px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
                <p style="color: #6B5D4F; font-size: 16px; margin-top: 0;">Xin chào <strong>{user.name}</strong>,</p>
                <p style="color: #6B5D4F; font-size: 16px; line-height: 1.6;">
                    Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản HUTECH Bus. 
                    Sử dụng mã OTP dưới đây để hoàn tất quá trình xác thực:
                </p>
                <div style="text-align: center; margin: 32px 0;">
                    <span style="display: inline-block; background-color: #FFF0E6; color: #B8641A; font-size: 32px; font-weight: 700; padding: 16px 32px; border-radius: 8px; letter-spacing: 8px; border: 1px dashed #B8641A;">
                        {otp}
                    </span>
                </div>
                <p style="color: #6B5D4F; font-size: 14px; text-align: center;">
                    Mã này sẽ hết hạn sau <strong>5 phút</strong>.
                </p>
            </div>
        </div>
        """
        try:
            mail.send(msg)
            return jsonify({'success': True, 'message': 'Mã OTP đã được gửi đến email của bạn!'})
        except Exception as e:
            return jsonify({'success': False, 'message': f'Lỗi gửi email: {str(e)}'})

    def api_verify_otp():
        data = request.json
        email = data.get('email')
        otp = data.get('otp')
        
        if email not in otp_store:
            return jsonify({'success': False, 'message': 'Yêu cầu không hợp lệ hoặc đã hết hạn.'})
            
        record = otp_store[email]
        if time.time() > record['expiry']:
            del otp_store[email]
            return jsonify({'success': False, 'message': 'Mã OTP đã hết hạn!'})
            
        if record['otp'] != otp:
            return jsonify({'success': False, 'message': 'Mã OTP không chính xác!'})
            
        record['verified'] = True
        return jsonify({'success': True, 'message': 'Xác thực thành công!'})

    def api_reset_password():
        data = request.json
        email = data.get('email')
        new_password = data.get('password')
        
        if email not in otp_store or not otp_store[email].get('verified'):
            return jsonify({'success': False, 'message': 'Chưa xác thực OTP!'})
            
        role = otp_store[email]['role']
        
        if role == 'passenger':
            user = User.query.filter_by(email=email).first()
        elif role == 'company':
            user = Company.query.filter_by(email=email).first()
        else:
            user = Staff.query.filter_by(email=email).first()
            
        if user:
            user.password = generate_password_hash(new_password)
            db.session.commit()
            del otp_store[email]
            return jsonify({'success': True, 'message': 'Đổi mật khẩu thành công!'})
            
        return jsonify({'success': False, 'message': 'Có lỗi xảy ra!'})

    app.add_url_rule('/passenger/register', view_func=passenger_register, methods=['GET', 'POST'])
    app.add_url_rule('/passenger/login', view_func=passenger_login, methods=['GET', 'POST'])
    app.add_url_rule('/company/register', view_func=company_register, methods=['GET', 'POST'])
    app.add_url_rule('/company/login', view_func=company_login, methods=['GET', 'POST'])
    app.add_url_rule('/staff/login', view_func=staff_login, methods=['GET', 'POST'])
    app.add_url_rule('/admin/staff/accounts', view_func=admin_only(admin_staff_accounts), methods=['GET', 'POST'])
    app.add_url_rule('/admin/ticket/check', view_func=company_login_required(admin_check_ticket), methods=['GET', 'POST'])
    app.add_url_rule('/forgot-password', view_func=forgot_password, methods=['GET', 'POST'])
    app.add_url_rule('/verify-otp', view_func=verify_otp, methods=['GET', 'POST'])
    app.add_url_rule('/reset-new-password', view_func=reset_new_password, methods=['GET', 'POST'])
    
    # React API Endpoints
    app.add_url_rule('/api/auth/login', view_func=api_login, methods=['POST'])
    app.add_url_rule('/api/auth/google-login', view_func=api_google_login, methods=['POST'])
    app.add_url_rule('/api/auth/register', view_func=api_register, methods=['POST'])
    app.add_url_rule('/api/auth/forgot-password', view_func=api_forgot_password, methods=['POST'])
    app.add_url_rule('/api/auth/verify-otp', view_func=api_verify_otp, methods=['POST'])
    app.add_url_rule('/api/auth/reset-password', view_func=api_reset_password, methods=['POST'])
