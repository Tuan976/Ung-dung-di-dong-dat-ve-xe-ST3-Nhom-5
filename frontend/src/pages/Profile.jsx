import React, { useState, useEffect } from 'react';
import { User, Mail, Phone, MapPin, Edit3, Save, Ticket } from 'lucide-react';
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
    localStorage.setItem('user', JSON.stringify(formData));
    setUser(formData);
    setIsEditing(false);
    alert('Cập nhật thông tin thành công!');
  };

  return (
    <div className="min-h-screen bg-[#F7F8FA] py-10 flex justify-center w-full">
      <div className="max-w-4xl w-full px-4 sm:px-6">
        <h1 className="text-2xl font-black text-[#202938] mb-6">Tài khoản cá nhân</h1>

        <div className="bg-white rounded-2xl border border-[#E7EAF0] card-shadow overflow-hidden">
          <div className="h-24 bg-[#FFF1E6] border-b border-[#E7EAF0]"></div>

          <div className="px-6 sm:px-8 pb-8 relative">
            <div className="flex justify-between items-end -mt-12 mb-6">
              <div className="w-24 h-24 bg-white rounded-full p-1.5 border border-[#E7EAF0] shadow-sm">
                <div className="w-full h-full bg-[#FFF1E6] rounded-full flex items-center justify-center text-[#FF6B00]">
                  <User size={40} />
                </div>
              </div>

              {isEditing ? (
                <button
                  onClick={handleSave}
                  className="bg-[#FF6B00] hover:bg-[#E85F00] text-white px-5 py-2 rounded-xl text-sm font-bold flex items-center gap-2 transition-colors cursor-pointer"
                >
                  <Save size={16} /> Lưu thay đổi
                </button>
              ) : (
                <button
                  onClick={() => setIsEditing(true)}
                  className="bg-[#F7F8FA] hover:border-[#FF6B00] hover:text-[#FF6B00] border border-[#E7EAF0] text-[#202938] px-5 py-2 rounded-xl text-sm font-bold flex items-center gap-2 transition-colors cursor-pointer"
                >
                  <Edit3 size={16} /> Chỉnh sửa
                </button>
              )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-xs font-bold text-[#778196] mb-1.5">Họ và tên</label>
                <div className="flex items-center gap-3 bg-[#F7F8FA] px-4 py-3 rounded-xl border border-[#E7EAF0] focus-within:border-[#FF6B00] focus-within:bg-white transition-all">
                  <User size={18} className={isEditing ? 'text-[#FF6B00]' : 'text-[#778196]'} />
                  <input
                    type="text"
                    value={formData.name || ''}
                    onChange={e => setFormData({ ...formData, name: e.target.value })}
                    readOnly={!isEditing}
                    className="bg-transparent w-full text-sm font-bold text-[#202938] focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#778196] mb-1.5">Số điện thoại</label>
                <div className="flex items-center gap-3 bg-[#F7F8FA] px-4 py-3 rounded-xl border border-[#E7EAF0] focus-within:border-[#FF6B00] focus-within:bg-white transition-all">
                  <Phone size={18} className={isEditing ? 'text-[#FF6B00]' : 'text-[#778196]'} />
                  <input
                    type="text"
                    value={formData.phone || ''}
                    onChange={e => setFormData({ ...formData, phone: e.target.value.replace(/\D/g, '') })}
                    readOnly={!isEditing}
                    className="bg-transparent w-full text-sm font-bold text-[#202938] focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#778196] mb-1.5">Email</label>
                <div className="flex items-center gap-3 bg-[#F7F8FA] px-4 py-3 rounded-xl border border-[#E7EAF0] focus-within:border-[#FF6B00] focus-within:bg-white transition-all">
                  <Mail size={18} className={isEditing ? 'text-[#FF6B00]' : 'text-[#778196]'} />
                  <input
                    type="email"
                    value={formData.email || ''}
                    onChange={e => setFormData({ ...formData, email: e.target.value })}
                    readOnly={!isEditing}
                    className="bg-transparent w-full text-sm font-bold text-[#202938] focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#778196] mb-1.5">Địa chỉ</label>
                <div className="flex items-center gap-3 bg-[#F7F8FA] px-4 py-3 rounded-xl border border-[#E7EAF0] focus-within:border-[#FF6B00] focus-within:bg-white transition-all">
                  <MapPin size={18} className={isEditing ? 'text-[#FF6B00]' : 'text-[#778196]'} />
                  <input
                    type="text"
                    placeholder={isEditing ? 'Nhập địa chỉ của bạn' : 'Chưa cập nhật'}
                    value={formData.address || ''}
                    onChange={e => setFormData({ ...formData, address: e.target.value })}
                    readOnly={!isEditing}
                    className="bg-transparent w-full text-sm font-bold text-[#202938] focus:outline-none"
                  />
                </div>
              </div>
            </div>

            <div className="mt-8 pt-6 border-t border-[#E7EAF0]">
              <h3 className="text-base font-extrabold text-[#202938] mb-3">Tra cứu & Quản lý vé</h3>
              <div className="bg-[#F7F8FA] rounded-xl p-6 text-center text-sm text-[#778196] font-medium border border-[#E7EAF0]">
                <Ticket size={24} className="mx-auto mb-2 text-[#FF6B00]" />
                Bạn có thể kiểm tra vé đã đặt tại mục{' '}
                <Link to="/check-ticket" className="text-[#FF6B00] hover:underline font-bold">
                  Tra cứu vé
                </Link>{' '}
                hoặc{' '}
                <Link to="/" className="text-[#FF6B00] hover:underline font-bold">
                  Tìm chuyến xe mới
                </Link>
                .
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Profile;
