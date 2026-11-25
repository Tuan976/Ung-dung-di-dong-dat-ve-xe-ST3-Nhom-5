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
  AlertTriangle,
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
        flex items-center gap-2 px-3.5 py-2 rounded-xl transition-all text-xs font-bold
        ${
          isActive
            ? 'bg-[#FF6B00] text-white shadow-xs'
            : 'text-[#778196] hover:bg-[#F7F8FA] hover:text-[#202938]'
        }
      `}
    >
      <Icon size={15} />
      <span>{label}</span>
    </NavLink>
  );
};

const AdminLayout = ({ children }) => {
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const [sosAlerts, setSosAlerts] = useState([]);

  useEffect(() => {
    const interval = setInterval(() => {
      const baseUrl = window.location.origin.includes('localhost')
        ? 'http://127.0.0.1:5000'
        : window.location.origin;
      axios
        .get(`${baseUrl}/api/v1/sos_alerts`)
        .then(res => {
          if (res.data.success) {
            setSosAlerts(res.data.data);
          }
        })
        .catch(err => console.error('Error fetching SOS alerts', err));
    }, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleResolveSOS = id => {
    const baseUrl = window.location.origin.includes('localhost')
      ? 'http://127.0.0.1:5000'
      : window.location.origin;
    axios
      .post(`${baseUrl}/api/v1/sos_alerts/${id}/resolve`)
      .then(res => {
        if (res.data.success) {
          setSosAlerts(prev => prev.filter(a => a.id !== id));
        }
      })
      .catch(err => console.error('Error resolving SOS alert', err));
  };

  const handleLogout = () => {
    localStorage.removeItem('user');
    window.location.href = '/auth';
  };

  return (
    <div className="dashboard-container bg-[#F7F8FA] min-h-screen flex flex-col">
      <header className="h-16 bg-white border-b border-[#E7EAF0] text-[#202938] flex items-center justify-between px-6 sticky top-0 z-50">
        <div className="flex items-center gap-6 overflow-x-auto">
          <div className="flex items-center gap-2.5 shrink-0">
            <div className="bg-[#FF6B00] p-2 rounded-xl text-white">
              <Bus size={18} />
            </div>
            <div>
              <span className="text-lg font-black tracking-tight text-[#202938]">
                TRIP<span className="text-[#FF6B00]">LY</span>
              </span>
              <span className="ml-1.5 rounded-md bg-[#FFF1E6] px-1.5 py-0.5 text-[10px] font-extrabold text-[#FF6B00]">
                OPERATOR
              </span>
            </div>
          </div>

          <nav className="flex items-center gap-1.5">
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

        <div className="flex items-center gap-4 shrink-0">
          <div className="text-right pr-3 border-r border-[#E7EAF0]">
            <div className="text-xs font-extrabold text-[#202938] truncate max-w-[140px]">
              {user.name || 'Quản trị viên'}
            </div>
            <div className="text-[10px] font-bold text-[#FF6B00] uppercase">
              {user.staff_role || user.role}
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-[#FDECEC] hover:bg-[#DC4545] text-[#DC4545] hover:text-white rounded-xl transition-all text-xs font-bold cursor-pointer"
          >
            <LogOut size={14} />
            Đăng xuất
          </button>
        </div>
      </header>

      <main className="flex-1 p-4 sm:p-6 overflow-auto">
        <div className="max-w-[1600px] mx-auto">{children}</div>
      </main>

      {/* SOS ALERTS MODAL */}
      {sosAlerts.length > 0 && (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-[#202938]/70 backdrop-blur-xs">
          <div className="bg-white w-full max-w-2xl rounded-2xl shadow-2xl border-2 border-[#DC4545] p-6 m-4">
            <div className="flex items-center gap-3 mb-4 text-[#DC4545] border-b border-[#E7EAF0] pb-4">
              <AlertTriangle size={32} />
              <h2 className="text-xl font-black uppercase">Cảnh báo SOS Khẩn cấp</h2>
            </div>

            <div className="space-y-4">
              {sosAlerts.map(alert => (
                <div key={alert.id} className="bg-[#FDECEC] border border-[#F8C6C6] rounded-xl p-5 flex flex-col gap-3">
                  <div className="flex justify-between items-start gap-4">
                    <div>
                      <h3 className="text-base font-extrabold text-[#202938]">
                        Hành khách: {alert.passenger_name || 'Không rõ'}
                      </h3>
                      <p className="text-[#DC4545] text-xs font-bold mt-0.5">
                        SĐT: {alert.passenger_phone || 'Không rõ'}
                      </p>
                      <p className="text-[#202938] mt-2 font-medium text-sm">"{alert.message}"</p>
                    </div>
                    <div className="text-right shrink-0">
                      <p className="text-xs text-[#778196] mb-2">
                        {new Date(alert.created_at).toLocaleString('vi-VN')}
                      </p>
                      <a
                        href={`https://maps.google.com/?q=${alert.latitude},${alert.longitude}`}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1.5 bg-white border border-[#E7EAF0] text-[#FF6B00] px-3 py-1.5 rounded-lg text-xs font-bold hover:border-[#FF6B00]"
                      >
                        <MapPin size={14} />
                        Xem Vị Trí GPS
                      </a>
                    </div>
                  </div>
                  <button
                    onClick={() => handleResolveSOS(alert.id)}
                    className="w-full bg-[#DC4545] hover:bg-red-700 text-white font-bold py-2.5 rounded-xl text-sm transition-colors cursor-pointer"
                  >
                    Đã Tiếp Nhận & Xử Lý Hỗ Trợ
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
