import React, { useState, useEffect } from 'react';
import { Bus, Plus, Search, Trash2, Edit2, RefreshCw, XCircle, Info, Palette, Layers, ChevronDown } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const BUS_TYPES = [
  { value: 'standard_sleeper', label: 'Giường nằm Phổ thông (40-44 chỗ)' },
  { value: 'vip_34', label: 'Limousine 34 Giường VIP' },
  { value: 'luxury_cabin', label: 'Cabin Cung điện (22 cabin)' },
  { value: 'chair_limo', label: 'Ghế ngồi / Limousine ghế (9-29 chỗ)' }
];

const BusModal = ({ onClose, onSaved, currentBus = null }) => {
  const [formData, setFormData] = useState({
    license_plate: '',
    bus_type: 'vip_34',
    color: 'Xanh HUTECH',
    total_seats: 34
  });

  useEffect(() => {
    if (currentBus) {
      setFormData({
        license_plate: currentBus.license_plate || '',
        bus_type: currentBus.type || 'vip_34',
        color: currentBus.color || 'Xanh HUTECH',
        total_seats: currentBus.total_seats || 34
      });
    }
  }, [currentBus]);

  // Automatically adjust seats based on type selection for better UX
  const handleTypeChange = (e) => {
    const type = e.target.value;
    let defaultSeats = 34;
    if (type === 'standard_sleeper') defaultSeats = 40;
    if (type === 'luxury_cabin') defaultSeats = 22;
    if (type === 'chair_limo') defaultSeats = 16;
    
    setFormData({
      ...formData,
      bus_type: type,
      total_seats: defaultSeats
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const method = currentBus ? 'PUT' : 'POST';
    const url = currentBus ? `/api/admin/buses/${currentBus.id}` : '/api/admin/buses';
    
    try {
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      if (res.ok) {
        onSaved();
      } else {
        const data = await res.json();
        alert('Lỗi: ' + data.error);
      }
    } catch (err) {
      alert('Lỗi kết nối máy chủ!');
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[110] flex items-center justify-center p-6">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }} 
        animate={{ opacity: 1, scale: 1 }} 
        exit={{ opacity: 0, scale: 0.95 }}
        className="bg-white w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden"
      >
        <div className="bg-[#f8f9fa] px-6 py-4 border-b border-slate-200 flex justify-between items-center">
           <h2 className="text-lg font-black text-slate-800 flex items-center gap-3 uppercase">
              <Bus className="text-[#EF5222]" size={20} /> {currentBus ? 'Cập nhật thông tin xe' : 'Thêm xe mới vào đội'}
           </h2>
           <button onClick={onClose} className="text-slate-400 hover:text-slate-600 transition-colors"><XCircle size={24} /></button>
        </div>
        
        <form onSubmit={handleSubmit} className="p-8 space-y-6">
          <div className="space-y-1.5">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Biển số xe</label>
            <input 
              type="text" 
              placeholder="Ví dụ: 51B-123.45"
              className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm transition-all" 
              required
              value={formData.license_plate} 
              onChange={e => setFormData({...formData, license_plate: e.target.value})} 
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Loại xe vận hành</label>
            <select 
              className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm transition-all"
              required
              value={formData.bus_type} 
              onChange={handleTypeChange}
            >
              {BUS_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
            </select>
          </div>

          <div className="grid grid-cols-2 gap-6">
             <div className="space-y-1.5">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Màu sắc / Nhận diện</label>
                <input 
                  type="text" 
                  className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm transition-all" 
                  placeholder="Xanh lá, Đỏ trắng..."
                  required
                  value={formData.color} 
                  onChange={e => setFormData({...formData, color: e.target.value})} 
                />
             </div>
             <div className="space-y-1.5">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Số lượng ghế thiết kế</label>
                <input 
                  type="number" 
                  className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-black text-orange-600 outline-none focus:border-orange-400 shadow-sm transition-all" 
                  min="4"
                  max="60"
                  required
                  value={formData.total_seats} 
                  onChange={e => setFormData({...formData, total_seats: e.target.value})} 
                />
             </div>
          </div>

          <div className="flex gap-4 pt-4">
            <button type="button" onClick={onClose} className="flex-1 py-3 font-bold text-slate-500 hover:bg-slate-50 rounded-xl transition-all uppercase text-xs tracking-widest">Hủy bỏ</button>
            <button type="submit" className="flex-[2] py-3 bg-[#EF5222] text-white font-black rounded-xl shadow-lg shadow-orange-100 hover:bg-[#D43D11] transition-all uppercase text-xs tracking-widest">Lưu thông tin</button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};

const Buses = () => {
  const [buses, setBuses] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingBus, setEditingBus] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');

  const fetchBuses = () => {
    setIsLoading(true);
    fetch('/api/admin/buses')
      .then(res => res.json())
      .then(data => {
        setBuses(Array.isArray(data) ? data : []);
        setIsLoading(false);
      })
      .catch(() => setIsLoading(false));
  };

  useEffect(() => {
    fetchBuses();
  }, []);

  const handleDelete = async (id, plate) => {
    if (!window.confirm(`Bạn có chắc muốn xóa xe mang biển số ${plate} khỏi đội xe?`)) return;
    try {
      const res = await fetch(`/api/admin/buses/${id}`, { method: 'DELETE' });
      if (res.ok) {
        fetchBuses();
      } else {
        const data = await res.json();
        alert('Lỗi: ' + data.error);
      }
    } catch (err) {
      alert('Lỗi kết nối máy chủ!');
    }
  };

  const handleEdit = (bus) => {
    setEditingBus(bus);
    setShowModal(true);
  };

  const getBusTypeLabel = (type) => {
    const found = BUS_TYPES.find(t => t.value === type);
    return found ? found.label.split(' (')[0] : type;
  };

  const filteredBuses = buses.filter(b => 
    b.license_plate?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    b.type?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    b.color?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="flex flex-col gap-0 -m-4 bg-white min-h-screen font-sans text-slate-700">
      <AnimatePresence>
         {showModal && (
            <BusModal 
              currentBus={editingBus} 
              onClose={() => { setShowModal(false); setEditingBus(null); }} 
              onSaved={() => { setShowModal(false); setEditingBus(null); fetchBuses(); }} 
            />
         )}
      </AnimatePresence>
      
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex flex-wrap items-center gap-4 sticky top-0 z-50 shadow-sm">
        <div className="relative flex-1 max-w-md group">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-orange-500 transition-colors" size={16} />
          <input 
            type="text" 
            placeholder="Tìm biển số, loại xe, màu sắc..." 
            className="w-full bg-[#f8f9fa] border border-slate-200 rounded py-2 pl-10 pr-4 text-xs font-bold text-slate-700 focus:border-orange-400 transition-all outline-none" 
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
          />
        </div>
        
        <div className="flex gap-2 ml-auto">
           <button 
             onClick={() => setShowModal(true)} 
             className="bg-[#EF5222] text-white px-5 py-2 rounded-md text-xs font-black flex items-center gap-2 hover:bg-[#D43D11] shadow-md shadow-orange-100 transition-all uppercase tracking-widest"
           >
              <Plus size={14} /> Thêm xe mới
           </button>
           <button onClick={fetchBuses} className="bg-white border border-slate-200 text-slate-500 px-5 py-2 rounded-md text-xs font-bold flex items-center gap-2 hover:bg-slate-50 transition-all">
              <RefreshCw size={14} /> Làm mới
           </button>
        </div>
      </div>

      <div className="px-6 py-4 bg-white border-b border-slate-100 flex items-center gap-4 shadow-sm">
         <span className="text-[12px] font-black text-slate-800 uppercase tracking-widest border-r border-slate-200 pr-4">ĐỘI XE VẬN HÀNH</span>
         <div className="flex gap-6 text-[11px] font-bold text-slate-500 overflow-x-auto no-scrollbar">
            <span>Tổng phương tiện: <span className="text-slate-900 font-black">{buses.length}</span></span>
            <span>Đang hoạt động: <span className="text-green-600 font-black">{buses.length}</span></span>
         </div>
      </div>

      <div className="flex-1 bg-white overflow-hidden m-6 rounded shadow-sm border border-slate-200">
        <div className="overflow-x-auto h-full">
          <table className="w-full text-left border-collapse min-w-[1000px]">
            <thead className="bg-[#f8fafc] text-[10px] font-black text-slate-500 uppercase border-b border-slate-200 sticky top-0 z-10">
              <tr>
                <th className="px-4 py-4 w-12 text-center border-r border-slate-100 bg-[#f8fafc]">STT</th>
                <th className="px-6 py-4 w-52 border-r border-slate-100">Biển số xe</th>
                <th className="px-6 py-4 border-r border-slate-100">Dòng xe / Phân khúc <ChevronDown size={10} className="inline ml-1" /></th>
                <th className="px-6 py-4 w-48 border-r border-slate-100">Số lượng ghế</th>
                <th className="px-6 py-4 w-48 border-r border-slate-100">Màu sắc / Nhận diện</th>
                <th className="px-6 py-4 w-36 border-r border-slate-100 text-center">Trạng thái</th>
                <th className="px-6 py-4 text-center">Tác vụ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr><td colSpan="7" className="text-center py-24 text-slate-300 font-black italic animate-pulse tracking-widest uppercase text-xs">Đang tải danh sách phương tiện...</td></tr>
              ) : filteredBuses.length === 0 ? (
                <tr><td colSpan="7" className="text-center py-32">
                   <div className="flex flex-col items-center gap-3 text-slate-300">
                      <Bus size={64} strokeWidth={1} />
                      <span className="font-black italic uppercase text-xs tracking-widest">Không tìm thấy phương tiện nào</span>
                   </div>
                </td></tr>
              ) : filteredBuses.map((bus, idx) => (
                <tr key={bus.id} className="hover:bg-blue-50/30 transition-colors text-xs font-bold text-slate-600 group">
                  <td className="px-4 py-4 text-center border-r border-slate-50 text-slate-300 font-medium">{idx + 1}</td>
                  
                  <td className="px-6 py-4 border-r border-slate-50">
                    <div className="inline-flex items-center justify-center px-4 py-2 border-2 border-slate-800 rounded bg-slate-50 text-slate-900 font-black text-sm tracking-wider shadow-sm uppercase font-mono">
                      {bus.license_plate}
                    </div>
                  </td>
                  
                  <td className="px-6 py-4 border-r border-slate-50">
                    <div className="flex items-center gap-3">
                       <div className="w-8 h-8 bg-orange-50 text-orange-600 rounded flex items-center justify-center group-hover:bg-[#EF5222] group-hover:text-white transition-all shadow-sm">
                          <Bus size={16} />
                       </div>
                       <div>
                          <span className="font-black text-slate-800 text-sm uppercase block">{getBusTypeLabel(bus.type)}</span>
                          <span className="text-[10px] text-slate-400 font-mono font-bold uppercase">{bus.type}</span>
                       </div>
                    </div>
                  </td>
                  
                  <td className="px-6 py-4 border-r border-slate-50">
                    <div className="flex items-center gap-2">
                       <Layers size={14} className="text-slate-400" />
                       <div>
                          <span className="text-slate-900 font-black text-sm">{bus.total_seats}</span>
                          <span className="text-[10px] text-slate-400 block font-bold uppercase">Giường / Ghế</span>
                       </div>
                    </div>
                  </td>

                  <td className="px-6 py-4 border-r border-slate-50">
                    <div className="flex items-center gap-2">
                       <Palette size={14} className="text-slate-400" />
                       <div>
                          <span className="text-slate-800 font-black text-sm uppercase">{bus.color}</span>
                          <span className="text-[9px] text-slate-400 block font-bold uppercase">Nhãn nhận diện</span>
                       </div>
                    </div>
                  </td>
                  
                  <td className="px-6 py-4 border-r border-slate-100 text-center">
                    <span className="text-[9px] font-black uppercase px-3 py-1 rounded border border-green-200 bg-green-50 text-green-700 tracking-widest shadow-sm">Hoạt động</span>
                  </td>
                  
                  <td className="px-6 py-4">
                     <div className="flex items-center justify-center gap-1.5 opacity-40 group-hover:opacity-100 transition-opacity">
                        <button 
                          onClick={() => handleEdit(bus)} 
                          className="w-8 h-8 bg-blue-500 text-white rounded flex items-center justify-center hover:bg-blue-600 shadow-md transition-all active:scale-90"
                          title="Sửa xe"
                        >
                          <Edit2 size={14} />
                        </button>
                        <button 
                          onClick={() => handleDelete(bus.id, bus.license_plate)} 
                          className="w-8 h-8 bg-red-500 text-white rounded flex items-center justify-center hover:bg-red-600 shadow-md transition-all active:scale-90"
                          title="Xóa xe"
                        >
                          <Trash2 size={14} />
                        </button>
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

export default Buses;
