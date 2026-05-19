import React from 'react';
import { Navigate, Link } from 'react-router-dom';
import { ShieldAlert } from 'lucide-react';
import { getPermissions } from '../utils/permissions';

const ProtectedRoute = ({ children, permission }) => {
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const permissions = getPermissions(user.role, user.staff_role);
  
  if (!user.role) return <Navigate to="/auth" />;
  if (permissions.includes('ALL') || permissions.includes(permission)) {
    return children;
  }
  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 p-6">
       <div className="bg-white p-12 rounded-[3rem] shadow-xl text-center max-w-md border border-red-100">
          <div className="w-20 h-20 bg-red-50 rounded-full flex items-center justify-center mx-auto mb-6">
             <ShieldAlert className="text-red-500" size={40} />
          </div>
          <h2 className="text-2xl font-black text-slate-800 mb-2 uppercase tracking-tighter">Truy cập bị từ chối</h2>
          <p className="text-slate-500 font-bold mb-8 italic">Tài khoản của bạn không có quyền truy cập vào chức năng này. Vui lòng liên hệ quản trị viên.</p>
          <Link to="/admin" className="bg-slate-900 text-white px-8 py-3 rounded-2xl font-bold shadow-lg shadow-slate-200">Quay lại Tổng quan</Link>
       </div>
    </div>
  );
};

export default ProtectedRoute;
