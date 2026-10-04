import React, { useState, useEffect } from 'react';
import { Users, UserPlus, Search, Filter, Mail, Phone, Shield, MoreVertical, CreditCard, X, Save, Trash2, Edit2, Key, CheckCircle2, AlertCircle, RefreshCw, MapPin, ChevronDown, XCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const StaffModal = ({ onClose, onSaved, currentStaff = null }) => {
  const [formData, setFormData] = useState({
    name: '', email: '', phone: '', role: 'STATION_STAFF', status: 'Active', password: '', license_number: ''
  });

  useEffect(() => {
    if (currentStaff) {
      setFormData({
        id: currentStaff.id,
        name: currentStaff.name || '',
        email: currentStaff.email || '',
        phone: currentStaff.phone || '',
        role: currentStaff.role || 'STATION_STAFF',
        status: currentStaff.status || 'Active',
        password: '',
        license_number: currentStaff.license_number || ''
      });
    }
  }, [currentStaff]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    const method = currentStaff ? 'PUT' : 'POST';
    try {
      const res = await fetch('/api/admin/staff', {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      if (res.ok) onSaved();
      else alert('Lỗi: ' + (await res.json()).error);
    } catch (err) { alert('Lỗi kết nối máy chủ'); }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[110] flex items-center justify-center p-4">
      <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="bg-white w-full max-w-md rounded-lg shadow-2xl overflow-hidden">
        <div className="bg-[#f8f9fa] px-6 py-4 border-b border-slate-200 flex justify-between items-center">
          <h2 className="text-lg font-bold text-slate-800 flex items-center gap-3 uppercase">
             <UserPlus className="text-orange-500" size={20} />
             {currentStaff ? 'Cập nhật nhân sự' : 'Thêm nhân sự mới'}
          </h2>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600 transition-colors"><XCircle size={24} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-5">
           <div className="space-y-1">
              <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Họ và tên</label>
              <input type="text" className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
           </div>
           <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                 <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Số điện thoại</label>
                 <input type="tel" className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value.replace(/\D/g, '')})} />
              </div>
              <div className="space-y-1">
                 <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Vai trò</label>
                 <select className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" value={formData.role} onChange={e => setFormData({...formData, role: e.target.value})}>
                    <option value="STATION_STAFF">Nhân viên trạm</option>
                    <option value="TICKET_OFFICE">Nhân viên bán vé</option>
                    <option value="DRIVER">Tài xế</option>
                    <option value="ASSISTANT">Phụ xe</option>
                    <option value="ADMIN">Quản trị viên</option>
                 </select>
              </div>
           </div>
           <div className="space-y-1">
              <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Email / Tài khoản</label>
              <input type="email" className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
           </div>
           <div className="space-y-1">
              <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Mật khẩu {currentStaff && '(Bỏ trống nếu không đổi)'}</label>
              <div className="relative">
                 <Key className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-300" size={16} />
                 <input type="password" placeholder={currentStaff ? "••••••••" : "Nhập mật khẩu"} className="w-full bg-white border border-slate-200 rounded py-2 pl-10 pr-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required={!currentStaff} value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
              </div>
           </div>
           {formData.role === 'DRIVER' && (
              <div className="space-y-1">
                 <label className="text-[10px] font-black text-blue-500 uppercase tracking-widest ml-1">Số bằng lái (GPLX)</label>
                 <input type="text" className="w-full bg-blue-50 border border-blue-100 rounded py-2 px-3 text-sm font-bold text-blue-700 outline-none focus:border-blue-400" placeholder="Nhập số bằng lái..." value={formData.license_number} onChange={e => setFormData({...formData, license_number: e.target.value})} />
              </div>
           )}
           <div className="pt-4 flex gap-3">
              <button type="button" onClick={onClose} className="flex-1 py-2.5 rounded font-bold text-slate-500 hover:bg-slate-100 transition-all">Hủy</button>
              <button type="submit" className="flex-1 py-2.5 rounded font-bold bg-orange-500 text-white shadow-md hover:bg-orange-600 transition-all flex items-center justify-center gap-2 uppercase text-sm tracking-wider">
                 <Save size={18} /> Lưu nhân sự
              </button>
           </div>
        </form>
      </motion.div>
    </div>
  );
};

const Staff = () => {
  const [staff, setStaff] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingStaff, setEditingStaff] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState('ALL');

  const fetchStaff = () => {
    setIsLoading(true);
    fetch(`/api/admin/staff/${activeTab}`).then(res => res.json()).then(data => { setStaff(Array.isArray(data) ? data : []); setIsLoading(false); }).catch(() => setIsLoading(false));
  };

  useEffect(() => { fetchStaff(); }, [activeTab]);

  const handleDelete = async (id) => {
    if (!window.confirm('Xóa nhân viên này?')) return;
    await fetch('/api/admin/staff', { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id }) });
    fetchStaff();
  };

  const filteredStaff = staff.filter(s => s.name?.toLowerCase().includes(searchTerm.toLowerCase()) || s.phone?.includes(searchTerm) || s.email?.toLowerCase().includes(searchTerm.toLowerCase()));

  return (
    <div className="flex flex-col gap-0 -m-4 bg-white min-h-screen font-sans text-slate-700">
      <AnimatePresence>
        {showModal && (
          <StaffModal 
            currentStaff={editingStaff} 
            onClose={() => { setShowModal(false); setEditingStaff(null); }} 
            onSaved={() => { setShowModal(false); setEditingStaff(null); fetchStaff(); }} 
          />
        )}
      </AnimatePresence>

      <div className="bg-white border-b border-slate-200 px-6 py-4 flex flex-wrap items-center gap-4 sticky top-0 z-50 shadow-sm">
        <div className="flex bg-[#f1f3f5] p-1 rounded-md overflow-x-auto">
           {['ALL', 'DRIVER', 'STATION_STAFF', 'TICKET_OFFICE'].map(tab => (
              <button key={tab} onClick={() => setActiveTab(tab)} className={`px-4 py-1.5 rounded text-[10px] font-black uppercase tracking-widest transition-all ${activeTab === tab ? 'bg-white text-orange-600 shadow-sm' : 'text-slate-400 hover:text-slate-600'}`}>
                 {tab === 'ALL' ? 'Tất cả' : tab === 'STATION_STAFF' ? 'Trạm' : tab === 'TICKET_OFFICE' ? 'Phòng vé' : 'Tài xế'}
              </button>
           ))}
        </div>
        
        <div className="relative flex-1 max-w-md group">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-orange-500 transition-colors" size={16} />
          <input type="text" placeholder="Tìm tên, SĐT, Email..." className="w-full bg-[#f8f9fa] border border-slate-200 rounded py-2 pl-10 pr-4 text-xs font-bold text-slate-700 focus:border-orange-400 transition-all outline-none" value={searchTerm} onChange={e => setSearchTerm(e.target.value)} />
        </div>
        
        <div className="flex gap-2 ml-auto">
           <button onClick={() => setShowModal(true)} className="bg-[#EF5222] text-white px-5 py-2 rounded-md text-xs font-black flex items-center gap-2 hover:bg-[#D43D11] shadow-md shadow-orange-100 transition-all uppercase tracking-widest">
              <UserPlus size={14} /> Thêm nhân sự
           </button>
        </div>
      </div>

      <div className="px-6 py-4 bg-white border-b border-slate-100 flex items-center gap-4 shadow-sm">
         <span className="text-[12px] font-black text-slate-800 uppercase tracking-widest border-r border-slate-200 pr-4">NHÂN SỰ</span>
         <div className="flex gap-6 text-[11px] font-bold text-slate-500 overflow-x-auto no-scrollbar">
            <span>Tổng số: <span className="text-slate-900 font-black">{staff.length}</span></span>
            <span>Đang làm: <span className="text-green-600 font-black">{staff.filter(s => s.status === 'Active').length}</span></span>
            <span>Tài xế: <span className="text-blue-600 font-black">{staff.filter(s => s.role === 'DRIVER').length}</span></span>
         </div>
      </div>

      <div className="flex-1 bg-white overflow-hidden m-6 rounded-lg shadow-xl shadow-slate-200/50 border border-slate-200">
        <div className="overflow-x-auto h-full">
          <table className="w-full text-left border-collapse min-w-[1200px]">
            <thead className="bg-[#f8fafc] text-[10px] font-black text-slate-500 uppercase border-b border-slate-200 sticky top-0 z-10">
              <tr>
                <th className="px-4 py-4 w-12 text-center border-r border-slate-100 bg-[#f8fafc]"><input type="checkbox" className="rounded-sm border-slate-300" /></th>
                <th className="px-4 py-4 border-r border-slate-100">Nhân sự / Liên hệ <ChevronDown size={10} className="inline ml-1" /></th>
                <th className="px-4 py-4 w-40 border-r border-slate-100">Vai trò</th>
                <th className="px-4 py-4 w-40 border-r border-slate-100 text-center">Gia nhập</th>
                <th className="px-4 py-4 w-32 border-r border-slate-100 text-center">Trạng thái</th>
                <th className="px-4 py-4 text-center">Tác vụ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr><td colSpan="6" className="text-center py-20 text-slate-300 font-black italic animate-pulse tracking-widest uppercase text-xs">Đang tải dữ liệu nhân sự...</td></tr>
              ) : filteredStaff.length === 0 ? (
                <tr><td colSpan="6" className="text-center py-24">
                   <div className="flex flex-col items-center gap-3 text-slate-300">
                      <Users size={64} strokeWidth={1} />
                      <span className="font-black italic uppercase text-xs tracking-widest">Không tìm thấy nhân viên</span>
                   </div>
                </td></tr>
              ) : filteredStaff.map((person) => (
                <tr key={person.id} className="hover:bg-blue-50/30 transition-colors text-xs font-bold text-slate-600 group">
                  <td className="px-4 py-4 text-center border-r border-slate-50"><input type="checkbox" className="rounded-sm border-slate-300" /></td>
                  <td className="px-4 py-4 border-r border-slate-50">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded bg-slate-100 flex items-center justify-center font-black text-slate-400">
                        {person.name?.[0] || 'U'}
                      </div>
                      <div>
                        <div className="font-black text-slate-800 text-sm uppercase leading-none mb-1">{person.name}</div>
                        <div className="text-[10px] font-bold text-slate-400 flex items-center gap-3 tracking-tighter uppercase">
                           <span>{person.phone}</span>
                           <span className="text-slate-200">|</span>
                           <span>{person.email}</span>
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50">
                    <div className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded border text-[9px] font-black uppercase tracking-widest ${
                       person.role === 'DRIVER' ? 'bg-blue-50 border-blue-100 text-blue-700' : 
                       person.role === 'ADMIN' ? 'bg-purple-50 border-purple-100 text-purple-700' : 'bg-orange-50 border-orange-100 text-orange-700'
                    }`}>
                       <Shield size={10} /> {person.role}
                    </div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50 text-center">
                    <div className="text-slate-600 font-bold">{person.joined_at}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50 text-center">
                    <div className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full border text-[9px] font-black uppercase tracking-widest ${
                      person.status === 'Active' ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'
                    }`}>
                      {person.status === 'Active' ? 'Đang làm' : 'Đã nghỉ'}
                    </div>
                  </td>
                  <td className="px-4 py-4">
                    <div className="flex items-center justify-center gap-1.5 opacity-60 group-hover:opacity-100 transition-opacity">
                       <button onClick={() => { setEditingStaff(person); setShowModal(true); }} className="w-8 h-8 bg-blue-500 text-white rounded flex items-center justify-center hover:bg-blue-600 shadow transition-all active:scale-90"><Edit2 size={12} /></button>
                       <button onClick={() => handleDelete(person.id)} className="w-8 h-8 bg-red-500 text-white rounded flex items-center justify-center hover:bg-red-600 shadow transition-all active:scale-90"><Trash2 size={12} /></button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Staff;
