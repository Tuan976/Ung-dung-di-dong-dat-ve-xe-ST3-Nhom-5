import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { User, Building2, Mail, Lock, Phone, ArrowRight, Eye, EyeOff, Loader2, AlertCircle, CheckCircle2 } from 'lucide-react';
import { GoogleLogin } from '@react-oauth/google';
import { jwtDecode } from 'jwt-decode';

const Auth = () => {
  const [type, setType] = useState('login'); // login, register, forgot, otp, reset
  const [role, setRole] = useState('passenger'); // passenger, company
  const [showPassword, setShowPassword] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    password: '',
    otp: '',
    newPassword: ''
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const handleGoogleSuccess = async (credentialResponse) => {
    setIsLoading(true);
    setError('');
    setSuccessMsg('');
    try {
      const decoded = jwtDecode(credentialResponse.credential);
      const { email, name, sub } = decoded;
      
      const res = await fetch('/api/auth/google-login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, name, google_id: sub, role })
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
    } catch (err) {
      setError('Lỗi kết nối server!');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAuth = async (e) => {
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
        body: JSON.stringify(bodyData)
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
    } catch (err) {
      setError('Lỗi kết nối server!');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col pt-32 pb-12">
      {/* FUTA-style header bg */}
      <div className="absolute top-0 left-0 w-full h-[320px] bg-gradient-to-b from-[#EF5222] to-[#FF8E53] -z-10"></div>
      
      <div className="max-w-5xl mx-auto w-full px-6 flex-1 flex items-center justify-center">
        <div className="bg-white rounded-3xl shadow-2xl overflow-hidden flex flex-col md:flex-row w-full max-w-4xl min-h-[500px]">
          
          {/* Left Side: Branding (FUTA Style) */}
          <div className="md:w-1/2 p-10 bg-white flex flex-col border-r border-slate-100">
            <div className="mb-8">
              <h1 className="text-3xl font-black text-[#008000] tracking-tighter uppercase italic">HUTECH BUS</h1>
              <p className="text-[#EF5222] font-bold text-lg mt-1 italic">Cùng bạn trên mọi nẻo đường</p>
            </div>

            <div className="mt-auto relative flex justify-center">
               <div className="text-center z-10">
                  <h2 className="text-2xl font-black text-[#008000] mb-2 uppercase">XE TRUNG CHUYỂN</h2>
                  <h2 className="text-2xl font-black text-[#008000] uppercase">ĐÓN - TRẢ TẬN NƠI</h2>
               </div>
               {/* Illustration Placeholder - Simplified Bus SVG */}
               <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 opacity-10">
                  <svg width="300" height="200" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" className="text-[#EF5222]">
                    <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-1.1 0-2 .9-2 2v7h2m14 0c0 1.1-.9 2-2 2s-2-.9-2-2m4 0h-4m-8 0c0 1.1-.9 2-2 2s-2-.9-2-2m4 0H5" />
                  </svg>
               </div>
            </div>

            <div className="mt-auto pt-10 text-xs font-bold text-slate-400">
               &copy; 2026 HUTECH BUS GROUP. Đa dạng hệ sinh thái phục vụ bạn.
            </div>
          </div>

          {/* Right Side: Auth Form (FUTA Style) */}
          <div className="md:w-1/2 p-10 bg-white">
            <div className="flex flex-col h-full">
              <h3 className="text-2xl font-black text-slate-800 text-center mb-8">
                {type === 'forgot' && 'Quên mật khẩu'}
                {type === 'otp' && 'Xác thực OTP'}
                {type === 'reset' && 'Mật khẩu mới'}
                {(type === 'login' || type === 'register') && (role === 'passenger' ? (type === 'login' ? 'Đăng nhập tài khoản' : 'Đăng ký tài khoản') : 'Đối tác Nhà xe')}
              </h3>

              {/* Messages */}
              <AnimatePresence>
                {error && (
                  <motion.div 
                    initial={{ opacity: 0, y: -10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -10 }}
                    className="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl flex items-center gap-3 text-red-600 shadow-sm"
                  >
                    <AlertCircle size={20} className="shrink-0" />
                    <p className="font-semibold text-sm">{error}</p>
                  </motion.div>
                )}
                {successMsg && (
                  <motion.div 
                    initial={{ opacity: 0, y: -10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -10 }}
                    className="mb-6 p-4 bg-emerald-50 border border-emerald-200 rounded-xl flex items-center gap-3 text-emerald-600 shadow-sm"
                  >
                    <CheckCircle2 size={20} className="shrink-0" />
                    <p className="font-semibold text-sm">{successMsg}</p>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Tabs */}
              {(type === 'login' || type === 'register') && (
                <div className="flex border-b border-slate-100 mb-8">
                  <button 
                    onClick={() => setType('login')}
                    className={`flex-1 py-3 font-black text-sm uppercase tracking-wider transition-all flex items-center justify-center gap-2 ${type === 'login' ? 'text-[#EF5222] border-b-2 border-[#EF5222]' : 'text-slate-400'}`}
                  >
                    <Phone size={16} /> Đăng nhập
                  </button>
                  <button 
                    onClick={() => setType('register')}
                    className={`flex-1 py-3 font-black text-sm uppercase tracking-wider transition-all flex items-center justify-center gap-2 ${type === 'register' ? 'text-[#EF5222] border-b-2 border-[#EF5222]' : 'text-slate-400'}`}
                  >
                    Đăng ký
                  </button>
                </div>
              )}

              {/* Form */}
              <form className="space-y-4" onSubmit={handleAuth}>
                {type === 'register' && (
                  <div className="relative group">
                    <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300 group-focus-within:text-[#EF5222] transition-colors" size={18} />
                    <input 
                      type="text" 
                      required 
                      value={formData.name}
                      onChange={(e) => setFormData({...formData, name: e.target.value})}
                      placeholder="Nhập họ và tên" 
                      className="w-full bg-slate-50 border border-slate-100 rounded-xl py-3.5 pl-12 pr-4 font-bold text-slate-800 focus:ring-2 focus:ring-[#EF5222]/10 focus:border-[#EF5222] outline-none transition-all" 
                    />
                  </div>
                )}

                {(type === 'login' || type === 'register' || type === 'forgot') && (
                  <div className="relative group">
                    <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300 group-focus-within:text-[#EF5222] transition-colors" size={18} />
                    <input 
                      type="email" 
                      required 
                      value={formData.email}
                      onChange={(e) => setFormData({...formData, email: e.target.value})}
                      placeholder="Nhập địa chỉ email" 
                      className="w-full bg-slate-50 border border-slate-100 rounded-xl py-3.5 pl-12 pr-4 font-bold text-slate-800 focus:ring-2 focus:ring-[#EF5222]/10 focus:border-[#EF5222] outline-none transition-all" 
                    />
                  </div>
                )}

                {type === 'otp' && (
                  <div className="relative group">
                    <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300 group-focus-within:text-[#EF5222] transition-colors" size={18} />
                    <input 
                      type="text" 
                      required 
                      value={formData.otp}
                      onChange={(e) => setFormData({...formData, otp: e.target.value})}
                      placeholder="Nhập mã OTP (6 số)" 
                      className="w-full bg-slate-50 border border-slate-100 rounded-xl py-3.5 pl-12 pr-4 font-bold text-slate-800 text-center tracking-widest focus:ring-2 focus:ring-[#EF5222]/10 focus:border-[#EF5222] outline-none transition-all" 
                    />
                  </div>
                )}

                {type === 'register' && (
                  <div className="relative group">
                    <Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300 group-focus-within:text-[#EF5222] transition-colors" size={18} />
                    <input 
                      type="tel" 
                      required 
                      value={formData.phone}
                      onChange={(e) => setFormData({...formData, phone: e.target.value})}
                      placeholder="Nhập số điện thoại" 
                      className="w-full bg-slate-50 border border-slate-100 rounded-xl py-3.5 pl-12 pr-4 font-bold text-slate-800 focus:ring-2 focus:ring-[#EF5222]/10 focus:border-[#EF5222] outline-none transition-all" 
                    />
                  </div>
                )}

                {(type === 'login' || type === 'register') && (
                  <div className="relative group">
                    <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300 group-focus-within:text-[#EF5222] transition-colors" size={18} />
                    <input 
                      type={showPassword ? "text" : "password"} 
                      required
                      value={formData.password}
                      onChange={(e) => setFormData({...formData, password: e.target.value})}
                      placeholder="Nhập mật khẩu" 
                      className="w-full bg-slate-50 border border-slate-100 rounded-xl py-3.5 pl-12 pr-12 font-bold text-slate-800 focus:ring-2 focus:ring-[#EF5222]/10 focus:border-[#EF5222] outline-none transition-all" 
                    />
                    <button 
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-300 hover:text-slate-500"
                    >
                      {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                )}

                {type === 'reset' && (
                  <div className="relative group">
                    <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300 group-focus-within:text-[#EF5222] transition-colors" size={18} />
                    <input 
                      type={showPassword ? "text" : "password"} 
                      required
                      value={formData.newPassword}
                      onChange={(e) => setFormData({...formData, newPassword: e.target.value})}
                      placeholder="Nhập mật khẩu mới" 
                      className="w-full bg-slate-50 border border-slate-100 rounded-xl py-3.5 pl-12 pr-12 font-bold text-slate-800 focus:ring-2 focus:ring-[#EF5222]/10 focus:border-[#EF5222] outline-none transition-all" 
                    />
                    <button 
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-300 hover:text-slate-500"
                    >
                      {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                )}

                <button 
                  type="submit" 
                  disabled={isLoading}
                  className="w-full py-4 bg-[#EF5222] hover:bg-[#D43D11] text-white font-black rounded-xl shadow-lg shadow-orange-100 transition-all uppercase tracking-widest mt-6 flex items-center justify-center gap-2"
                >
                  {isLoading ? (
                    <>
                      <Loader2 size={20} className="animate-spin" />
                      Đang xử lý...
                    </>
                  ) : (
                    type === 'login' ? 'Đăng nhập' : 
                    type === 'register' ? 'Đăng ký tài khoản' : 
                    type === 'forgot' ? 'Gửi mã OTP' : 
                    type === 'otp' ? 'Xác nhận OTP' : 'Đổi mật khẩu'
                  )}
                </button>

                {(type === 'login' || type === 'register') && (
                  <>
                    <div className="flex items-center gap-4 my-6">
                      <div className="flex-1 h-px bg-slate-100"></div>
                      <span className="text-sm font-bold text-slate-400">HOẶC</span>
                      <div className="flex-1 h-px bg-slate-100"></div>
                    </div>
                    
                    <div className="flex justify-center">
                      <GoogleLogin
                        onSuccess={handleGoogleSuccess}
                        onError={() => setError('Đăng nhập Google thất bại!')}
                        useOneTap
                        shape="pill"
                        text={type === 'login' ? "signin_with" : "signup_with"}
                      />
                    </div>
                  </>
                )}

                {type === 'login' && (
                  <div className="text-center mt-4">
                    <button type="button" onClick={() => setType('forgot')} className="text-sm font-bold text-[#EF5222] hover:underline">Quên mật khẩu?</button>
                  </div>
                )}

                {(type === 'forgot' || type === 'otp' || type === 'reset') && (
                  <div className="text-center mt-4">
                    <button type="button" onClick={() => setType('login')} className="text-sm font-bold text-slate-400 hover:text-slate-600 hover:underline">Quay lại đăng nhập</button>
                  </div>
                )}
              </form>

              {/* Role Switcher */}
              <div className="mt-auto pt-8 border-t border-slate-100">
                <div className="text-center text-xs font-bold text-slate-400 uppercase tracking-widest mb-3">Kết nối Đối tác</div>
                <button 
                  onClick={() => setRole(role === 'passenger' ? 'company' : 'passenger')}
                  className="w-full py-2.5 rounded-xl border-2 border-slate-100 text-slate-500 font-bold text-sm hover:bg-slate-50 transition-all flex items-center justify-center gap-2"
                >
                  {role === 'passenger' ? <Building2 size={16} /> : <User size={16} />}
                  {role === 'passenger' ? 'Bạn là Nhà xe? Đăng nhập tại đây' : 'Quay lại đăng nhập Khách hàng'}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Auth;
