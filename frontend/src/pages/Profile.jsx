import React, { useState, useEffect } from 'react';
import { User, Mail, Phone, MapPin, Edit3, Save } from 'lucide-react';
import { useNavigate, Link } from 'react-router-dom';

const Profile = () => {
  const [user, setUser] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({});
  const navigate = useNavigate();

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      const parsed = JSON.parse(userStr);
      setUser(parsed);
      setFormData(parsed);
    } else {
      navigate('/auth');
    }
  }, [navigate]);

  if (!user) return null;

  const handleSave = () => {
    // In a real app, this would be an API call
    localStorage.setItem('user', JSON.stringify(formData));
    setUser(formData);
    setIsEditing(false);
    alert('Cập nhật thông tin thành công!');
  };

  return (
    <div className="min-h-screen bg-slate-50 pt-32 pb-12 flex justify-center w-full">
      <div className="max-w-4xl w-full px-6">
        <h1 className="text-3xl font-black text-slate-800 mb-8 uppercase tracking-tight">Tài khoản của tôi</h1>
        
        <div className="bg-white rounded-3xl shadow-xl overflow-hidden">
          <div className="h-32 bg-gradient-to-r from-[#EF5222] to-[#FF8E53]"></div>
          
          <div className="px-8 pb-8 relative">
            <div className="flex justify-between items-end -mt-16 mb-8">
              <div className="w-32 h-32 bg-white rounded-full p-2 shadow-lg">
                <div className="w-full h-full bg-slate-100 rounded-full flex items-center justify-center text-[#EF5222]">
                  <User size={48} />
                </div>
              </div>
              
              {isEditing ? (
                <button 
                  onClick={handleSave}
                  className="bg-[#EF5222] hover:bg-[#D43D11] text-white px-6 py-2 rounded-full font-bold flex items-center gap-2 transition-colors shadow-lg shadow-orange-200"
                >
                  <Save size={18} /> Lưu thay đổi
                </button>
              ) : (
                <button 
                  onClick={() => setIsEditing(true)}
                  className="bg-slate-100 hover:bg-slate-200 text-slate-700 px-6 py-2 rounded-full font-bold flex items-center gap-2 transition-colors"
                >
                  <Edit3 size={18} /> Cập nhật
                </button>
              )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="space-y-6">
                <div>
                  <label className="block text-sm font-bold text-slate-500 mb-2">Họ và tên</label>
                  <div className="flex items-center gap-3 bg-slate-50 p-4 rounded-xl border border-slate-100 focus-within:border-[#EF5222] focus-within:ring-2 focus-within:ring-[#EF5222]/10 transition-all">
                    <User size={20} className={isEditing ? "text-[#EF5222]" : "text-slate-400"} />
                    <input 
                      type="text" 
                      value={formData.name || ''} 
                      onChange={e => setFormData({...formData, name: e.target.value})}
                      readOnly={!isEditing}
                      className="bg-transparent w-full font-bold text-slate-800 focus:outline-none"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-bold text-slate-500 mb-2">Số điện thoại</label>
                  <div className="flex items-center gap-3 bg-slate-50 p-4 rounded-xl border border-slate-100 focus-within:border-[#EF5222] focus-within:ring-2 focus-within:ring-[#EF5222]/10 transition-all">
                    <Phone size={20} className={isEditing ? "text-[#EF5222]" : "text-slate-400"} />
                    <input 
                      type="text" 
                      value={formData.phone || ''} 
                      onChange={e => setFormData({...formData, phone: e.target.value.replace(/\D/g, '')})}
                      readOnly={!isEditing}
                      className="bg-transparent w-full font-bold text-slate-800 focus:outline-none"
                    />
                  </div>
                </div>
              </div>

              <div className="space-y-6">
                <div>
                  <label className="block text-sm font-bold text-slate-500 mb-2">Email</label>
                  <div className="flex items-center gap-3 bg-slate-50 p-4 rounded-xl border border-slate-100 focus-within:border-[#EF5222] focus-within:ring-2 focus-within:ring-[#EF5222]/10 transition-all">
                    <Mail size={20} className={isEditing ? "text-[#EF5222]" : "text-slate-400"} />
                    <input 
                      type="email" 
                      value={formData.email || ''} 
                      onChange={e => setFormData({...formData, email: e.target.value})}
                      readOnly={!isEditing}
                      className="bg-transparent w-full font-bold text-slate-800 focus:outline-none"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-bold text-slate-500 mb-2">Địa chỉ</label>
                  <div className="flex items-center gap-3 bg-slate-50 p-4 rounded-xl border border-slate-100 focus-within:border-[#EF5222] focus-within:ring-2 focus-within:ring-[#EF5222]/10 transition-all">
                    <MapPin size={20} className={isEditing ? "text-[#EF5222]" : "text-slate-400"} />
                    <input 
                      type="text" 
                      placeholder={isEditing ? "Nhập địa chỉ của bạn" : "Chưa cập nhật"}
                      value={formData.address || ''}
                      onChange={e => setFormData({...formData, address: e.target.value})}
                      readOnly={!isEditing}
                      className="bg-transparent w-full font-bold text-slate-800 focus:outline-none"
                    />
                  </div>
                </div>
              </div>
            </div>
            
            <div className="mt-12 pt-8 border-t border-slate-100">
              <h3 className="text-xl font-bold text-slate-800 mb-6">Lịch sử đặt vé</h3>
              <div className="bg-slate-50 rounded-xl p-8 text-center text-slate-500 font-medium border border-slate-100 border-dashed">
                Bạn chưa có chuyến đi nào. <Link to="/" className="text-[#EF5222] hover:underline font-bold">Đặt vé ngay!</Link>
              </div>
            </div>
            
          </div>
        </div>
      </div>
    </div>
  );
};

export default Profile;
