import React, { useState, useEffect } from 'react';
import { Package, Search, Filter, Plus, Truck, ArrowRight, User, Phone, DollarSign, Scale, Maximize, MoreVertical, Printer, Clock, Trash2, Edit2, Download, RefreshCw, ChevronDown, Calendar, MapPin, AlertCircle, X, Bus, Wallet, CreditCard } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link } from 'react-router-dom';

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
           const route = routes.find(r => trip.route.includes(r.start_point));
           if (route) setModalRouteId(route.id.toString());
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

  const isOfficeInCity = (office, city) => {
    if (!city) return true;
    const c = city.toLowerCase().replace('tp.', '').trim();
    const name = office.name.toLowerCase();
    const addr = (office.address || '').toLowerCase();
    
    if (c.includes('hồ chí minh') || c === 'hcm' || c === 'ho chi minh') {
      return name.includes('hcm') || name.includes('quận 9') || name.includes('q9') || name.includes('sài gòn') || 
             addr.includes('hồ chí minh') || addr.includes('hcm') || addr.includes('quận 9') || addr.includes('q9');
    }
    
    if (c.includes('cư jut') || c.includes('cư jút') || c.includes('đắk nông') || c.includes('dak nong')) {
      return name.includes('cư jut') || name.includes('đắk mil') || name.includes('gia nghĩa') || name.includes('kiến đức') ||
             addr.includes('cư jut') || addr.includes('đắk mil') || addr.includes('gia nghĩa') || addr.includes('kiến đức') ||
             name.includes('đắk nông') || addr.includes('đắk nông') || name.includes('lâm đồng') || addr.includes('lâm đồng');
    }
    
    return name.includes(c) || addr.includes(c);
  };

  const selectedTrip = formData.trip_id ? trips.find(t => t.id === parseInt(formData.trip_id)) : null;
  const [startPoint, endPoint] = selectedTrip && selectedTrip.route ? selectedTrip.route.split(' - ') : [null, null];
  const selectedRouteObj = modalRouteId ? routes.find(r => r.id === parseInt(modalRouteId)) : null;
  const filterStartPoint = startPoint || (selectedRouteObj ? selectedRouteObj.start_point : null);
  const filterEndPoint = endPoint || (selectedRouteObj ? selectedRouteObj.end_point : null);

  const filteredSenderOffices = offices.filter(o => isOfficeInCity(o, filterStartPoint));
  const filteredReceiverOffices = offices.filter(o => isOfficeInCity(o, filterEndPoint));

  // Validate and auto-select offices when the route or trip changes
  useEffect(() => {
    let updated = false;
    let newSender = formData.sender_office_id;
    let newReceiver = formData.receiver_office_id;

    if (filterStartPoint) {
      const isValid = filteredSenderOffices.some(o => o.id === parseInt(formData.sender_office_id));
      if (!isValid) {
        newSender = filteredSenderOffices.length === 1 ? filteredSenderOffices[0].id.toString() : '';
        updated = true;
      }
    }
    if (filterEndPoint) {
      const isValid = filteredReceiverOffices.some(o => o.id === parseInt(formData.receiver_office_id));
      if (!isValid) {
        newReceiver = filteredReceiverOffices.length === 1 ? filteredReceiverOffices[0].id.toString() : '';
        updated = true;
      }
    }

    if (updated) {
      setFormData(prev => ({
        ...prev,
        sender_office_id: newSender,
        receiver_office_id: newReceiver
      }));
    }
  }, [formData.trip_id, modalRouteId, offices]);

  const filteredTripsForModal = trips.filter(t => {
     const matchesRoute = !modalRouteId || t.route_id === parseInt(modalRouteId);
     const matchesDate = !modalDate || t.departure_time.startsWith(modalDate);
     return matchesRoute && matchesDate;
  });

  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[110] flex items-center justify-center p-6">
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="bg-white w-full max-w-2xl rounded-3xl shadow-2xl p-8 overflow-y-auto max-h-[90vh]">
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <h2 className="text-2xl font-black text-slate-800 flex items-center gap-3"><Package className="text-orange-500" /> {currentCargo ? 'Cập nhật đơn hàng' : 'Nhận hàng ký gửi'}</h2>
            <button type="button" onClick={onRefresh} title="Tải lại dữ liệu" className="p-2 hover:bg-slate-100 rounded-full transition-all text-slate-400 hover:text-blue-500">
               <RefreshCw size={16} />
            </button>
          </div>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600 font-bold"><X size={24} /></button>
        </div>
        <form onSubmit={handleSubmit} className="space-y-6">
          
          <div className="p-5 bg-slate-50 rounded-3xl border border-slate-100 space-y-4">
             <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-2"><Bus size={12} className="text-blue-500" /> Lịch trình xe chạy</h3>
             
             <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                   <label className="text-[9px] font-black text-slate-400 uppercase ml-1">Tuyến đường</label>
                   <select 
                     className="w-full bg-white border border-slate-200 rounded-xl py-2.5 px-4 font-bold text-xs outline-none focus:border-blue-400 shadow-sm"
                     value={modalRouteId} onChange={e => setModalRouteId(e.target.value)}
                   >
                      <option value="">Chọn tuyến (Để lọc chuyến)</option>
                      {routes.map(r => <option key={r.id} value={r.id}>{r.start_point} - {r.end_point}</option>)}
                   </select>
                </div>
                <div className="space-y-1">
                   <label className="text-[9px] font-black text-slate-400 uppercase ml-1">Ngày đi</label>
                   <input 
                     type="date" 
                     className="w-full bg-white border border-slate-200 rounded-xl py-2.5 px-4 font-bold text-xs outline-none focus:border-blue-400 shadow-sm"
                     value={modalDate} onChange={e => setModalDate(e.target.value)}
                   />
                </div>
             </div>

             <div className="space-y-1">
                <label className="text-[9px] font-black text-slate-400 uppercase ml-1">Chọn chuyến xe</label>
                <select className="w-full bg-white border border-slate-200 rounded-xl py-3 px-4 font-black text-sm outline-none focus:border-blue-400 text-blue-600 shadow-sm"
                   value={formData.trip_id} onChange={e => setFormData({...formData, trip_id: e.target.value})}>
                   <option value="">-- Chưa gán chuyến / Lưu kho --</option>
                   {filteredTripsForModal.map(t => (
                     <option key={t.id} value={t.id}>
                       [{t.bus}] {t.route} - {new Date(t.departure_time).toLocaleTimeString('vi-VN', {hour:'2-digit', minute:'2-digit'})}
                     </option>
                   ))}
                </select>
             </div>
          </div>

          <div className="grid grid-cols-2 gap-6 text-sm">
            <div className="space-y-4">
               <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-widest border-l-4 border-blue-500 pl-2">Người gửi</h3>
               <input type="text" placeholder="Tên người gửi" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 shadow-sm" required 
                 value={formData.sender_name} onChange={e => setFormData({...formData, sender_name: e.target.value})} />
               <input type="tel" placeholder="SĐT người gửi" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 shadow-sm" required 
                 value={formData.sender_phone} onChange={e => setFormData({...formData, sender_phone: e.target.value})} />
               <select className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 text-slate-700 shadow-sm" required
                  value={formData.sender_office_id} onChange={e => setFormData({...formData, sender_office_id: e.target.value})}>
                  <option value="">Văn phòng gửi</option>
                  {filteredSenderOffices.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
               </select>
            </div>
            <div className="space-y-4">
               <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-widest border-l-4 border-green-500 pl-2">Người nhận</h3>
               <input type="text" placeholder="Tên người nhận" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 shadow-sm" required 
                 value={formData.receiver_name} onChange={e => setFormData({...formData, receiver_name: e.target.value})} />
               <input type="tel" placeholder="SĐT người nhận" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 shadow-sm" required 
                 value={formData.receiver_phone} onChange={e => setFormData({...formData, receiver_phone: e.target.value})} />
               <select className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 text-slate-700 shadow-sm" required
                  value={formData.receiver_office_id} onChange={e => setFormData({...formData, receiver_office_id: e.target.value})}>
                  <option value="">Văn phòng nhận</option>
                  {filteredReceiverOffices.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
               </select>
            </div>
          </div>
          <div className="space-y-4">
             <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-widest border-l-4 border-orange-500 pl-2">Thông tin Kiện hàng</h3>
             <textarea placeholder="Mô tả hàng hóa..." className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 h-24 shadow-sm" required
               value={formData.description} onChange={e => setFormData({...formData, description: e.target.value})}></textarea>
             
             <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                   <label className="text-[10px] font-black text-slate-400 uppercase ml-1">Khối lượng (kg)</label>
                   <input type="number" step="0.1" className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 shadow-sm" 
                     value={formData.weight_kg} onChange={e => setFormData({...formData, weight_kg: e.target.value})} />
                </div>
                <div className="space-y-1">
                   <label className="text-[10px] font-black text-slate-400 uppercase ml-1">Loại hàng</label>
                   <select className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 font-bold outline-none focus:border-blue-400 shadow-sm"
                      value={formData.cargo_type} onChange={e => setFormData({...formData, cargo_type: e.target.value})}>
                      <option value="NORMAL">Hàng thường</option>
                      <option value="FRAGILE">Hàng dễ vỡ</option>
                      <option value="HIGH_VALUE">Giá trị cao</option>
                   </select>
                </div>
             </div>

             <div className="grid grid-cols-3 gap-4 bg-slate-100 p-4 rounded-2xl border border-slate-200">
                <div className="space-y-1">
                   <label className="text-[10px] font-black text-slate-500 uppercase ml-1">Cước phí (đ)</label>
                   <input type="number" className="w-full bg-white border border-slate-300 rounded-xl py-3 px-4 font-black text-sm text-blue-600 outline-none focus:border-blue-400 shadow-sm" required 
                     value={formData.cost} onChange={e => setFormData({...formData, cost: e.target.value})} />
                </div>
                <div className="space-y-1">
                   <label className="text-[10px] font-black text-slate-500 uppercase ml-1">Thanh toán</label>
                   <select className="w-full bg-white border border-slate-300 rounded-xl py-3 px-4 font-black text-sm outline-none focus:border-blue-400 shadow-sm"
                     value={formData.payment_status} onChange={e => setFormData({...formData, payment_status: e.target.value})}>
                      <option value="UNPAID">Chưa thu</option>
                      <option value="PAID">Đã thu</option>
                   </select>
                </div>
                <div className="space-y-1">
                   <label className="text-[10px] font-black text-slate-500 uppercase ml-1">Thu hộ (COD)</label>
                   <input type="number" className="w-full bg-white border border-slate-300 rounded-xl py-3 px-4 font-black text-sm text-red-600 outline-none focus:border-red-400 shadow-sm" placeholder="0" 
                     value={formData.cod_amount} onChange={e => setFormData({...formData, cod_amount: e.target.value})} />
                </div>
             </div>
          </div>
          <div className="flex gap-4 pt-6">
            <button type="button" onClick={onClose} className="flex-1 py-4 font-bold text-slate-500 hover:bg-slate-50 rounded-xl transition-all">Hủy</button>
            <button type="submit" className="flex-1 py-4 bg-[#EF5222] text-white font-black rounded-xl shadow-lg shadow-orange-100 hover:bg-[#D43D11] transition-all uppercase tracking-widest text-xs">
               {currentCargo ? 'Lưu thay đổi' : 'Xác nhận đơn hàng'}
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};

const Cargo = () => {
  const [cargos, setCargos] = useState([]);
  const [offices, setOffices] = useState([]);
  const [trips, setTrips] = useState([]);
  const [routes, setRoutes] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [selectedCargo, setSelectedCargo] = useState(null);
  
  // Filters
  const [selectedRouteId, setSelectedRouteId] = useState('');
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);
  const [selectedTripId, setSelectedTripId] = useState('');
  const [filterOfficeId, setFilterOfficeId] = useState('');
  const [filterReceiverOfficeId, setFilterReceiverOfficeId] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [filterPaymentStatus, setFilterPaymentStatus] = useState('');
  const [filterCargoType, setFilterCargoType] = useState('');
  const [filterCOD, setFilterCOD] = useState('');

  const fetchData = async () => {
    setIsLoading(true);
    try {
      const cargoP = fetch('/api/admin/cargo').then(r => r.json()).catch(() => ({}));
      const officeP = fetch('/api/admin/offices').then(r => r.json()).catch(() => ({}));
      const tripP = fetch('/api/admin/trips').then(r => r.json()).catch(() => ({}));
      const routeP = fetch('/api/admin/routes').then(r => r.json()).catch(() => ({}));

      const [cargoData, officeData, tripData, routeData] = await Promise.all([cargoP, officeP, tripP, routeP]);
      
      if (
        (cargoData && cargoData.error === 'Unauthorized') ||
        (tripData && tripData.error === 'Unauthorized') ||
        (officeData && officeData.error === 'Unauthorized') ||
        (routeData && routeData.error === 'Unauthorized')
      ) {
         localStorage.removeItem('user');
         window.location.href = '/auth';
         return;
      }

      setCargos(Array.isArray(cargoData) ? cargoData : []);
      setOffices(Array.isArray(officeData) ? officeData : []);
      setTrips(Array.isArray(tripData) ? tripData : []);
      setRoutes(Array.isArray(routeData) ? routeData : []);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleDelete = async (id) => {
    if (!window.confirm('Bạn có chắc muốn xóa kiện hàng này?')) return;
    try {
      const res = await fetch(`/api/admin/cargo/${id}`, { method: 'DELETE' });
      if (res.ok) fetchData();
    } catch (err) {
      console.error(err);
    }
  };

  const openEdit = (cargo) => {
    setSelectedCargo(cargo);
    setShowModal(true);
  };

  const filteredCargos = cargos.filter(c => {
    const matchesRoute = !selectedRouteId || trips.find(t => t.id === c.trip_id)?.route_id === parseInt(selectedRouteId);
    const matchesTrip = !selectedTripId || c.trip_id === parseInt(selectedTripId);
    const matchesOffice = !filterOfficeId || c.sender_office_id === parseInt(filterOfficeId);
    const matchesReceiverOffice = !filterReceiverOfficeId || c.receiver_office_id === parseInt(filterReceiverOfficeId);
    const matchesStatus = !filterStatus || c.status === filterStatus;
    const matchesPayment = !filterPaymentStatus || c.payment_status === filterPaymentStatus;
    const matchesType = !filterCargoType || c.type === filterCargoType;
    const matchesCOD = !filterCOD || (filterCOD === 'YES' ? c.cod_amount > 0 : c.cod_amount === 0);
    
    const trip = trips.find(t => t.id === c.trip_id);
    // Date filter: Check trip departure OR cargo creation/collection date
    const cargoDate = trip ? trip.departure_time : c.collected_at || c.created_at;
    
    // Always show unassigned and active warehouse cargo so they can be assigned easily
    const isUnassignedWarehouse = !c.trip_id && c.status === 'Received';
    const matchesDate = !selectedDate || isUnassignedWarehouse || (cargoDate && cargoDate.startsWith(selectedDate));

    return matchesRoute && matchesTrip && matchesOffice && matchesReceiverOffice && matchesStatus && matchesPayment && matchesType && matchesCOD && matchesDate;
  });

  const totalCost = filteredCargos.reduce((acc, c) => acc + (c.cost || 0), 0);
  const totalWeight = filteredCargos.reduce((acc, c) => acc + (c.weight || 0), 0);
  const totalCOD = filteredCargos.reduce((acc, c) => acc + (c.cod_amount || 0), 0);

  const availableTrips = trips.filter(t => {
     const matchesRoute = !selectedRouteId || t.route_id === parseInt(selectedRouteId);
     const matchesDate = !selectedDate || t.departure_time.startsWith(selectedDate);
     return matchesRoute && matchesDate;
  });

  return (
    <div className="flex flex-col gap-0 -m-4 bg-[#f0f2f5] min-h-screen font-sans">
      {showModal && (
        <CreateCargoModal 
          onClose={() => { setShowModal(false); setSelectedCargo(null); }} 
          onCreated={() => { setShowModal(false); setSelectedCargo(null); fetchData(); }} 
          offices={offices}
          trips={trips}
          routes={routes}
          currentCargo={selectedCargo}
          onRefresh={fetchData}
        />
      )}
      
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex flex-wrap items-center gap-4 sticky top-0 z-50 shadow-sm">
        <div className="flex items-center gap-3">
           <select 
             className="bg-slate-50 border border-slate-200 rounded-md px-3 py-2 text-xs font-bold text-slate-600 outline-none focus:border-blue-400 w-56 shadow-sm transition-all"
             value={selectedRouteId}
             onChange={e => setSelectedRouteId(e.target.value)}
           >
              <option value="">Tất cả tuyến</option>
              {routes.map(r => <option key={r.id} value={r.id}>{r.start_point} - {r.end_point}</option>)}
           </select>
           <input 
             type="date" 
             className="bg-slate-50 border border-slate-200 rounded-md px-3 py-2 text-xs font-bold text-slate-600 outline-none focus:border-blue-400 shadow-sm transition-all" 
             value={selectedDate}
             onChange={e => setSelectedDate(e.target.value)}
           />
           <select 
             className="bg-slate-50 border border-slate-200 rounded-md px-3 py-2 text-xs font-bold text-slate-600 outline-none focus:border-blue-400 w-48 shadow-sm transition-all"
             value={selectedTripId}
             onChange={e => setSelectedTripId(e.target.value)}
           >
              <option value="">Chọn chuyến</option>
              {availableTrips.map(t => <option key={t.id} value={t.id}>[{t.bus}] {new Date(t.departure_time).toLocaleTimeString('vi-VN', {hour: '2-digit', minute:'2-digit'})}</option>)}
           </select>
        </div>
        
        <div className="flex gap-2 ml-auto">
           <button onClick={() => { setSelectedCargo(null); setShowModal(true); }} className="bg-[#EF5222] text-white px-5 py-2 rounded-md text-xs font-black flex items-center gap-2 hover:bg-[#D43D11] shadow-md shadow-orange-100 transition-all uppercase tracking-widest">
              <Plus size={14} /> Lên hàng
           </button>
           <button 
              onClick={() => {
                if (!selectedTripId) return alert('Vui lòng chọn chuyến xe để in phơi hàng!');
                window.open(`/admin/trip/${selectedTripId}/cargo/pdf`, '_blank');
              }}
              className="bg-white border border-slate-200 text-slate-500 px-5 py-2 rounded-md text-xs font-bold flex items-center gap-2 hover:bg-slate-50 transition-all shadow-sm"
           >
              <Printer size={14} /> Xem Phơi hàng
           </button>
        </div>
      </div>

      <div className="px-6 py-4 bg-white border-b border-slate-100 flex items-center gap-4 shadow-sm">
         <span className="text-[12px] font-black text-slate-800 uppercase tracking-widest border-r border-slate-200 pr-4">KHO GỬI</span>
         <div className="flex gap-6 text-[11px] font-bold text-slate-500 overflow-x-auto no-scrollbar">
            <span>Tổng: Đơn: <span className="text-slate-900 font-black">{filteredCargos.length}</span></span>
            <span>SL: <span className="text-slate-900 font-black">{filteredCargos.length}</span></span>
            <span>Món: <span className="text-slate-900 font-black">{filteredCargos.length}</span></span>
            <span>KG: <span className="text-slate-900 font-black">{totalWeight}</span></span>
            <span>CC: <span className="text-[#EF5222] font-black">{totalCost.toLocaleString()} đ</span></span>
            <span>Thu hộ: <span className="text-blue-600 font-black">{totalCOD.toLocaleString()} đ</span></span>
         </div>
      </div>

      <div className="px-6 py-4 bg-[#f8fafc] border-b border-slate-200 relative z-20">
         <div className="flex flex-col gap-4">
            <div className="flex items-center gap-3">
               <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest min-w-[30px]">Lọc</span>
               
               <select 
                  className="bg-blue-600 text-white px-4 py-2 rounded-md text-xs font-black uppercase tracking-widest outline-none shadow-md hover:bg-blue-700 transition-all w-56 cursor-pointer border-none"
                  value={filterOfficeId}
                  onChange={e => setFilterOfficeId(e.target.value)}
               >
                  <option value="">Văn phòng gửi</option>
                  {offices.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
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

      <div className="flex-1 bg-white overflow-hidden m-6 rounded-2xl shadow-xl shadow-slate-200/50 border border-slate-200">
        <div className="overflow-x-auto h-full">
          <table className="w-full text-left border-collapse min-w-[1200px]">
            <thead className="bg-[#f8fafc] text-[10px] font-black text-slate-500 uppercase border-b border-slate-100 sticky top-0 z-10">
              <tr>
                <th className="px-4 py-4 w-12 text-center border-r border-slate-100 bg-[#f8fafc]"><input type="checkbox" className="rounded-sm border-slate-300" /></th>
                <th className="px-4 py-4 border-r border-slate-100">Chi tiết <ChevronDown size={10} className="inline ml-1" /></th>
                <th className="px-4 py-4 border-r border-slate-100">Tên món hàng <br/><span className="text-[8px] text-slate-400 font-medium">Ghi chú</span></th>
                <th className="px-4 py-4 w-24 border-r border-slate-100">CR <br/><span className="text-[8px] text-slate-400 font-medium">HTTT</span></th>
                <th className="px-4 py-4 w-28 border-r border-slate-100">CC</th>
                <th className="px-4 py-4 w-40 border-r border-slate-100">Số ĐT <br/><span className="text-[8px] text-slate-400 font-medium">Người nhận</span></th>
                <th className="px-4 py-4 w-48 border-r border-slate-100">ĐC giao <br/><span className="text-[8px] text-slate-400 font-medium">VP nhận</span></th>
                <th className="px-4 py-4 w-40 border-r border-slate-100">Số ĐT <br/><span className="text-[8px] text-slate-400 font-medium">Người gửi</span></th>
                <th className="px-4 py-4 w-48 border-r border-slate-100">ĐC lấy <br/><span className="text-[8px] text-slate-400 font-medium">VP gửi</span></th>
                <th className="px-4 py-4 text-center">Tác vụ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr><td colSpan="10" className="text-center py-20 text-slate-300 font-black italic animate-pulse tracking-widest uppercase text-xs">Đang truy xuất dữ liệu từ máy chủ...</td></tr>
              ) : filteredCargos.length === 0 ? (
                <tr><td colSpan="10" className="text-center py-24">
                   <div className="flex flex-col items-center gap-3 text-slate-300">
                      <Package size={64} strokeWidth={1} />
                      <span className="font-black italic uppercase text-xs tracking-widest">Không có dữ liệu kiện hàng phù hợp</span>
                   </div>
                </td></tr>
              ) : filteredCargos.map((cargo, idx) => (
                <tr key={cargo.id} className="hover:bg-blue-50/30 transition-colors text-xs font-bold text-slate-600 group">
                  <td className="px-4 py-4 text-center border-r border-slate-50"><input type="checkbox" className="rounded-sm border-slate-300" /></td>
                  <td className="px-4 py-4 border-r border-slate-50">
                     <div className="text-blue-500 text-[10px] font-black uppercase">1 loại</div>
                     <div className="text-slate-400 text-[9px] font-medium italic">{cargo.type || 'Hàng thường'}</div>
                     {cargo.payment_status === 'PAID' ? (
                        <div className="mt-1 flex items-center gap-1 text-[8px] text-green-600 font-black uppercase"><Wallet size={10} /> Đã thu</div>
                     ) : (
                        <div className="mt-1 flex items-center gap-1 text-[8px] text-red-500 font-black uppercase"><CreditCard size={10} /> Chưa thu</div>
                     )}
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50 font-black text-slate-800">
                     {cargo.description}
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50">
                     <div className="text-slate-400 font-medium">-</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50">
                     <div className="text-[#EF5222] font-black text-sm">{(cargo.cost || 0).toLocaleString()}</div>
                     {cargo.cod_amount > 0 && (
                        <div className="text-[8px] text-blue-600 font-black mt-1 uppercase">COD: {cargo.cod_amount.toLocaleString()}</div>
                     )}
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50">
                     <div className="text-slate-900 font-black tracking-tight">{cargo.receiver_phone}</div>
                     <div className="text-slate-400 font-bold uppercase text-[9px]">{cargo.receiver_name}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50">
                     <div className="text-green-600 font-black uppercase text-[9px] mb-1 flex items-center gap-1"><MapPin size={10} /> ĐĐ: {cargo.receiver_office || 'N/A'}</div>
                     <div className="text-slate-400 text-[8px] font-medium">VP {cargo.receiver_office || 'N/A'}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50">
                     <div className="text-slate-900 font-black tracking-tight">{cargo.sender_phone}</div>
                     <div className="text-slate-400 font-bold uppercase text-[9px]">{cargo.sender_name}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-50">
                     <div className="text-green-600 font-black uppercase text-[9px] mb-1 flex items-center gap-1"><MapPin size={10} /> ĐĐ: {cargo.sender_office || 'N/A'}</div>
                     <div className="text-slate-400 text-[8px] font-medium">VP {cargo.sender_office || 'N/A'}</div>
                  </td>
                  <td className="px-4 py-4">
                     <div className="flex items-center justify-center gap-1 opacity-40 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => openEdit(cargo)} title="Chỉnh sửa" className="w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center hover:bg-blue-600 shadow-md transition-all active:scale-90"><Edit2 size={14} /></button>
                        <button onClick={() => handleDelete(cargo.id)} title="Hủy đơn" className="w-8 h-8 bg-red-500 text-white rounded-full flex items-center justify-center hover:bg-red-600 shadow-md transition-all active:scale-90"><Trash2 size={14} /></button>
                        <button 
                           onClick={() => window.open(`/api/admin/cargo/${cargo.id}/receipt`, '_blank')}
                           title="In biên nhận" 
                           className="w-8 h-8 bg-white text-slate-400 border border-slate-200 rounded-full flex items-center justify-center hover:bg-slate-50 transition-all shadow-sm"
                        >
                           <Printer size={14} />
                        </button>
                        <button title="Lịch sử" className="w-8 h-8 bg-white text-slate-400 border border-slate-200 rounded-full flex items-center justify-center hover:bg-slate-50 transition-all"><Clock size={14} /></button>
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

export default Cargo;
