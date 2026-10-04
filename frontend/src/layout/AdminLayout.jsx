import React, { useState, useEffect } from 'react';
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
  Calendar,
  AlertTriangle
} from 'lucide-react';
import axios from 'axios';
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
  const [sosAlerts, setSosAlerts] = useState([]);
  
  useEffect(() => {
    // Poll for SOS alerts every 5 seconds
    const interval = setInterval(() => {
      const baseUrl = window.location.origin.includes('localhost') ? 'http://127.0.0.1:5000' : window.location.origin;
      axios.get(`${baseUrl}/api/v1/sos_alerts`)
        .then(res => {
          if (res.data.success) {
            setSosAlerts(res.data.data);
          }
        })
        .catch(err => console.error("Error fetching SOS alerts", err));
    }, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleResolveSOS = (id) => {
    const baseUrl = window.location.origin.includes('localhost') ? 'http://127.0.0.1:5000' : window.location.origin;
    axios.post(`${baseUrl}/api/v1/sos_alerts/${id}/resolve`)
      .then(res => {
        if (res.data.success) {
          setSosAlerts(prev => prev.filter(a => a.id !== id));
        }
      })
      .catch(err => console.error("Error resolving SOS alert", err));
  };

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

      {/* SOS ALERTS MODAL */}
      {sosAlerts.length > 0 && (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/80 backdrop-blur-sm">
          <div className="bg-red-600 w-full max-w-3xl rounded-2xl shadow-[0_0_50px_rgba(255,0,0,0.5)] border-4 border-red-400 p-8 m-4 animate-pulse">
            <div className="flex items-center gap-4 mb-6 text-white border-b border-red-500 pb-4">
              <AlertTriangle size={48} className="animate-bounce" />
              <h2 className="text-3xl font-black uppercase tracking-widest">Cảnh báo SOS Khẩn cấp!</h2>
            </div>
            
            <div className="space-y-4">
              {sosAlerts.map(alert => (
                <div key={alert.id} className="bg-white/10 rounded-xl p-6 flex flex-col gap-4">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="text-xl font-bold text-white mb-2">Hành khách: {alert.passenger_name || 'Không rõ'}</h3>
                      <p className="text-red-200 text-sm font-bold">SĐT: {alert.passenger_phone || 'Không rõ'}</p>
                      <p className="text-white mt-3 italic text-lg">"{alert.message}"</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-red-300 font-mono mb-2">Thời gian: {new Date(alert.created_at).toLocaleString('vi-VN')}</p>
                      <a 
                        href={`https://maps.google.com/?q=${alert.latitude},${alert.longitude}`}
                        target="_blank" rel="noreferrer"
                        className="inline-flex items-center gap-2 bg-white text-red-600 px-4 py-2 rounded-lg font-bold hover:bg-red-50 transition-colors"
                      >
                        <MapPin size={18} />
                        Xem Vị Trí (GPS)
                      </a>
                    </div>
                  </div>
                  <button 
                    onClick={() => handleResolveSOS(alert.id)}
                    className="w-full mt-2 bg-red-800 hover:bg-red-900 text-white font-black py-4 rounded-xl uppercase tracking-widest shadow-inner transition-colors"
                  >
                    Đã Tiếp Nhận & Đang Xử Lý Hỗ Trợ
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminLayout;
