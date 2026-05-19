import React, { useState, useEffect } from 'react';
import { NavLink, Link, useNavigate } from 'react-router-dom';
import { LogIn, UserPlus, User, LogOut } from 'lucide-react';

const Navbar = () => {
  const [user, setUser] = useState(null);
  const [showDropdown, setShowDropdown] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      try {
        setUser(JSON.parse(userStr));
      } catch (e) {
        console.error(e);
      }
    }
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('user');
    setUser(null);
    navigate('/');
  };

  return (
  <nav className="fixed top-6 left-1/2 -translate-x-1/2 w-[92%] max-w-7xl glass rounded-full h-16 px-8 flex items-center justify-between z-50 card-shadow">
    <div className="flex items-center gap-2">
      <Link to="/" className="flex items-center gap-2">
        <div className="flex gap-0.5">
          <div className="w-1.5 h-6 bg-[#EF5222] rounded-full animate-bounce"></div>
          <div className="w-1.5 h-8 bg-[#008000] rounded-full"></div>
          <div className="w-1.5 h-5 bg-orange-400 rounded-full animate-bounce" style={{animationDelay: '0.2s'}}></div>
        </div>
        <span className="text-xl font-black text-slate-900 ml-2 tracking-tight italic uppercase">Hutech Bus</span>
      </Link>
    </div>

    <div className="hidden md:flex items-center gap-8 font-semibold text-slate-600 text-sm">
      <NavLink to="/" className={({isActive}) => isActive ? "nav-link-active" : "hover:text-orange-500 transition-colors"}>Trang chủ</NavLink>
      <a href="#" className="hover:text-orange-500 transition-colors">Lịch trình</a>
      <NavLink to="/check-ticket" className={({isActive}) => isActive ? "nav-link-active" : "hover:text-orange-500 transition-colors"}>Tra cứu vé</NavLink>
      <Link to="/auth" className="hover:text-orange-500 transition-colors">Đăng ký Nhà xe</Link>
      <a href="#" className="hover:text-orange-500 transition-colors">Liên hệ</a>
    </div>

    <div className="flex items-center gap-4">
      {user ? (
        <div className="relative">
          <button 
            onClick={() => setShowDropdown(!showDropdown)}
            onBlur={() => setTimeout(() => setShowDropdown(false), 200)}
            className="flex items-center gap-2 font-bold text-slate-600 hover:text-[#EF5222] transition-all text-sm"
          >
            <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-[#EF5222]">
              <User size={16} />
            </div>
            <span className="hidden md:block">{user.name || 'Người dùng'}</span>
          </button>
          
          {showDropdown && (
            <div className="absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-lg py-2 border border-slate-100 z-50">
              <Link to="/profile" className="flex items-center gap-2 px-4 py-3 text-sm text-slate-700 hover:bg-slate-50 hover:text-[#EF5222] font-semibold border-b border-slate-50">
                <User size={16} />
                Tài khoản của tôi
              </Link>
              <button 
                onClick={handleLogout}
                className="w-full flex items-center gap-2 px-4 py-3 text-sm text-red-600 hover:bg-red-50 text-left font-semibold"
              >
                <LogOut size={16} />
                Đăng xuất
              </button>
            </div>
          )}
        </div>
      ) : (
        <>
          <Link to="/auth" className="hidden md:flex items-center gap-2 font-bold text-slate-600 hover:text-[#EF5222] transition-all text-sm">
            <LogIn size={18} />
            Đăng nhập
          </Link>
          <Link to="/auth" className="bg-[#EF5222] hover:bg-[#D43D11] text-white px-6 py-2 rounded-full text-sm font-bold transition-all shadow-lg shadow-orange-100 flex items-center gap-2">
            <UserPlus size={16} />
            Đăng ký
          </Link>
        </>
      )}
    </div>
  </nav>
  );
};

export default Navbar;
