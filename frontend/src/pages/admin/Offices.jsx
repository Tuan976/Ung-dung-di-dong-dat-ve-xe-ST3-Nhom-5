import React, { useState, useEffect } from 'react';
import { MapPin, Search, Plus, Edit2, Trash2, Phone, Home, RefreshCw } from 'lucide-react';
import { motion } from 'framer-motion';

const AdminOffices = () => {
  const [offices, setOffices] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [currentOffice, setCurrentOffice] = useState(null);
  const [formData, setFormData] = useState({ name: '', address: '', phone: '' });

  const fetchOffices = async () => {
    setIsLoading(true);
    try {
      const res = await fetch('/api/admin/offices');
      const data = await res.json();
      setOffices(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchOffices();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    const method = currentOffice ? 'PUT' : 'POST';
    const url = currentOffice ? `/api/admin/offices/${currentOffice.id}` : '/api/admin/offices';
    
    try {
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      if (res.ok) {
        setShowModal(false);
        fetchOffices();
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Bạn có chắc chắn muốn xóa văn phòng này?')) return;
    try {
      const res = await fetch(`/api/admin/offices/${id}`, { method: 'DELETE' });
      if (res.ok) fetchOffices();
    } catch (err) {
      console.error(err);
    }
  };

  const openEdit = (office) => {
    setCurrentOffice(office);
    setFormData({ name: office.name, address: office.address, phone: office.phone });
    setShowModal(true);
  };

  const openAdd = () => {
    setCurrentOffice(null);
    setFormData({ name: '', address: '', phone: '' });
    setShowModal(true);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-black text-slate-800">Quản lý Văn phòng</h1>
          <p className="text-sm text-slate-500">Danh sách các điểm giao nhận và văn phòng của Hutech Bus.</p>
        </div>
        <button onClick={openAdd} className="bg-orange-500 text-white px-6 py-2 rounded-lg font-bold flex items-center gap-2 hover:bg-orange-600 transition-all shadow-lg shadow-orange-100">
          <Plus size={20} /> Thêm văn phòng
        </button>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <div className="p-4 border-b border-slate-50 flex items-center justify-between">
           <div className="relative w-80">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
              <input type="text" placeholder="Tìm kiếm văn phòng..." className="w-full bg-slate-50 border-none rounded-xl py-2 pl-10 pr-4 text-sm outline-none focus:ring-2 focus:ring-blue-100" />
           </div>
           <button onClick={fetchOffices} className="p-2 text-slate-400 hover:text-blue-500 hover:bg-blue-50 rounded-lg transition-all">
              <RefreshCw size={20} />
           </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead className="bg-slate-50 text-[10px] uppercase font-black text-slate-400 tracking-widest">
              <tr>
                <th className="px-6 py-4">Tên văn phòng</th>
                <th className="px-6 py-4">Địa chỉ</th>
                <th className="px-6 py-4">Số điện thoại</th>
                <th className="px-6 py-4 text-center">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {isLoading ? (
                <tr><td colSpan="4" className="text-center py-20 text-slate-300 font-bold italic">Đang tải dữ liệu...</td></tr>
              ) : offices.length === 0 ? (
                <tr><td colSpan="4" className="text-center py-20 text-slate-300 font-bold italic">Chưa có văn phòng nào.</td></tr>
              ) : offices.map(office => (
                <tr key={office.id} className="hover:bg-slate-50 transition-colors">
                  <td className="px-6 py-4 font-bold text-slate-700">{office.name}</td>
                  <td className="px-6 py-4 text-sm text-slate-500 flex items-center gap-2"><MapPin size={14} className="text-blue-400" /> {office.address}</td>
                  <td className="px-6 py-4 text-sm font-bold text-slate-600 flex items-center gap-2"><Phone size={14} className="text-green-500" /> {office.phone}</td>
                  <td className="px-6 py-4">
                    <div className="flex items-center justify-center gap-2">
                       <button onClick={() => openEdit(office)} className="w-8 h-8 bg-blue-50 text-blue-600 rounded-lg flex items-center justify-center hover:bg-blue-600 hover:text-white transition-all"><Edit2 size={14} /></button>
                       <button onClick={() => handleDelete(office.id)} className="w-8 h-8 bg-red-50 text-red-600 rounded-lg flex items-center justify-center hover:bg-red-600 hover:text-white transition-all"><Trash2 size={14} /></button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[200] flex items-center justify-center p-6">
          <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="bg-white w-full max-w-md rounded-3xl shadow-2xl p-8">
             <h2 className="text-xl font-black text-slate-800 mb-6">{currentOffice ? 'Cập nhật văn phòng' : 'Thêm văn phòng mới'}</h2>
             <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                   <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest block mb-2">Tên văn phòng</label>
                   <input type="text" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400" required 
                     value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
                </div>
                <div>
                   <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest block mb-2">Địa chỉ</label>
                   <input type="text" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400" required 
                     value={formData.address} onChange={e => setFormData({...formData, address: e.target.value})} />
                </div>
                <div>
                   <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest block mb-2">Số điện thoại</label>
                   <input type="tel" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400" required 
                     value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
                </div>
                <div className="flex gap-4 pt-4">
                   <button type="button" onClick={() => setShowModal(false)} className="flex-1 py-3 font-bold text-slate-500 hover:bg-slate-50 rounded-xl transition-all">Hủy</button>
                   <button type="submit" className="flex-1 py-3 bg-blue-600 text-white font-bold rounded-xl shadow-lg shadow-blue-100 hover:bg-blue-700 transition-all uppercase tracking-widest text-xs">Lưu lại</button>
                </div>
             </form>
          </motion.div>
        </div>
      )}
    </div>
  );
};

export default AdminOffices;
