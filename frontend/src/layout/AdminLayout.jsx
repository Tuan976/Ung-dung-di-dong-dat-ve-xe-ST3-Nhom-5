import React from 'react';
import { NavLink } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Bus, 
  MapPin, 
  Package, 
  Users, 
  Settings, 
  LogOut,
  Truck,
  Calendar
} from 'lucide-react';
import { getPermissions } from '../utils/permissions';

const AdminSidebarItem = ({ to, icon: Icon, label, end, permission }) => {
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const permissions = getPermissions(user.role, user.staff_role);
  
  if (!permissions.includes('ALL') && !permissions.includes(permission)) return null;

  return (
    <NavLink 
      to={to} 
      end={end}
      className={({ isActive }) => `
        flex items-center gap-2 px-4 py-2 rounded-lg transition-all duration-300
        ${isActive ? 'bg-blue-600 text-white' : 'text-slate-300 hover:bg-slate-800 hover:text-white'}
      `}
    >
      <Icon size={16} />
      <span className="font-bold text-xs uppercase tracking-tight">{label}</span>
    </NavLink>
  );
};

const AdminLayout = ({ children }) => {
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  
  const handleLogout = () => {
    localStorage.removeItem('user');
    window.location.href = '/auth';
  };

  return (
    <div className="dashboard-container bg-[#f0f2f5] min-h-screen flex flex-col">
      <header className="h-14 bg-[#004e92] text-white flex items-center justify-between px-6 sticky top-0 z-50 shadow-md">
        <div className="flex items-center gap-8">
          <div className="flex items-center gap-2 mr-4">
            <div className="bg-orange-500 p-1.5 rounded-lg">
               <Bus size={18} className="text-white" />
            </div>
            <span className="text-lg font-black tracking-tighter uppercase italic">Hutech Bus</span>
          </div>

          <nav className="flex items-center gap-2">
            <AdminSidebarItem to="/admin" end icon={LayoutDashboard} label="Tổng quan" permission="DASHBOARD" />
            <AdminSidebarItem to="/admin/trips" icon={Calendar} label="Lịch trình" permission="TRIPS" />
            <AdminSidebarItem to="/admin/buses" icon={Bus} label="Đội xe" permission="TRIPS" />
            <AdminSidebarItem to="/admin/warehouse/sending" icon={Truck} label="Kho gửi" permission="WAREHOUSE" />
            <AdminSidebarItem to="/admin/cargo" icon={Package} label="Hàng hóa" permission="CARGO" />
            <AdminSidebarItem to="/admin/offices" icon={MapPin} label="Văn phòng" permission="OFFICES" />
            <AdminSidebarItem to="/admin/staff" icon={Users} label="Nhân sự" permission="STAFF" />
            <AdminSidebarItem to="/admin/settings" icon={Settings} label="Cấu hình" permission="SETTINGS" />
          </nav>
        </div>

        <div className="flex items-center gap-4">
          <div className="flex items-center gap-3 pr-4 border-r border-blue-400/30">
            <div className="text-right">
              <div className="text-[10px] font-black text-white truncate max-w-[120px] uppercase tracking-tight">{user.name || 'User'}</div>
              <div className="text-[9px] font-black text-orange-400 uppercase tracking-widest">{user.staff_role || user.role}</div>
            </div>
          </div>
          <button 
            onClick={handleLogout}
            className="flex items-center gap-2 px-3 py-1.5 bg-red-500/20 hover:bg-red-500 text-red-200 hover:text-white rounded-md transition-all text-[10px] font-black uppercase tracking-widest border border-red-500/30"
          >
            <LogOut size={14} />
            Đăng xuất
          </button>
        </div>
      </header>

      <main className="flex-1 p-4 overflow-auto">
        <div className="max-w-[1600px] mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
};

export default AdminLayout;
