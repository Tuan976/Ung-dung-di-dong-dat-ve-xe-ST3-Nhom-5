import React, { useState, useEffect } from 'react';
import { MapPin, Plus, Search, Filter, Trash2, Edit2, Navigation, DollarSign, Clock, Map, ChevronDown, RefreshCw, Download, Printer, Settings2, ArrowRight, XCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const VIETNAM_PROVINCES = [
  "An Giang", "Bà Rịa - Vũng Tàu", "Bắc Giang", "Bắc Kạn", "Bạc Liêu", "Bắc Ninh", "Bến Tre", "Bình Định", "Bình Dương", "Bình Phước", "Bình Thuận", "Cà Mau", "Cần Thơ", "Cao Bằng", "Đà Nẵng", "Đắk Lắk", "Đắk Nông", "Điện Biên", "Đồng Nai", "Đồng Tháp", "Gia Lai", "Hà Giang", "Hà Nam", "Hà Nội", "Hà Tĩnh", "Hải Dương", "Hải Phòng", "Hậu Giang", "Hòa Bình", "Hưng Yên", "Khánh Hòa", "Kiên Giang", "Kon Tum", "Lai Châu", "Lâm Đồng", "Lạng Sơn", "Lào Cai", "Long An", "Nam Định", "Nghệ An", "Ninh Bình", "Ninh Thuận", "Phú Thọ", "Phú Yên", "Quảng Bình", "Quảng Nam", "Quảng Ngãi", "Quảng Ninh", "Quảng Trị", "Sóc Trăng", "Sơn La", "Tây Ninh", "Thái Bình", "Thái Nguyên", "Thanh Hóa", "Thừa Thiên Huế", "Tiền Giang", "TP. Hồ Chí Minh", "Trà Vinh", "Tuyên Quang", "Vĩnh Long", "Vĩnh Phúc", "Yên Bái"
];

const RouteModal = ({ onClose, onSaved, currentRoute = null }) => {
  const [formData, setFormData] = useState({
    start_point: '', end_point: '', distance_km: '', duration_hours: '', base_price: ''
  });

  useEffect(() => {
    if (currentRoute) {
      setFormData({
        start_point: currentRoute.start_point || '',
        end_point: currentRoute.end_point || '',
        distance_km: currentRoute.distance_km || '',
        duration_hours: currentRoute.duration_hours || '',
        base_price: currentRoute.base_price || ''
      });
    }
  }, [currentRoute]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    const method = currentRoute ? 'PUT' : 'POST';
    const url = currentRoute ? `/api/admin/routes/${currentRoute.id}` : '/api/admin/routes';
    
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
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="bg-white w-full max-w-xl rounded-2xl shadow-2xl overflow-hidden">
        <div className="bg-[#f8f9fa] px-6 py-4 border-b border-slate-200 flex justify-between items-center">
           <h2 className="text-lg font-black text-slate-800 flex items-center gap-3 uppercase">
              <Map className="text-orange-500" size={20} /> {currentRoute ? 'Cập nhật tuyến đường' : 'Thiết lập tuyến mới'}
           </h2>
           <button onClick={onClose} className="text-slate-400 hover:text-slate-600 transition-colors"><XCircle size={24} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-8 space-y-6">
          <div className="grid grid-cols-2 gap-6">
             <div className="space-y-1.5">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Điểm khởi hành</label>
                <select className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm transition-all" required
                  value={formData.start_point} onChange={e => setFormData({...formData, start_point: e.target.value})}>
                  <option value="">Chọn tỉnh/thành...</option>
                  {VIETNAM_PROVINCES.map(p => <option key={p} value={p}>{p}</option>)}
                </select>
             </div>
             <div className="space-y-1.5">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Điểm kết thúc</label>
                <select className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm transition-all" required
                  value={formData.end_point} onChange={e => setFormData({...formData, end_point: e.target.value})}>
                  <option value="">Chọn tỉnh/thành...</option>
                  {VIETNAM_PROVINCES.map(p => <option key={p} value={p}>{p}</option>)}
                </select>
             </div>
          </div>
          <div className="grid grid-cols-3 gap-6">
             <div className="space-y-1.5">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Cự ly (km)</label>
                <input type="number" className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm transition-all" required
                  value={formData.distance_km} onChange={e => setFormData({...formData, distance_km: e.target.value})} />
             </div>
             <div className="space-y-1.5">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Thời gian (h)</label>
                <input type="number" step="0.5" className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm transition-all" required
                  value={formData.duration_hours} onChange={e => setFormData({...formData, duration_hours: e.target.value})} />
             </div>
             <div className="space-y-1.5">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Giá cơ bản (đ)</label>
                <input type="number" className="w-full bg-white border border-slate-200 rounded-lg py-3 px-4 font-black text-orange-600 outline-none focus:border-orange-400 shadow-sm transition-all" required
                  value={formData.base_price} onChange={e => setFormData({...formData, base_price: e.target.value})} />
             </div>
          </div>
          <div className="flex gap-4 pt-4">
            <button type="button" onClick={onClose} className="flex-1 py-3 font-bold text-slate-500 hover:bg-slate-50 rounded-xl transition-all uppercase text-xs tracking-widest">Hủy bỏ</button>
            <button type="submit" className="flex-[2] py-3 bg-[#EF5222] text-white font-black rounded-xl shadow-lg shadow-orange-100 hover:bg-[#D43D11] transition-all uppercase text-xs tracking-widest">Lưu tuyến đường</button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};

const Routes = () => {
  const [routes, setRoutes] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingRoute, setEditingRoute] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');

  const fetchRoutes = () => {
    setIsLoading(true);
    fetch('/api/admin/routes')
      .then(res => res.json())
      .then(data => {
        setRoutes(Array.isArray(data) ? data : []);
        setIsLoading(false);
      })
      .catch(() => setIsLoading(false));
  };

  useEffect(() => {
    fetchRoutes();
  }, []);

  const handleDelete = async (id) => {
    if (!window.confirm('Bạn có chắc muốn xóa tuyến đường này?')) return;
    try {
      const res = await fetch(`/api/admin/routes/${id}`, { method: 'DELETE' });
      if (res.ok) {
        fetchRoutes();
      } else {
        const data = await res.json();
        alert('Lỗi: ' + data.error);
      }
    } catch (err) {
      alert('Lỗi kết nối máy chủ!');
    }
  };

  const handleEdit = (route) => {
    setEditingRoute(route);
    setShowModal(true);
  };

  const filteredRoutes = routes.filter(r => 
    r.start_point?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    r.end_point?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="flex flex-col gap-0 -m-4 bg-white min-h-screen font-sans text-slate-700">
      <AnimatePresence>
         {showModal && (
            <RouteModal 
              currentRoute={editingRoute} 
              onClose={() => { setShowModal(false); setEditingRoute(null); }} 
              onSaved={() => { setShowModal(false); setEditingRoute(null); fetchRoutes(); }} 
            />
         )}
      </AnimatePresence>
      
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex flex-wrap items-center gap-4 sticky top-0 z-50 shadow-sm">
        <div className="relative flex-1 max-w-md group">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-orange-500 transition-colors" size={16} />
          <input 
            type="text" 
            placeholder="Tìm điểm khởi hành, điểm đến..." 
            className="w-full bg-[#f8f9fa] border border-slate-200 rounded py-2 pl-10 pr-4 text-xs font-bold text-slate-700 focus:border-orange-400 transition-all outline-none" 
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
          />
        </div>
        
        <div className="flex gap-2 ml-auto">
           <button onClick={() => setShowModal(true)} className="bg-[#EF5222] text-white px-5 py-2 rounded-md text-xs font-black flex items-center gap-2 hover:bg-[#D43D11] shadow-md shadow-orange-100 transition-all uppercase tracking-widest">
              <Plus size={14} /> Thêm tuyến mới
           </button>
           <button onClick={fetchRoutes} className="bg-white border border-slate-200 text-slate-500 px-5 py-2 rounded-md text-xs font-bold flex items-center gap-2 hover:bg-slate-50 transition-all">
              <RefreshCw size={14} /> Làm mới
           </button>
        </div>
      </div>

      <div className="px-6 py-4 bg-white border-b border-slate-100 flex items-center gap-4 shadow-sm">
         <span className="text-[12px] font-black text-slate-800 uppercase tracking-widest border-r border-slate-200 pr-4">CẤU HÌNH</span>
         <div className="flex gap-6 text-[11px] font-bold text-slate-500 overflow-x-auto no-scrollbar">
            <span>Tổng tuyến: <span className="text-slate-900 font-black">{routes.length}</span></span>
            <span>Đang hoạt động: <span className="text-green-600 font-black">{routes.length}</span></span>
         </div>
      </div>

      <div className="flex-1 bg-white overflow-hidden m-6 rounded shadow-sm border border-slate-200">
        <div className="overflow-x-auto h-full">
          <table className="w-full text-left border-collapse min-w-[1000px]">
            <thead className="bg-[#f8fafc] text-[10px] font-black text-slate-500 uppercase border-b border-slate-200 sticky top-0 z-10">
              <tr>
                <th className="px-4 py-4 w-12 text-center border-r border-slate-100 bg-[#f8fafc]"><input type="checkbox" className="rounded-sm border-slate-300 cursor-pointer" /></th>
                <th className="px-6 py-4 border-r border-slate-100">Tuyến đường vận hành <ChevronDown size={10} className="inline ml-1" /></th>
                <th className="px-6 py-4 w-40 border-r border-slate-100 text-center">Cự ly (km)</th>
                <th className="px-6 py-4 w-40 border-r border-slate-100 text-center">Thời gian (h)</th>
                <th className="px-6 py-4 w-48 border-r border-slate-100">Giá vé cơ bản</th>
                <th className="px-6 py-4 w-32 border-r border-slate-100 text-center">Trạng thái</th>
                <th className="px-6 py-4 text-center">Tác vụ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr><td colSpan="7" className="text-center py-24 text-slate-300 font-black italic animate-pulse tracking-widest uppercase text-xs">Đang đồng bộ dữ liệu tuyến đường...</td></tr>
              ) : filteredRoutes.length === 0 ? (
                <tr><td colSpan="7" className="text-center py-32">
                   <div className="flex flex-col items-center gap-3 text-slate-300">
                      <Map size={64} strokeWidth={1} />
                      <span className="font-black italic uppercase text-xs tracking-widest">Không tìm thấy tuyến đường phù hợp</span>
                   </div>
                </td></tr>
              ) : filteredRoutes.map((route, idx) => (
                <tr key={route.id} className="hover:bg-blue-50/30 transition-colors text-xs font-bold text-slate-600 group">
                  <td className="px-4 py-4 text-center border-r border-slate-50 text-slate-300 font-medium">{idx + 1}</td>
                  <td className="px-6 py-4 border-r border-slate-50">
                    <div className="flex items-center gap-3">
                       <div className="w-8 h-8 bg-slate-100 rounded flex items-center justify-center text-slate-400 group-hover:text-orange-500 transition-colors">
                          <Navigation size={14} />
                       </div>
                       <div className="flex items-center gap-2">
                          <span className="font-black text-slate-800 text-sm uppercase">{route.start_point}</span>
                          <ArrowRight size={12} className="text-slate-300" />
                          <span className="font-black text-slate-800 text-sm uppercase">{route.end_point}</span>
                       </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 border-r border-slate-50 text-center">
                    <div className="text-slate-900 font-black text-sm">{route.distance_km}</div>
                    <div className="text-[9px] text-slate-400 font-bold uppercase mt-0.5">Kilômét</div>
                  </td>
                  <td className="px-6 py-4 border-r border-slate-50 text-center">
                    <div className="text-slate-900 font-black text-sm">{route.duration_hours}</div>
                    <div className="text-[9px] text-slate-400 font-bold uppercase mt-0.5">Giờ chạy</div>
                  </td>
                  <td className="px-6 py-4 border-r border-slate-100">
                    <div className="text-[#EF5222] font-black text-base">{(route.base_price || 0).toLocaleString()} <span className="text-[10px]">đ</span></div>
                    <div className="text-[9px] text-slate-400 font-bold uppercase mt-0.5 tracking-tighter">Giá vé tiêu chuẩn</div>
                  </td>
                  <td className="px-6 py-4 border-r border-slate-100 text-center">
                    <span className="text-[9px] font-black uppercase px-3 py-1 rounded border border-green-200 bg-green-50 text-green-700 tracking-widest">Active</span>
                  </td>
                  <td className="px-6 py-4">
                     <div className="flex items-center justify-center gap-1.5 opacity-40 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => handleEdit(route)} className="w-8 h-8 bg-blue-500 text-white rounded flex items-center justify-center hover:bg-blue-600 shadow-md transition-all active:scale-90"><Edit2 size={14} /></button>
                        <button onClick={() => handleDelete(route.id)} className="w-8 h-8 bg-red-500 text-white rounded flex items-center justify-center hover:bg-red-600 shadow-md transition-all active:scale-90"><Trash2 size={14} /></button>
                        <button className="w-8 h-8 bg-white border border-slate-200 text-slate-400 rounded flex items-center justify-center hover:bg-slate-50 transition-all"><Settings2 size={14} /></button>
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

export default Routes;
