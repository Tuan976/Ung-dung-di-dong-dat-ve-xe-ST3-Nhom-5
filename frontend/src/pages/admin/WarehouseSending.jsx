import React, { useState, useEffect } from 'react';
import { Package, Search, Filter, Plus, Truck, ArrowRight, User, Phone, DollarSign, Scale, Maximize, MoreVertical, Printer, Clock, Trash2, Edit2, Download, RefreshCw, ChevronDown, Calendar, MapPin, AlertCircle, X, Bus, CheckCircle2, Wallet, CreditCard, FileText, AlertTriangle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link, useSearchParams } from 'react-router-dom';
import * as XLSX from 'xlsx';

const CreateCargoModal = ({ onClose, onCreated, offices, trips, routes, currentCargo = null, onRefresh }) => {
  const [formData, setFormData] = useState({
    sender_name: '', sender_phone: '',
    receiver_name: '', receiver_phone: '',
    description: '', weight_kg: '', cost: '', cargo_type: 'NORMAL',
    sender_office_id: '', receiver_office_id: '', trip_id: '',
    payment_status: 'UNPAID', cod_amount: ''
  });

  const [modalRouteId, setModalRouteId] = useState('');
  const [modalDate, setModalDate] = useState(new Date().toISOString().split('T')[0]);

  useEffect(() => {
    if (currentCargo) {
      setFormData({
        sender_name: currentCargo.sender_name || '',
        sender_phone: currentCargo.sender_phone || '',
        receiver_name: currentCargo.receiver_name || '',
        receiver_phone: currentCargo.receiver_phone || '',
        description: currentCargo.description || '',
        weight_kg: currentCargo.weight || '',
        cost: currentCargo.cost || '',
        cargo_type: currentCargo.type || 'NORMAL',
        sender_office_id: currentCargo.sender_office_id || '',
        receiver_office_id: currentCargo.receiver_office_id || '',
        trip_id: currentCargo.trip_id || '',
        payment_status: currentCargo.payment_status || 'UNPAID',
        cod_amount: currentCargo.cod_amount || ''
      });

      if (currentCargo.trip_id) {
        const trip = trips.find(t => t.id === currentCargo.trip_id);
        if (trip) {
           setModalRouteId(trip.route_id?.toString() || '');
           setModalDate(trip.departure_time.split('T')[0]);
        }
      }
    }
  }, [currentCargo, trips, routes]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    const method = currentCargo ? 'PUT' : 'POST';
    const url = currentCargo ? `/api/admin/cargo/${currentCargo.id}` : '/api/admin/cargo';
    
    try {
      const response = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });

      if (response.ok) {
        onCreated();
      } else {
        const text = await response.text();
        let errorMsg = 'Không thể lưu dữ liệu!';
        try {
          const data = JSON.parse(text);
          errorMsg = data.error || errorMsg;
        } catch (e) {
          errorMsg = `Server Error (${response.status}): ${text.substring(0, 50)}...`;
        }
        alert('Lỗi: ' + errorMsg);
      }
    } catch (err) {
      console.error(err);
      alert('Lỗi kết nối máy chủ! Hãy đảm bảo bạn đã khởi động lại app.py.');
    }
  };

  const filteredTripsForModal = trips.filter(t => {
     const matchesRoute = !modalRouteId || t.route_id === parseInt(modalRouteId);
     const matchesDate = !modalDate || t.departure_time.startsWith(modalDate);
     return matchesRoute && matchesDate;
  });

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[110] flex items-center justify-center p-4">
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="bg-white w-full max-w-2xl rounded-lg shadow-2xl overflow-hidden flex flex-col max-h-[95vh]">
        <div className="bg-[#f8f9fa] border-b border-slate-200 px-6 py-4 flex justify-between items-center">
          <h2 className="text-lg font-bold text-slate-800 flex items-center gap-2">
            <Package className="text-orange-500" size={20} /> 
            {currentCargo ? 'Cập nhật đơn hàng' : 'Nhận hàng ký gửi mới'}
          </h2>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600 transition-colors"><X size={24} /></button>
        </div>
        
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-6">
          <div className="bg-[#fff9f4] p-5 rounded-lg border border-orange-100 space-y-4">
             <h3 className="text-xs font-bold text-orange-600 uppercase flex items-center gap-2"><Bus size={14} /> Chuyến xe gán đơn</h3>
             <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                   <label className="text-[10px] font-bold text-slate-500 uppercase">Tuyến đường</label>
                   <select className="w-full bg-white border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-orange-400 shadow-sm" value={modalRouteId} onChange={e => setModalRouteId(e.target.value)}>
                      <option value="">-- Tất cả tuyến --</option>
                      {routes.map(r => <option key={r.id} value={r.id}>{r.start_point} - {r.end_point}</option>)}
                   </select>
                </div>
                <div className="space-y-1">
                   <label className="text-[10px] font-bold text-slate-500 uppercase">Ngày chạy</label>
                   <input type="date" className="w-full bg-white border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-orange-400 shadow-sm" value={modalDate} onChange={e => setModalDate(e.target.value)} />
                </div>
             </div>
             <div className="space-y-1">
                <label className="text-[10px] font-bold text-slate-500 uppercase">Chọn chuyến</label>
                <select className="w-full bg-white border border-slate-300 rounded-md py-2 px-3 text-sm font-bold text-blue-600 outline-none focus:border-blue-400 shadow-sm" value={formData.trip_id} onChange={e => setFormData({...formData, trip_id: e.target.value})}>
                   <option value="">-- Lưu kho (Chưa gán chuyến) --</option>
                   {filteredTripsForModal.map(t => (
                     <option key={t.id} value={t.id}>[{t.bus}] {t.route} - {new Date(t.departure_time).toLocaleTimeString('vi-VN', {hour:'2-digit', minute:'2-digit'})}</option>
                   ))}
                </select>
                {filteredTripsForModal.length === 0 && modalRouteId && (
                   <p className="text-[10px] text-red-500 font-bold mt-1 uppercase italic">Không có chuyến nào cho tuyến này vào ngày {new Date(modalDate).toLocaleDateString('vi-VN')}</p>
                )}
             </div>
          </div>

          <div className="grid grid-cols-2 gap-8">
            <div className="space-y-4">
               <h3 className="text-xs font-bold text-blue-600 uppercase border-b border-blue-100 pb-2 flex items-center gap-2"><User size={14}/> Người gửi</h3>
               <div className="space-y-3">
                  <input type="text" placeholder="Họ tên người gửi" className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-blue-400" required value={formData.sender_name} onChange={e => setFormData({...formData, sender_name: e.target.value})} />
                  <input type="tel" placeholder="Số điện thoại" className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-blue-400" required value={formData.sender_phone} onChange={e => setFormData({...formData, sender_phone: e.target.value})} />
                  <select className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-blue-400" required value={formData.sender_office_id} onChange={e => setFormData({...formData, sender_office_id: e.target.value})}>
                     <option value="">Chọn văn phòng gửi</option>
                     {offices.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
                  </select>
               </div>
            </div>
            <div className="space-y-4">
               <h3 className="text-xs font-bold text-green-600 uppercase border-b border-green-100 pb-2 flex items-center gap-2"><User size={14}/> Người nhận</h3>
               <div className="space-y-3">
                  <input type="text" placeholder="Họ tên người nhận" className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-green-400" required value={formData.receiver_name} onChange={e => setFormData({...formData, receiver_name: e.target.value})} />
                  <input type="tel" placeholder="Số điện thoại" className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-green-400" required value={formData.receiver_phone} onChange={e => setFormData({...formData, receiver_phone: e.target.value})} />
                  <select className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-green-400" required value={formData.receiver_office_id} onChange={e => setFormData({...formData, receiver_office_id: e.target.value})}>
                     <option value="">Chọn văn phòng nhận</option>
                     {offices.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
                  </select>
               </div>
            </div>
          </div>

          <div className="space-y-4">
             <h3 className="text-xs font-bold text-slate-600 uppercase border-b border-slate-100 pb-2 flex items-center gap-2"><Package size={14}/> Thông tin hàng hóa</h3>
             <textarea placeholder="Mô tả hàng hóa, ghi chú..." className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm outline-none focus:border-slate-400 h-20" required value={formData.description} onChange={e => setFormData({...formData, description: e.target.value})}></textarea>
             
             <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                   <label className="text-[10px] font-bold text-slate-500 uppercase">Khối lượng (kg)</label>
                   <input type="number" step="0.1" className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm" value={formData.weight_kg} onChange={e => setFormData({...formData, weight_kg: e.target.value})} />
                </div>
                <div className="space-y-1">
                   <label className="text-[10px] font-bold text-slate-500 uppercase">Loại hàng</label>
                   <select className="w-full border border-slate-200 rounded-md py-2 px-3 text-sm" value={formData.cargo_type} onChange={e => setFormData({...formData, cargo_type: e.target.value})}>
                      <option value="NORMAL">Hàng thường</option>
                      <option value="FRAGILE">Dễ vỡ</option>
                      <option value="HIGH_VALUE">Giá trị cao</option>
                   </select>
                </div>
             </div>

             <div className="grid grid-cols-3 gap-4 bg-slate-50 p-4 rounded-lg border border-slate-200">
                <div className="space-y-1">
                   <label className="text-[10px] font-bold text-slate-500 uppercase">Cước phí (đ)</label>
                   <input type="number" className="w-full border border-slate-300 rounded-md py-2 px-3 text-sm font-bold text-blue-600" required value={formData.cost} onChange={e => setFormData({...formData, cost: e.target.value})} />
                </div>
                <div className="space-y-1">
                   <label className="text-[10px] font-bold text-slate-500 uppercase">Thanh toán</label>
                   <select className="w-full border border-slate-300 rounded-md py-2 px-3 text-sm font-bold" value={formData.payment_status} onChange={e => setFormData({...formData, payment_status: e.target.value})}>
                      <option value="UNPAID">Chưa thu</option>
                      <option value="PAID">Đã thu</option>
                   </select>
                </div>
                <div className="space-y-1">
                   <label className="text-[10px] font-bold text-slate-500 uppercase">Thu hộ (COD)</label>
                   <input type="number" className="w-full border border-slate-300 rounded-md py-2 px-3 text-sm font-bold text-red-600" placeholder="0" value={formData.cod_amount} onChange={e => setFormData({...formData, cod_amount: e.target.value})} />
                </div>
             </div>
          </div>
        </form>

        <div className="bg-[#f8f9fa] border-t border-slate-200 px-6 py-4 flex gap-3">
           <button type="button" onClick={onClose} className="flex-1 py-2.5 font-bold text-slate-600 hover:bg-slate-200 rounded-md transition-all">Hủy bỏ</button>
           <button onClick={handleSubmit} className="flex-2 px-12 py-2.5 bg-orange-500 text-white font-bold rounded-md hover:bg-orange-600 shadow-md transition-all uppercase tracking-wider text-sm">
              {currentCargo ? 'Lưu thay đổi' : 'Xác nhận tạo đơn'}
           </button>
        </div>
      </motion.div>
    </div>
  );
};

const WarehouseSending = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [cargos, setCargos] = useState([]);
  const [offices, setOffices] = useState([]);
  const [trips, setTrips] = useState([]);
  const [routes, setRoutes] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [selectedCargo, setSelectedCargo] = useState(null);
  const [showManifest, setShowManifest] = useState(false);
  
  // Selection
  const [selectedIds, setSelectedIds] = useState([]);

  // URL and Local Filters
  const [selectedRouteId, setSelectedRouteId] = useState(searchParams.get('route_id') || '');
  const [selectedDate, setSelectedDate] = useState(searchParams.get('date') || new Date().toISOString().split('T')[0]);
  const [selectedTripId, setSelectedTripId] = useState(searchParams.get('trip_id') || '');
  
  const [filterOfficeId, setFilterOfficeId] = useState('');
  const [filterReceiverOfficeId, setFilterReceiverOfficeId] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [filterPaymentStatus, setFilterPaymentStatus] = useState('');
  const [filterCargoType, setFilterCargoType] = useState('');
  const [filterCOD, setFilterCOD] = useState('');

  const fetchData = async () => {
    setIsLoading(true);
    try {
      const [cargoRes, officeRes, tripRes, routeRes] = await Promise.all([
        fetch('/api/admin/cargo').then(r => r.json()).catch(() => ({})),
        fetch('/api/admin/offices').then(r => r.json()).catch(() => ({})),
        fetch('/api/admin/trips').then(r => r.json()).catch(() => ({})),
        fetch('/api/admin/routes').then(r => r.json()).catch(() => ({}))
      ]);
      
      if (
        (cargoRes && cargoRes.error === 'Unauthorized') ||
        (tripRes && tripRes.error === 'Unauthorized') ||
        (officeRes && officeRes.error === 'Unauthorized') ||
        (routeRes && routeRes.error === 'Unauthorized')
      ) {
         localStorage.removeItem('user');
         window.location.href = '/auth';
         return;
      }

      setCargos(Array.isArray(cargoRes) ? cargoRes : []);
      setOffices(Array.isArray(officeRes) ? officeRes : []);
      setTrips(Array.isArray(tripRes) ? tripRes : []);
      setRoutes(Array.isArray(routeRes) ? routeRes : []);
    } catch (err) { console.error(err); }
    finally { setIsLoading(false); }
  };

  useEffect(() => { fetchData(); }, []);

  useEffect(() => {
    const params = {};
    if (selectedRouteId) params.route_id = selectedRouteId;
    if (selectedDate) params.date = selectedDate;
    if (selectedTripId) params.trip_id = selectedTripId;
    setSearchParams(params);
  }, [selectedRouteId, selectedDate, selectedTripId]);

  const handleAction = async () => {
    if (selectedIds.length > 0) {
      if (!selectedTripId) {
        alert('Vui lòng chọn Chuyến xe ở phía trên để lên hàng cho các đơn đã chọn!');
        return;
      }
      
      try {
        const res = await fetch('/api/admin/cargo/batch', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ids: selectedIds, trip_id: parseInt(selectedTripId) })
        });
        if (res.ok) {
          alert(`Đã lên hàng thành công ${selectedIds.length} đơn vào chuyến xe!`);
          setSelectedIds([]);
          fetchData();
        } else {
          alert('Có lỗi khi lên hàng hàng loạt!');
        }
      } catch (err) { console.error(err); }
    } else {
      setSelectedCargo(null);
      setShowModal(true);
    }
  };

  const toggleSelect = (id) => {
    setSelectedIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  };

  const toggleSelectAll = () => {
    if (selectedIds.length === filteredCargos.length) setSelectedIds([]);
    else setSelectedIds(filteredCargos.map(c => c.id));
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Bạn có chắc muốn xóa kiện hàng này?')) return;
    try {
      const res = await fetch(`/api/admin/cargo/${id}`, { method: 'DELETE' });
      if (res.ok) fetchData();
    } catch (err) { console.error(err); }
  };

  const openEdit = (cargo) => {
    setSelectedCargo(cargo);
    setShowModal(true);
  };

  const filteredCargos = cargos.filter(c => {
    const trip = trips.find(t => t.id === c.trip_id);
    
    const matchesTripFilter = !selectedTripId || c.trip_id === parseInt(selectedTripId);
    if (selectedTripId) return matchesTripFilter;

    const matchesOffice = !filterOfficeId || c.sender_office_id === parseInt(filterOfficeId);
    const matchesReceiverOffice = !filterReceiverOfficeId || c.receiver_office_id === parseInt(filterReceiverOfficeId);
    const matchesStatus = !filterStatus || c.status === filterStatus;
    const matchesPayment = !filterPaymentStatus || c.payment_status === filterPaymentStatus;
    const matchesType = !filterCargoType || c.cargo_type === filterCargoType;
    const matchesCOD = !filterCOD || (filterCOD === 'YES' ? (c.cod_amount > 0) : (c.cod_amount === 0));
    
    // Date filter: Check trip departure OR cargo collection date. Warehouse cargos are kept visible so they can be loaded.
    const cargoDate = trip ? trip.departure_time : c.collected_at || c.created_at;
    const matchesDate = !selectedDate || !c.trip_id || (cargoDate && cargoDate.startsWith(selectedDate));
    const matchesRoute = !selectedRouteId || !c.trip_id || (trip && trip.route_id === parseInt(selectedRouteId));

    return matchesDate && matchesRoute && matchesOffice && matchesReceiverOffice && matchesStatus && matchesPayment && matchesType && matchesCOD;
  });

  const totalCost = filteredCargos.reduce((acc, c) => acc + (c.cost || 0), 0);
  const totalCOD = filteredCargos.reduce((acc, c) => acc + (c.cod_amount || 0), 0);
  const totalWeight = filteredCargos.reduce((acc, c) => acc + (c.weight || 0), 0);

  const availableTrips = trips.filter(t => {
     const matchesRoute = !selectedRouteId || t.route_id === parseInt(selectedRouteId);
     const matchesDate = !selectedDate || t.departure_time.startsWith(selectedDate);
     return matchesRoute && matchesDate;
  });

  const exportManifest = () => {
    if (!selectedTripId) {
       alert("Vui lòng chọn một chuyến xe để xuất phơi hàng!");
       return;
    }
    const trip = trips.find(t => t.id === parseInt(selectedTripId));
    const manifestData = filteredCargos.map((c, index) => ({
       'STT': index + 1,
       'Mã vận đơn': c.tracking_number,
       'Người gửi': `${c.sender_name} (${c.sender_phone})`,
       'Người nhận': `${c.receiver_name} (${c.receiver_phone})`,
       'Mô tả hàng hóa': c.description,
       'Trọng lượng (kg)': c.weight_kg,
       'Cước phí': c.cost,
       'Trạng thái thu': c.payment_status === 'PAID' ? 'Đã thu' : 'Chưa thu',
       'Thu hộ (COD)': c.cod_amount || 0,
       'Ghi chú': ''
    }));

    const ws = XLSX.utils.json_to_sheet(manifestData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Phơi hàng");
    XLSX.writeFile(wb, `Manifest_${trip?.bus}_${selectedDate}.xlsx`);
  };

  return (
    <div className="flex flex-col gap-0 -m-4 bg-white min-h-screen font-sans text-slate-700 pb-20">
      {showModal && (
        <CreateCargoModal 
          onClose={() => { setShowModal(false); setSelectedCargo(null); }} 
          onCreated={() => { setShowModal(false); setSelectedCargo(null); fetchData(); }} 
          offices={offices} trips={trips} routes={routes} currentCargo={selectedCargo} onRefresh={fetchData}
        />
      )}
      
      {/* Top Header Controls */}
      <div className="bg-[#e9ecef] border-b border-slate-300 px-6 py-3 flex flex-wrap items-center gap-3 relative z-30">
         <div className="flex flex-col">
            <label className="text-[10px] font-bold text-slate-500 uppercase mb-1">Tuyến đường</label>
            <select 
              className="bg-white border border-slate-300 rounded px-3 py-1.5 text-sm w-64 outline-none focus:border-blue-400 shadow-sm font-bold cursor-pointer"
              value={selectedRouteId} onChange={e => { setSelectedRouteId(e.target.value); setSelectedTripId(''); }}
            >
               <option value="">-- Tất cả tuyến --</option>
               {routes.map(r => <option key={r.id} value={r.id}>{r.start_point} - {r.end_point}</option>)}
            </select>
         </div>
         
         <div className="flex flex-col">
            <label className="text-[10px] font-bold text-slate-500 uppercase mb-1">Ngày chạy</label>
            <div className="flex gap-1">
               <input 
                 type="date" 
                 className="bg-white border border-slate-300 rounded px-3 py-1.5 text-sm outline-none focus:border-blue-400 shadow-sm font-bold cursor-pointer" 
                 value={selectedDate} onChange={e => { setSelectedDate(e.target.value); setSelectedTripId(''); }}
               />
               <button onClick={() => setSelectedDate('')} className={`px-2 text-[10px] font-black rounded border transition-all ${!selectedDate ? 'bg-blue-600 text-white' : 'bg-white text-slate-400'}`}>TẤT CẢ</button>
            </div>
         </div>
         
         <div className="flex flex-col">
            <label className="text-[10px] font-bold text-slate-500 uppercase mb-1">Chọn chuyến xe</label>
            <select 
              className={`bg-white border rounded px-3 py-1.5 text-sm w-64 outline-none shadow-sm font-black transition-all cursor-pointer ${availableTrips.length === 0 && selectedRouteId ? 'border-red-400 text-red-500 animate-pulse' : 'border-slate-300 text-blue-600'}`}
              value={selectedTripId} onChange={e => setSelectedTripId(e.target.value)}
            >
               <option value="">-- {availableTrips.length === 0 ? 'KHÔNG CÓ CHUYẾN' : 'Chọn chuyến xe'} --</option>
               {availableTrips.map(t => <option key={t.id} value={t.id}>[{t.bus}] {new Date(t.departure_time).toLocaleTimeString('vi-VN', {hour: '2-digit', minute:'2-digit'})}</option>)}
            </select>
         </div>

         <div className="flex items-end h-full pt-4">
            <button 
              onClick={handleAction} 
              className={`px-6 py-2.5 rounded text-sm font-black flex items-center gap-2 shadow-md transition-all active:scale-95 uppercase tracking-widest ${selectedIds.length > 0 ? 'bg-blue-600 text-white' : 'bg-orange-500 text-white'}`}
            >
               {selectedIds.length > 0 ? <Truck size={18} /> : <Plus size={18} />}
               {selectedIds.length > 0 ? `Lên hàng (${selectedIds.length})` : 'NHẬN ĐƠN MỚI'}
            </button>
            
            <button onClick={() => { if(selectedTripId) setShowManifest(!showManifest); else alert("Chọn chuyến xe để xem phơi!"); }} className={`px-5 py-2.5 rounded text-sm font-bold flex items-center gap-2 shadow-sm transition-all ml-2 ${showManifest ? 'bg-blue-600 text-white' : 'bg-[#dee2e6] text-slate-600'}`}>
               <Printer size={16} /> {showManifest ? 'Đóng phơi' : 'Phơi hàng'}
            </button>
         </div>

         {availableTrips.length === 0 && selectedRouteId && selectedDate && (
            <div className="flex items-center gap-2 bg-red-50 border border-red-100 px-4 py-2 rounded-lg ml-4">
               <AlertTriangle size={16} className="text-red-500" />
               <span className="text-[10px] font-black text-red-600 uppercase">Ngày {new Date(selectedDate).toLocaleDateString('vi-VN')} không có xe chạy!</span>
               <button onClick={() => setSelectedDate('')} className="text-[10px] font-black text-blue-600 underline ml-2">XEM TẤT CẢ NGÀY</button>
            </div>
         )}
      </div>

      {/* Summary Line */}
      <div className="px-6 py-3 bg-white border-b border-slate-100 flex items-center gap-4 shadow-sm relative z-20">
         <span className="text-[12px] font-black text-slate-800 uppercase tracking-widest border-r border-slate-200 pr-4">KHO GỬI</span>
         <div className="flex gap-6 text-[11px] font-bold text-slate-500 overflow-x-auto no-scrollbar">
            <span>Tổng: Đơn: <span className="text-slate-900 font-black">{filteredCargos.length}</span></span>
            <span>SL: <span className="text-slate-900 font-black">{filteredCargos.length}</span></span>
            <span>KG: <span className="text-slate-900 font-black">{totalWeight}</span></span>
            <span>CC: <span className="text-[#EF5222] font-black">{totalCost.toLocaleString()} đ</span></span>
            <span>Thu hộ: <span className="text-blue-600 font-black">{totalCOD.toLocaleString()} đ</span></span>
         </div>
      </div>

      <AnimatePresence>
        {showManifest && selectedTripId && (
           <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="px-6 py-4 bg-slate-50 border-b border-slate-200 overflow-hidden relative z-10">
              <div className="bg-white rounded-xl shadow-lg border border-slate-200 p-8 max-w-5xl mx-auto">
                 <div className="flex justify-between items-start mb-8 border-b-2 border-slate-800 pb-4">
                    <div>
                       <h2 className="text-2xl font-black text-slate-900 uppercase">PHƠI HÀNG KÝ GỬI</h2>
                       <p className="text-sm font-bold text-blue-600 uppercase mt-1">Chuyến: {trips.find(t=>t.id===parseInt(selectedTripId))?.bus} - {trips.find(t=>t.id===parseInt(selectedTripId))?.route}</p>
                    </div>
                    <div className="text-right">
                       <p className="text-xs font-bold text-slate-500 uppercase">Ngày đi: {new Date(trips.find(t=>t.id===parseInt(selectedTripId))?.departure_time).toLocaleDateString('vi-VN')}</p>
                       <p className="text-xs font-bold text-slate-500 uppercase mt-1">Giờ chạy: {new Date(trips.find(t=>t.id===parseInt(selectedTripId))?.departure_time).toLocaleTimeString('vi-VN', {hour:'2-digit', minute:'2-digit'})}</p>
                       <button onClick={exportManifest} className="mt-4 bg-green-600 text-white px-4 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest flex items-center gap-2 hover:bg-green-700 shadow-md">
                          <Download size={14} /> Xuất phơi Excel
                       </button>
                    </div>
                 </div>

                 <table className="w-full border-collapse border border-slate-800 text-[11px]">
                    <thead>
                       <tr className="bg-slate-100 text-slate-900 font-black uppercase">
                          <th className="border border-slate-800 p-2 w-10">STT</th>
                          <th className="border border-slate-800 p-2">Mã đơn</th>
                          <th className="border border-slate-800 p-2">Người gửi</th>
                          <th className="border border-slate-800 p-2">Người nhận</th>
                          <th className="border border-slate-800 p-2">Hàng hóa</th>
                          <th className="border border-slate-800 p-2">Cước phí</th>
                          <th className="border border-slate-800 p-2">Thu hộ</th>
                       </tr>
                    </thead>
                    <tbody>
                       {filteredCargos.map((c, i) => (
                          <tr key={c.id} className="font-bold text-slate-700">
                             <td className="border border-slate-800 p-2 text-center">{i+1}</td>
                             <td className="border border-slate-800 p-2">{c.tracking_number}</td>
                             <td className="border border-slate-800 p-2">{c.sender_name}<br/><span className="text-[9px] font-medium">{c.sender_phone}</span></td>
                             <td className="border border-slate-800 p-2">{c.receiver_name}<br/><span className="text-[9px] font-medium">{c.receiver_phone}</span></td>
                             <td className="border border-slate-800 p-2">{c.description}</td>
                             <td className="border border-slate-800 p-2 text-right">{c.cost.toLocaleString()} đ</td>
                             <td className="border border-slate-800 p-2 text-right text-red-600">{c.cod_amount ? c.cod_amount.toLocaleString() : '-'}</td>
                          </tr>
                       ))}
                       <tr className="bg-slate-50 font-black text-slate-900">
                          <td colSpan="5" className="border border-slate-800 p-2 text-right uppercase">Tổng cộng:</td>
                          <td className="border border-slate-800 p-2 text-right">{totalCost.toLocaleString()} đ</td>
                          <td className="border border-slate-800 p-2 text-right text-red-600">{totalCOD.toLocaleString()} đ</td>
                       </tr>
                    </tbody>
                 </table>
                 <div className="grid grid-cols-3 gap-8 mt-12 text-center text-xs font-black uppercase italic">
                    <div>Người lập phơi</div>
                    <div>Tài xế xác nhận</div>
                    <div>Văn phòng nhận</div>
                 </div>
              </div>
           </motion.div>
        )}
      </AnimatePresence>

      {/* Filter Area */}
      <div className="px-6 py-4 bg-[#f8fafc] border-b border-slate-200 relative z-20 shadow-sm">
         <div className="flex flex-col gap-4">
            <div className="flex items-center gap-3">
               <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest min-w-[30px]">Lọc</span>
               
               <select 
                  className="bg-blue-600 text-white px-4 py-2 rounded-md text-xs font-black uppercase tracking-widest outline-none shadow-md hover:bg-blue-700 transition-all w-56 cursor-pointer border-none"
                  value={filterOfficeId}
                  onChange={e => setFilterOfficeId(e.target.value)}
               >
                  <option value="">Văn phòng gửi</option>
                  {offices.map(o => <option key={o.id} value={o.id} className="bg-white text-slate-700">{o.name}</option>)}
               </select>

               <div className="flex items-center bg-white border border-slate-200 rounded-md px-3 py-2 gap-2 text-xs font-bold text-slate-600 shadow-sm w-48">
                  <Calendar size={14} className="text-blue-500" />
                  <input 
                    type="date" 
                    className="outline-none w-full bg-transparent cursor-pointer" 
                    value={selectedDate}
                    onChange={e => setSelectedDate(e.target.value)}
                  />
               </div>

               <select 
                  className="bg-white border border-slate-200 text-slate-700 px-4 py-2 rounded-md text-xs font-bold outline-none w-56 shadow-sm hover:border-blue-400 transition-all cursor-pointer"
                  value={filterReceiverOfficeId}
                  onChange={e => setFilterReceiverOfficeId(e.target.value)}
               >
                  <option value="">Văn phòng nhận</option>
                  {offices.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
               </select>

               <select 
                  className="bg-white border border-slate-200 text-slate-700 px-4 py-2 rounded-md text-xs font-bold outline-none w-44 shadow-sm hover:border-blue-400 transition-all cursor-pointer"
                  value={filterStatus}
                  onChange={e => setFilterStatus(e.target.value)}
               >
                  <option value="">Trạng thái đơn</option>
                  <option value="Received">Đã nhận</option>
                  <option value="In Transit">Đang đi</option>
                  <option value="Delivered">Đã giao</option>
               </select>

               <select 
                  className="bg-white border border-slate-200 text-slate-700 px-4 py-2 rounded-md text-xs font-bold outline-none w-44 shadow-sm hover:border-blue-400 transition-all cursor-pointer"
                  value={filterPaymentStatus}
                  onChange={e => setFilterPaymentStatus(e.target.value)}
               >
                  <option value="">Trạng thái cước</option>
                  <option value="PAID">Đã thu</option>
                  <option value="UNPAID">Chưa thu</option>
               </select>
            </div>

            <div className="flex items-center gap-3 ml-[42px]">
               <select 
                  className="bg-white border border-slate-200 text-slate-700 px-4 py-2 rounded-md text-xs font-bold outline-none w-52 shadow-sm hover:border-blue-400 transition-all cursor-pointer"
                  value={filterCOD}
                  onChange={e => setFilterCOD(e.target.value)}
               >
                  <option value="">Trạng thái thu hộ</option>
                  <option value="YES">Có COD</option>
                  <option value="NO">Không COD</option>
               </select>

               <select 
                  className="bg-white border border-slate-200 text-slate-700 px-4 py-2 rounded-md text-xs font-bold outline-none w-56 shadow-sm hover:border-blue-400 transition-all cursor-pointer"
                  value={filterCargoType}
                  onChange={e => setFilterCargoType(e.target.value)}
               >
                  <option value="">Loại hàng / Đơn vị</option>
                  <option value="NORMAL">Hàng thường</option>
                  <option value="FRAGILE">Dễ vỡ</option>
                  <option value="HIGH_VALUE">Giá trị cao</option>
               </select>

               <div className="ml-auto flex gap-2">
                  <button onClick={fetchData} className="bg-slate-500 text-white px-4 py-2 rounded-md text-[10px] font-black uppercase tracking-widest flex items-center gap-2 hover:bg-slate-600 shadow-sm transition-all active:scale-95">
                     <RefreshCw size={12} /> Làm mới
                  </button>
               </div>
            </div>
         </div>
      </div>

      {/* Main Table */}
      <div className="flex-1 px-6 pb-6 overflow-hidden mt-4 relative z-10">
        <div className="border border-slate-200 rounded shadow-sm overflow-x-auto h-full bg-white">
          <table className="w-full text-left border-collapse min-w-[1200px]">
            <thead className="bg-[#f8f9fa] text-[12px] font-bold text-slate-700 border-b border-slate-200 sticky top-0 z-10">
              <tr>
                <th className="px-3 py-3 w-10 text-center border-r border-slate-200 bg-[#f8f9fa]">
                  <input type="checkbox" className="rounded-sm border-slate-300 w-4 h-4 cursor-pointer" 
                    checked={selectedIds.length === filteredCargos.length && filteredCargos.length > 0} 
                    onChange={toggleSelectAll} 
                  />
                </th>
                <th className="px-3 py-3 w-28 border-r border-slate-200">Chi tiết <ChevronDown size={12} className="inline ml-1" /></th>
                <th className="px-4 py-3 border-r border-slate-200">Tên món hàng <br/><span className="text-[10px] text-slate-500 font-medium italic">Ghi chú</span></th>
                <th className="px-4 py-3 w-24 border-r border-slate-200">Mã vận đơn <br/><span className="text-[10px] text-slate-500 font-medium tracking-tighter">{new Date().toLocaleDateString()}</span></th>
                <th className="px-4 py-3 w-28 border-r border-slate-200">CC</th>
                <th className="px-4 py-3 w-40 border-r border-slate-200">Số ĐT <br/><span className="text-[10px] text-slate-500 font-medium">Người nhận</span></th>
                <th className="px-4 py-3 w-48 border-r border-slate-200">ĐC giao <br/><span className="text-[10px] text-slate-500 font-medium">VP nhận</span></th>
                <th className="px-4 py-3 w-40 border-r border-slate-200">Số ĐT <br/><span className="text-[10px] text-slate-500 font-medium">Người gửi</span></th>
                <th className="px-4 py-3 w-48 border-r border-slate-200">ĐC lấy <br/><span className="text-[10px] text-slate-500 font-medium">VP gửi</span></th>
                <th className="px-4 py-3 text-center">Tác vụ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr><td colSpan="10" className="text-center py-20 text-slate-400 italic">Đang tải dữ liệu...</td></tr>
              ) : filteredCargos.length === 0 ? (
                <tr><td colSpan="10" className="text-center py-32">
                   <div className="flex flex-col items-center gap-3 text-slate-300">
                      <Package size={48} strokeWidth={1} />
                      <span className="text-sm font-medium italic uppercase tracking-widest">Không có hàng hóa phù hợp trong kho</span>
                      <p className="text-[10px] text-slate-400 max-w-xs text-center mt-2 font-bold uppercase">Mẹo: Thử chọn "Tất cả tuyến" hoặc xóa ngày lọc để thấy hàng đang lưu kho chờ gán chuyến.</p>
                   </div>
                </td></tr>
              ) : filteredCargos.map((cargo) => (
                <tr key={cargo.id} className={`transition-colors text-[13px] text-slate-600 ${selectedIds.includes(cargo.id) ? 'bg-blue-50/50' : 'hover:bg-slate-50'}`}>
                  <td className="px-3 py-4 text-center border-r border-slate-100">
                    <input type="checkbox" className="rounded-sm border-slate-300 w-4 h-4 cursor-pointer" 
                      checked={selectedIds.includes(cargo.id)} 
                      onChange={() => toggleSelect(cargo.id)} 
                    />
                  </td>
                  <td className="px-3 py-4 border-r border-slate-100">
                     <div className="text-slate-700 font-bold leading-none mb-1">{cargo.type === 'NORMAL' ? '1 loại' : 'Hàng đặc biệt'}</div>
                     <div className="text-slate-500 text-[11px] font-medium italic">{cargo.type}</div>
                     {cargo.payment_status === 'PAID' ? (
                        <div className="mt-1 flex items-center gap-1 text-[9px] text-green-600 font-black uppercase"><Wallet size={10} /> Đã thu</div>
                     ) : (
                        <div className="mt-1 flex items-center gap-1 text-[9px] text-red-500 font-black uppercase"><CreditCard size={10} /> Chưa thu</div>
                     )}
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100 font-bold text-slate-800">
                     {cargo.description}
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="text-blue-600 font-black text-xs tracking-tighter">{cargo.tracking_number}</div>
                     <div className="text-[9px] text-slate-400 font-bold mt-1 uppercase">{cargo.status}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="text-red-600 font-black text-sm">{(cargo.cost || 0).toLocaleString()}</div>
                     {cargo.cod_amount > 0 && (
                        <div className="text-[9px] text-blue-600 font-black mt-1 uppercase">COD: {cargo.cod_amount.toLocaleString()}</div>
                     )}
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="text-slate-900 font-black tracking-tight">{cargo.receiver_phone}</div>
                     <div className="text-slate-500 text-[11px] font-bold uppercase">{cargo.receiver_name}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="text-green-600 font-black text-[11px] mb-1 flex items-center gap-1">ĐĐ: {cargo.receiver_office || 'N/A'}</div>
                     <div className="text-slate-500 text-[11px] font-bold">VP {cargo.receiver_office || 'N/A'}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="text-slate-900 font-black tracking-tight">{cargo.sender_phone}</div>
                     <div className="text-slate-500 text-[11px] font-bold uppercase">{cargo.sender_name}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="text-green-600 font-black text-[11px] mb-1 flex items-center gap-1">ĐĐ: {cargo.sender_office || 'N/A'}</div>
                     <div className="text-slate-500 text-[11px] font-bold">VP {cargo.sender_office || 'N/A'}</div>
                  </td>
                  <td className="px-4 py-4">
                     <div className="flex items-center justify-center gap-1.5">
                        <button onClick={() => openEdit(cargo)} className="w-7 h-7 bg-blue-500 text-white rounded-full flex items-center justify-center hover:bg-blue-600 shadow-md transition-all active:scale-90" title="Sửa đơn"><Edit2 size={12} /></button>
                        <button onClick={() => handleDelete(cargo.id)} className="w-7 h-7 bg-red-500 text-white rounded-full flex items-center justify-center hover:bg-red-600 shadow-md transition-all active:scale-90" title="Xóa đơn"><Trash2 size={12} /></button>
                        <button onClick={() => window.open(`/api/admin/cargo/${cargo.id}/receipt`, '_blank')} className="w-7 h-7 bg-white border border-slate-200 text-slate-400 rounded-full flex items-center justify-center hover:bg-slate-50 shadow-sm transition-all" title="In biên nhận"><Printer size={12} /></button>
                        <button className="w-7 h-7 bg-white border border-slate-200 text-slate-400 rounded-full flex items-center justify-center hover:bg-slate-50 shadow-sm transition-all" title="Lịch sử"><Clock size={12} /></button>
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

export default WarehouseSending;
