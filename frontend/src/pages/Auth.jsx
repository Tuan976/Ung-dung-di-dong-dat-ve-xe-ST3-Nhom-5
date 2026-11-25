import React, { useState } from 'react';
import {
  User,
  Building2,
  Mail,
  Lock,
  Phone,
  Bus,
  Eye,
  EyeOff,
  Loader2,
  AlertCircle,
  CheckCircle2,
  ShieldCheck,
} from 'lucide-react';
import { GoogleLogin } from '@react-oauth/google';
import { jwtDecode } from 'jwt-decode';
import { useSearchParams } from 'react-router-dom';

const Auth = () => {
  const [searchParams] = useSearchParams();
  const requestedMode = searchParams.get('mode');
  const [modeOverride, setModeOverride] = useState(null);
  const type =
    modeOverride?.requestedMode === requestedMode
      ? modeOverride.type
      : ['register', 'forgot'].includes(requestedMode)
        ? requestedMode
        : 'login';
  const setType = nextType => setModeOverride({ requestedMode, type: nextType });
  const [role, setRole] = useState('passenger'); // passenger, company
  const [showPassword, setShowPassword] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    password: '',
    otp: '',
    newPassword: '',
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const handleGoogleSuccess = async credentialResponse => {
    setIsLoading(true);
    setError('');
    setSuccessMsg('');
    try {
      const decoded = jwtDecode(credentialResponse.credential);
      const { email, name, sub } = decoded;

      const res = await fetch('/api/auth/google-login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, name, google_id: sub, role }),
      });
      const data = await res.json();

      if (data.success) {
        localStorage.setItem('user', JSON.stringify(data.user));
        const userRole = data.user.role?.toUpperCase();
        if (userRole === 'PASSENGER') {
          window.location.href = '/';
        } else {
          window.location.href = '/admin';
        }
      } else {
        setError(data.message || 'Đã có lỗi xảy ra khi đăng nhập bằng Google!');
      }
    } catch {
      setError('Lỗi kết nối server!');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAuth = async e => {
    e.preventDefault();
    setError('');
    setSuccessMsg('');
    setIsLoading(true);
    try {
      let endpoint = '';
      let bodyData = {};

      if (type === 'login') {
        endpoint = '/api/auth/login';
        bodyData = { ...formData, role };
      } else if (type === 'register') {
        endpoint = '/api/auth/register';
        bodyData = { ...formData, role };
      } else if (type === 'forgot') {
        endpoint = '/api/auth/forgot-password';
        bodyData = { email: formData.email };
      } else if (type === 'otp') {
        endpoint = '/api/auth/verify-otp';
        bodyData = { email: formData.email, otp: formData.otp };
      } else if (type === 'reset') {
        endpoint = '/api/auth/reset-password';
        bodyData = { email: formData.email, password: formData.newPassword };
      }

      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bodyData),
      });
      const data = await res.json();

      if (data.success) {
        if (type === 'login') {
          localStorage.setItem('user', JSON.stringify(data.user));
          const userRole = data.user.role?.toUpperCase();
          if (userRole === 'PASSENGER') {
            window.location.href = '/';
          } else {
            window.location.href = '/admin';
          }
        } else if (type === 'register') {
          setSuccessMsg('Đăng ký thành công! Vui lòng đăng nhập.');
          setType('login');
        } else if (type === 'forgot') {
          setType('otp');
        } else if (type === 'otp') {
          setType('reset');
        } else if (type === 'reset') {
          setSuccessMsg('Đổi mật khẩu thành công! Vui lòng đăng nhập.');
          setType('login');
        }
      } else {
        setError(data.message || 'Đã có lỗi xảy ra!');
      }
    } catch {
      setError('Lỗi kết nối server!');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F7F8FA] flex flex-col justify-center py-12 px-4 sm:px-6">
      <div className="max-w-4xl mx-auto w-full">
        <div className="bg-white rounded-2xl border border-[#E7EAF0] card-shadow overflow-hidden flex flex-col md:flex-row">
          {/* Left Side: Triply Brand Identity */}
          <div className="md:w-5/12 p-8 bg-[#FFF9F5] border-b md:border-b-0 md:border-r border-[#E7EAF0] flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-2.5 mb-6">
                <div className="grid size-10 place-items-center rounded-xl bg-[#FF6B00] text-white">
                  <Bus size={22} />
                </div>
                <span className="text-2xl font-black tracking-tight text-[#202938]">
                  TRIP<span className="text-[#FF6B00]">LY</span>
                </span>
              </div>
              <h2 className="text-xl font-extrabold text-[#202938] mb-3">
                Nền tảng đặt vé xe khách thông minh
              </h2>
              <p className="text-sm text-[#778196] leading-relaxed">
                Quản lý hành trình dễ dàng, chọn đúng ghế ngồi yêu thích và nhận vé điện tử QR tức thì.
              </p>
            </div>

            <div className="mt-8 space-y-3">
              <div className="flex items-center gap-2.5 text-xs font-bold text-[#202938]">
                <ShieldCheck size={16} className="text-[#16A36A] shrink-0" />
                <span>Cam kết 100% giữ đúng vị trí ghế</span>
              </div>
              <div className="flex items-center gap-2.5 text-xs font-bold text-[#202938]">
                <ShieldCheck size={16} className="text-[#16A36A] shrink-0" />
                <span>Trợ lý đặt vé Triply hỗ trợ 24/7</span>
              </div>
              <div className="pt-4 border-t border-[#E7EAF0] text-[11px] font-medium text-[#778196]">
                © 2026 TRIPLY Mobility Platform
              </div>
            </div>
          </div>

          {/* Right Side: Auth Form */}
          <div className="md:w-7/12 p-8 bg-white">
            {/* Role Switcher */}
            <div className="mb-6 grid grid-cols-2 gap-1.5 rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] p-1">
              <button
                type="button"
                onClick={() => setRole('passenger')}
                className={`flex items-center justify-center gap-1.5 rounded-lg py-2 text-xs font-bold transition cursor-pointer ${
                  role === 'passenger'
                    ? 'bg-white text-[#FF6B00] shadow-xs'
                    : 'text-[#778196] hover:text-[#202938]'
                }`}
              >
                <User size={15} /> Hành khách
              </button>
              <button
                type="button"
                onClick={() => setRole('company')}
                className={`flex items-center justify-center gap-1.5 rounded-lg py-2 text-xs font-bold transition cursor-pointer ${
                  role === 'company'
                    ? 'bg-[#FF6B00] text-white shadow-xs'
                    : 'text-[#778196] hover:text-[#202938]'
                }`}
              >
                <Building2 size={15} /> Đối tác Nhà xe
              </button>
            </div>

            <h3 className="text-xl font-extrabold text-[#202938] mb-5">
              {type === 'forgot' && 'Khôi phục mật khẩu'}
              {type === 'otp' && 'Xác thực mã OTP'}
              {type === 'reset' && 'Thiết lập mật khẩu mới'}
              {(type === 'login' || type === 'register') &&
                (role === 'passenger'
                  ? type === 'login'
                    ? 'Đăng nhập tài khoản'
                    : 'Tạo tài khoản mới'
                  : 'Đăng nhập Cổng Nhà xe')}
            </h3>

            {error && (
              <div className="mb-5 p-3.5 bg-[#FDECEC] border border-[#F8C6C6] rounded-xl flex items-center gap-2.5 text-[#DC4545] text-xs font-bold">
                <AlertCircle size={18} className="shrink-0" />
                <span>{error}</span>
              </div>
            )}
            {successMsg && (
              <div className="mb-5 p-3.5 bg-[#E9F8F0] border border-[#C2ECD5] rounded-xl flex items-center gap-2.5 text-[#16A36A] text-xs font-bold">
                <CheckCircle2 size={18} className="shrink-0" />
                <span>{successMsg}</span>
              </div>
            )}

            {(type === 'login' || type === 'register') && role === 'passenger' && (
              <div className="flex border-b border-[#E7EAF0] mb-6">
                <button
                  type="button"
                  onClick={() => setType('login')}
                  className={`flex-1 pb-2.5 text-xs font-extrabold uppercase tracking-wider transition cursor-pointer ${
                    type === 'login'
                      ? 'text-[#FF6B00] border-b-2 border-[#FF6B00]'
                      : 'text-[#778196]'
                  }`}
                >
                  Đăng nhập
                </button>
                <button
                  type="button"
                  onClick={() => setType('register')}
                  className={`flex-1 pb-2.5 text-xs font-extrabold uppercase tracking-wider transition cursor-pointer ${
                    type === 'register'
                      ? 'text-[#FF6B00] border-b-2 border-[#FF6B00]'
                      : 'text-[#778196]'
                  }`}
                >
                  Đăng ký
                </button>
              </div>
            )}

            <form className="space-y-3.5" onSubmit={handleAuth}>
              {type === 'register' && (
                <div className="relative">
                  <User className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" size={17} />
                  <input
                    type="text"
                    required
                    value={formData.name}
                    onChange={e => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Họ và tên của bạn"
                    className="w-full bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl py-3 pl-10 pr-4 text-sm font-semibold text-[#202938] focus:bg-white focus:border-[#FF6B00] outline-none transition"
                  />
                </div>
              )}

              {(type === 'login' || type === 'register' || type === 'forgot') && (
                <div className="relative">
                  <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" size={17} />
                  <input
                    type="email"
                    required
                    value={formData.email}
                    onChange={e => setFormData({ ...formData, email: e.target.value })}
                    placeholder="Địa chỉ email"
                    className="w-full bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl py-3 pl-10 pr-4 text-sm font-semibold text-[#202938] focus:bg-white focus:border-[#FF6B00] outline-none transition"
                  />
                </div>
              )}

              {type === 'otp' && (
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" size={17} />
                  <input
                    type="text"
                    required
                    value={formData.otp}
                    onChange={e => setFormData({ ...formData, otp: e.target.value })}
                    placeholder="Nhập mã OTP (6 số)"
                    className="w-full bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl py-3 pl-10 pr-4 text-sm font-bold text-[#202938] text-center tracking-widest focus:bg-white focus:border-[#FF6B00] outline-none transition"
                  />
                </div>
              )}

              {type === 'register' && (
                <div className="relative">
                  <Phone className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" size={17} />
                  <input
                    type="tel"
                    required
                    value={formData.phone}
                    onChange={e => setFormData({ ...formData, phone: e.target.value.replace(/\D/g, '') })}
                    placeholder="Số điện thoại"
                    className="w-full bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl py-3 pl-10 pr-4 text-sm font-semibold text-[#202938] focus:bg-white focus:border-[#FF6B00] outline-none transition"
                  />
                </div>
              )}

              {(type === 'login' || type === 'register') && (
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" size={17} />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    value={formData.password}
                    onChange={e => setFormData({ ...formData, password: e.target.value })}
                    placeholder="Mật khẩu"
                    className="w-full bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl py-3 pl-10 pr-10 text-sm font-semibold text-[#202938] focus:bg-white focus:border-[#FF6B00] outline-none transition"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3.5 top-1/2 -translate-y-1/2 text-[#778196] hover:text-[#202938]"
                  >
                    {showPassword ? <EyeOff size={17} /> : <Eye size={17} />}
                  </button>
                </div>
              )}

              {type === 'reset' && (
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" size={17} />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    value={formData.newPassword}
                    onChange={e => setFormData({ ...formData, newPassword: e.target.value })}
                    placeholder="Nhập mật khẩu mới"
                    className="w-full bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl py-3 pl-10 pr-10 text-sm font-semibold text-[#202938] focus:bg-white focus:border-[#FF6B00] outline-none transition"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3.5 top-1/2 -translate-y-1/2 text-[#778196] hover:text-[#202938]"
                  >
                    {showPassword ? <EyeOff size={17} /> : <Eye size={17} />}
                  </button>
                </div>
              )}

              <button
                type="submit"
                disabled={isLoading}
                className="w-full py-3 bg-[#FF6B00] hover:bg-[#E85F00] text-white font-bold text-sm rounded-xl transition mt-4 flex items-center justify-center gap-2 cursor-pointer"
              >
                {isLoading ? (
                  <>
                    <Loader2 size={18} className="animate-spin" />
                    Đang xử lý...
                  </>
                ) : type === 'login' ? (
                  'Đăng nhập'
                ) : type === 'register' ? (
                  'Tạo tài khoản'
                ) : type === 'forgot' ? (
                  'Gửi mã OTP'
                ) : type === 'otp' ? (
                  'Xác nhận OTP'
                ) : (
                  'Đổi mật khẩu'
                )}
              </button>

              {(type === 'login' || type === 'register') && (
                <>
                  <div className="flex items-center gap-3 my-4">
                    <div className="flex-1 h-px bg-[#E7EAF0]"></div>
                    <span className="text-xs font-semibold text-[#778196]">Hoặc</span>
                    <div className="flex-1 h-px bg-[#E7EAF0]"></div>
                  </div>

                  <div className="flex justify-center">
                    <GoogleLogin
                      onSuccess={handleGoogleSuccess}
                      onError={() => setError('Đăng nhập Google thất bại!')}
                      useOneTap
                      shape="rectangular"
                      text={type === 'login' ? 'signin_with' : 'signup_with'}
                    />
                  </div>
                </>
              )}

              {type === 'login' && (
                <div className="text-center mt-3">
                  <button
                    type="button"
                    onClick={() => setType('forgot')}
                    className="text-xs font-bold text-[#FF6B00] hover:underline cursor-pointer"
                  >
                    Quên mật khẩu?
                  </button>
                </div>
              )}

              {(type === 'forgot' || type === 'otp' || type === 'reset') && (
                <div className="text-center mt-3">
                  <button
                    type="button"
                    onClick={() => setType('login')}
                    className="text-xs font-bold text-[#778196] hover:text-[#202938] hover:underline cursor-pointer"
                  >
                    Quay lại đăng nhập
                  </button>
                </div>
              )}
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Auth;
