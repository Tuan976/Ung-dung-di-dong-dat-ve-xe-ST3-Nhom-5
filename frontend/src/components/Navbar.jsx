import React, { useState, useEffect } from 'react';
import { NavLink, Link, useNavigate } from 'react-router-dom';
import { Bus, LogIn, UserPlus, User, LogOut, LayoutDashboard } from 'lucide-react';

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
    <header className="sticky top-0 z-50 w-full border-b border-[#E7EAF0] bg-white">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Triply Brand Logo */}
        <Link to="/" className="flex items-center gap-2.5">
          <div className="grid size-9 place-items-center rounded-xl bg-[#FF6B00] text-white shadow-sm shadow-[#FF6B00]/20">
            <Bus size={20} />
          </div>
          <div className="flex flex-col">
            <span className="text-xl font-black tracking-tight text-[#202938] leading-none">
              TRIP<span className="text-[#FF6B00]">LY</span>
            </span>
            <span className="text-[10px] font-semibold text-[#778196] tracking-wide">
              Modern Mobility Platform
            </span>
          </div>
        </Link>

        {/* Main Navigation Links */}
        <nav className="hidden md:flex items-center gap-7 text-sm font-semibold text-[#778196]">
          <NavLink
            to="/"
            end
            className={({ isActive }) =>
              isActive ? 'nav-link-active' : 'hover:text-[#FF6B00] transition-colors'
            }
          >
            Trang chủ
          </NavLink>
          <NavLink
            to="/check-ticket"
            className={({ isActive }) =>
              isActive ? 'nav-link-active' : 'hover:text-[#FF6B00] transition-colors'
            }
          >
            Tra cứu vé
          </NavLink>
          <NavLink
            to="/thong-tin/huong-dan-thanh-toan"
            className={({ isActive }) =>
              isActive ? 'nav-link-active' : 'hover:text-[#FF6B00] transition-colors'
            }
          >
            Hướng dẫn đặt vé
          </NavLink>
          <NavLink
            to="/thong-tin/faq"
            className={({ isActive }) =>
              isActive ? 'nav-link-active' : 'hover:text-[#FF6B00] transition-colors'
            }
          >
            Hỗ trợ & FAQ
          </NavLink>
          <Link to="/auth" className="hover:text-[#FF6B00] transition-colors">
            Đối tác Nhà xe
          </Link>
        </nav>

        {/* Auth / User Actions */}
        <div className="flex items-center gap-3">
          {user ? (
            <div className="relative">
              <button
                onClick={() => setShowDropdown(!showDropdown)}
                onBlur={() => setTimeout(() => setShowDropdown(false), 200)}
                className="flex items-center gap-2.5 rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] px-3 py-1.5 text-sm font-bold text-[#202938] hover:border-[#FF6B00] transition-all"
              >
                <div className="grid size-7 place-items-center rounded-lg bg-[#FFF1E6] text-[#FF6B00]">
                  <User size={15} />
                </div>
                <span className="hidden sm:block max-w-[140px] truncate">
                  {user.name || 'Khách hàng'}
                </span>
              </button>

              {showDropdown && (
                <div className="absolute right-0 mt-2 w-52 rounded-xl border border-[#E7EAF0] bg-white py-1.5 shadow-lg z-50">
                  <Link
                    to="/profile"
                    className="flex items-center gap-2.5 px-4 py-2.5 text-sm font-semibold text-[#202938] hover:bg-[#F7F8FA] hover:text-[#FF6B00]"
                  >
                    <User size={16} />
                    Tài khoản của tôi
                  </Link>
                  {user.role && user.role.toUpperCase() !== 'PASSENGER' && (
                    <Link
                      to="/admin"
                      className="flex items-center gap-2.5 px-4 py-2.5 text-sm font-semibold text-[#202938] hover:bg-[#F7F8FA] hover:text-[#FF6B00]"
                    >
                      <LayoutDashboard size={16} />
                      Cổng Quản trị Nhà xe
                    </Link>
                  )}
                  <div className="my-1 border-t border-[#E7EAF0]" />
                  <button
                    onClick={handleLogout}
                    className="flex w-full items-center gap-2.5 px-4 py-2.5 text-left text-sm font-semibold text-[#DC4545] hover:bg-[#FDECEC]"
                  >
                    <LogOut size={16} />
                    Đăng xuất
                  </button>
                </div>
              )}
            </div>
          ) : (
            <>
              <Link
                to="/auth"
                className="hidden sm:inline-flex items-center gap-1.5 rounded-xl border border-[#E7EAF0] bg-white px-4 py-2 text-sm font-bold text-[#202938] hover:border-[#FF6B00] hover:text-[#FF6B00] transition-all"
              >
                <LogIn size={16} />
                Đăng nhập
              </Link>
              <Link
                to="/auth?mode=register"
                className="inline-flex items-center gap-1.5 rounded-xl bg-[#FF6B00] hover:bg-[#E85F00] px-4 py-2 text-sm font-bold text-white transition-all shadow-sm"
              >
                <UserPlus size={16} />
                Đăng ký
              </Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
};

export default Navbar;
