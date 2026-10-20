import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bus, MapPin, Calendar, Users, Filter, Search, Plus, MoreVertical, Download, Printer, XCircle, FileText, CheckCircle, UserX, Package, RefreshCw, ChevronRight, Clock, AlertTriangle, TrendingUp, ChevronDown, Hash, UserSearch, X, ExternalLink, Navigation, Compass } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const TripDetailsModal = ({ trip, onClose }) => {
  const [passengers, setPassengers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeMapPassenger, setActiveMapPassenger] = useState(null);

  useEffect(() => {
    fetch(`/api/admin/trip/${trip.id}/passengers`)
      .then(res => res.json())
      .then(data => {
        setPassengers(data);
        setIsLoading(false);
      });
  }, [trip.id]);

  const gpsPassengers = passengers.filter(p => p.pickup_lat && p.pickup_lng);

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[200] flex items-center justify-center p-4 md:p-6">
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="bg-white w-full max-w-5xl rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh]">
        {/* Header */}
        <div className="bg-[#f8f9fa] border-b border-slate-200 px-6 py-4 flex justify-between items-center">
          <div>
            <div className="flex items-center gap-3">
              <h2 className="text-lg font-bold text-slate-800 uppercase tracking-tight">{trip.route}</h2>
              <span className="text-[11px] font-black text-slate-400 uppercase tracking-widest bg-white border px-2 py-0.5 rounded">Mã chuyến #HB-{trip.id}</span>
              <span className="text-[11px] font-black text-blue-600 uppercase tracking-widest bg-blue-50 border border-blue-100 px-2 py-0.5 rounded">{trip.bus}</span>
            </div>
            <div className="flex items-center gap-3 mt-1.5 text-xs text-slate-500 font-medium">
              <span>Tổng số: <b>{passengers.length}</b> hành khách</span>
              <span>•</span>
              <span className="text-emerald-700 font-bold bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full inline-flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                {gpsPassengers.length} hành khách đã gửi định vị GPS
              </span>
            </div>
          </div>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600 transition-colors">
            <XCircle size={26} />
          </button>
        </div>

        {/* Passenger List Body */}
        <div className="flex-1 overflow-y-auto p-6 bg-slate-50">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
             {isLoading ? (
                <div className="col-span-full py-24 text-center">
                   <RefreshCw className="animate-spin mx-auto text-slate-300 mb-4" size={40} />
                   <div className="text-slate-400 font-bold italic">Đang tải danh sách hành khách...</div>
                </div>
             ) : passengers.length === 0 ? (
                <div className="col-span-full py-24 text-center">
                   <Users className="mx-auto text-slate-200 mb-4 opacity-30" size={64} />
                   <div className="text-slate-400 font-bold italic text-lg">Chưa có khách đặt vé cho chuyến này.</div>
                </div>
             ) : passengers.map(p => {
                const hasGps = p.pickup_lat && p.pickup_lng;
                return (
                  <div key={p.id} className="p-4 rounded-xl bg-white shadow-sm border border-slate-200 flex flex-col justify-between group hover:shadow-md transition-all">
                    <div>
                      {/* Passenger Header */}
                      <div className="flex items-center gap-3">
                        <div className={`w-11 h-11 rounded-xl border flex items-center justify-center font-black text-sm shrink-0 ${p.boarding_status === 'BOARDED' ? 'bg-green-600 border-green-600 text-white shadow-sm' : 'bg-slate-100 border-slate-200 text-slate-600'}`}>
                          {p.seat}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="font-bold text-slate-800 text-sm truncate uppercase flex items-center gap-1.5">
                            <span className="truncate">{p.name}</span>
                            {p.boarding_status === 'BOARDED' && <CheckCircle size={15} className="text-green-600 shrink-0" />}
                          </div>
                          <div className="text-xs text-slate-400 font-semibold tracking-tight mt-0.5">{p.phone}</div>
                        </div>
                      </div>

                      {/* Pickup location information */}
                      <div className="mt-3 text-xs space-y-1">
                        <div className="flex items-start gap-1.5 text-slate-700">
                          <MapPin size={14} className="text-orange-500 shrink-0 mt-0.5" />
                          <div className="font-medium">
                            <span className="text-[10px] text-slate-400 uppercase font-black block">Điểm đón khách:</span>
                            <span className="text-slate-800 font-bold">{p.pickup_landmark || p.pickup || 'Bến xe xuất phát'}</span>
                          </div>
                        </div>

                        {p.pickup_note && (
                          <div className="text-[11px] text-amber-800 bg-amber-50 border border-amber-200/60 rounded px-2 py-1 mt-1">
                            <b>Ghi chú:</b> {p.pickup_note}
                          </div>
                        )}
                      </div>
                    </div>

                    {/* GPS Location & Live Actions */}
                    <div className="mt-3 pt-2.5 border-t border-slate-100">
                      {hasGps ? (
                        <div className="space-y-1.5">
                          <div className="flex items-center justify-between">
                            <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-700 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping"></span>
                              GPS: {p.pickup_lat.toFixed(4)}, {p.pickup_lng.toFixed(4)}
                            </span>
                            <span className="text-[10px] font-bold text-slate-400">Thiết bị hành khách</span>
                          </div>

                          <div className="grid grid-cols-2 gap-1.5 pt-1">
                            <button
                              onClick={() => setActiveMapPassenger(p)}
                              className="px-2 py-1.5 bg-blue-50 hover:bg-blue-100 text-blue-700 border border-blue-200 rounded-lg text-[11px] font-bold flex items-center justify-center gap-1 transition-all"
                            >
                              <Compass size={12} /> Xem bản đồ
                            </button>
                            <a
                              href={`https://www.google.com/maps/dir/?api=1&destination=${p.pickup_lat},${p.pickup_lng}`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="px-2 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-[11px] font-bold flex items-center justify-center gap-1 shadow-sm transition-all"
                            >
                              <Navigation size={12} /> Chỉ đường
                            </a>
                          </div>
                        </div>
                      ) : (
                        <div className="text-[11px] text-slate-400 italic flex items-center gap-1">
                          <span>Chưa có tọa độ GPS (Đón theo điểm mặc định)</span>
                        </div>
                      )}
                    </div>
                  </div>
                );
             })}
          </div>
        </div>

        {/* Footer */}
        <div className="bg-[#f8f9fa] border-t border-slate-200 px-6 py-4 flex gap-3 justify-end items-center">
           <button className="px-5 py-2 bg-white border border-slate-200 rounded-lg text-xs font-bold text-slate-600 hover:bg-slate-50 transition-all flex items-center gap-2">
             <Printer size={14} /> In phơi khách
           </button>
           <button className="px-5 py-2 bg-orange-500 text-white rounded-lg text-xs font-bold hover:bg-orange-600 transition-all flex items-center gap-2 shadow-sm uppercase tracking-widest">
             <FileText size={14} /> Lệnh vận chuyển
           </button>
        </div>
      </motion.div>

      {/* Embedded Live Map Modal */}
      {activeMapPassenger && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-[250] flex items-center justify-center p-4">
          <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="bg-white rounded-2xl w-full max-w-3xl overflow-hidden shadow-2xl flex flex-col max-h-[85vh]">
            <div className="bg-slate-900 text-white px-5 py-3.5 flex justify-between items-center">
              <div>
                <div className="text-xs text-orange-400 font-bold uppercase tracking-wider">Vị trí thực tế hành khách đang đứng</div>
                <div className="text-base font-bold flex items-center gap-2 mt-0.5">
                  <span>Ghế {activeMapPassenger.seat} • {activeMapPassenger.name} ({activeMapPassenger.phone})</span>
                </div>
              </div>
              <button onClick={() => setActiveMapPassenger(null)} className="text-slate-400 hover:text-white transition-colors">
                <XCircle size={24} />
              </button>
            </div>

            <div className="p-4 bg-slate-100 flex-1 flex flex-col">
              <div className="bg-white p-3 rounded-xl border border-slate-200 mb-3 flex items-center justify-between text-xs">
                <div>
                  <span className="font-bold text-slate-800">Điểm đón: </span>
                  <span className="text-slate-600">{activeMapPassenger.pickup_landmark || activeMapPassenger.pickup}</span>
                  <div className="text-[11px] text-slate-400 mt-0.5">Tọa độ: {activeMapPassenger.pickup_lat}, {activeMapPassenger.pickup_lng}</div>
                </div>
                <a
                  href={`https://www.google.com/maps?q=${activeMapPassenger.pickup_lat},${activeMapPassenger.pickup_lng}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="px-3 py-1.5 bg-blue-600 text-white rounded-lg font-bold flex items-center gap-1.5 hover:bg-blue-700 transition-all shadow-sm"
                >
                  <ExternalLink size={13} /> Mở Google Maps
                </a>
              </div>

              {/* OpenStreetMap interactive live iframe */}
              <div className="flex-1 w-full rounded-xl overflow-hidden border border-slate-300 min-h-[380px] bg-white shadow-inner relative">
                <iframe
                  title="Passenger Live Location"
                  width="100%"
                  height="100%"
                  frameBorder="0"
                  scrolling="no"
                  marginHeight="0"
                  marginWidth="0"
                  src={`https://www.openstreetmap.org/export/embed.html?bbox=${activeMapPassenger.pickup_lng - 0.008}%2C${activeMapPassenger.pickup_lat - 0.008}%2C${activeMapPassenger.pickup_lng + 0.008}%2C${activeMapPassenger.pickup_lat + 0.008}&layer=mapnik&marker=${activeMapPassenger.pickup_lat}%2C${activeMapPassenger.pickup_lng}`}
                  className="w-full h-full min-h-[380px]"
                />
              </div>
            </div>

            <div className="bg-white border-t border-slate-200 px-5 py-3 flex justify-between items-center">
              <div className="text-xs text-slate-500 font-medium">
                Vị trí được cập nhật trực tiếp từ cảm biến GPS thiết bị của hành khách khi chụp ảnh xác nhận điểm đón.
              </div>
              <button
                onClick={() => setActiveMapPassenger(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-xs font-bold transition-all"
              >
                Đóng bản đồ
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </div>
  );
};

const Trips = () => {
  const [trips, setTrips] = useState([]);
  const [routes, setRoutes] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedTrip, setSelectedTrip] = useState(null);
  const [showCreate, setShowCreate] = useState(false);
  
  // Filters
  const [activeTab, setActiveTab] = useState('current'); 
  const [selectedRouteId, setSelectedRouteId] = useState('');
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);
  const [passengerSearch, setPassengerSearch] = useState('');
  const [passengerResults, setPassengerResults] = useState([]);
  const [isSearchingPax, setIsSearchingPax] = useState(false);

  const navigate = useNavigate();

  const fetchTrips = () => {
    setIsLoading(true);
    fetch('/api/admin/trips')
      .then(res => res.json())
      .then(data => { 
        if (data && data.error === 'Unauthorized') {
           localStorage.removeItem('user');
           window.location.href = '/auth';
           return;
        }
        setTrips(Array.isArray(data) ? data : []); 
        setIsLoading(false); 
      })
      .catch(() => setIsLoading(false));
  };

  const fetchRoutes = () => {
    fetch('/api/admin/routes')
      .then(res => res.json())
      .then(data => {
        if (data && data.error === 'Unauthorized') {
           localStorage.removeItem('user');
           window.location.href = '/auth';
           return;
        }
        setRoutes(Array.isArray(data) ? data : []);
      })
      .catch(() => {});
  };

  useEffect(() => { 
    fetchTrips(); 
    fetchRoutes();
  }, []);

  const handlePassengerSearch = async (val) => {
    setPassengerSearch(val);
    if (val.length < 2) {
      setPassengerResults([]);
      return;
    }
    setIsSearchingPax(true);
    try {
      const res = await fetch(`/api/admin/passengers/search?q=${encodeURIComponent(val)}`);
      const data = await res.json();
      setPassengerResults(data);
    } catch (err) {
      console.error(err);
    } finally {
      setIsSearchingPax(false);
    }
  };

  const openTripFromPax = (pax) => {
    const trip = trips.find(t => t.id === pax.trip_id);
    if (trip) {
      setSelectedTrip(trip);
      setPassengerSearch('');
      setPassengerResults([]);
    } else {
      // If trip not in current list (maybe completed/hidden), we can fetch it
      fetch(`/api/admin/trip/${pax.trip_id}`)
        .then(res => res.json())
        .then(tripData => {
           setSelectedTrip(tripData);
           setPassengerSearch('');
           setPassengerResults([]);
        });
    }
  };

  const filteredTrips = trips.filter(t => {
    const matchesTab = activeTab === 'current' ? t.status !== 'Completed' : t.status === 'Completed';
    const matchesRoute = !selectedRouteId || t.route_id === parseInt(selectedRouteId);
    const matchesDate = !selectedDate || t.departure_time.startsWith(selectedDate);
    return matchesTab && matchesRoute && matchesDate;
  });

  return (
    <div className="flex flex-col gap-0 -m-4 bg-white min-h-screen font-sans text-slate-700">
      <AnimatePresence>
        {selectedTrip && <TripDetailsModal trip={selectedTrip} onClose={() => setSelectedTrip(null)} />}
        {showCreate && <CreateTripModal onClose={() => setShowCreate(false)} onCreated={() => { setShowCreate(false); fetchTrips(); }} />}
      </AnimatePresence>

      {/* Professional Filter Bar (Kho gửi style) */}
      <div className="bg-[#e9ecef] border-b border-slate-300 px-6 py-3 flex flex-wrap items-center gap-3">
         <div className="flex flex-col">
            <label className="text-[10px] font-bold text-slate-500 uppercase mb-1">Tuyến đường</label>
            <select 
              className="bg-white border border-slate-300 rounded px-3 py-1.5 text-sm w-64 outline-none focus:border-blue-400 shadow-sm font-bold"
              value={selectedRouteId} onChange={e => setSelectedRouteId(e.target.value)}
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
                 className="bg-white border border-slate-300 rounded px-3 py-1.5 text-sm outline-none focus:border-blue-400 shadow-sm font-bold" 
                 value={selectedDate} onChange={e => setSelectedDate(e.target.value)}
               />
               <button onClick={() => setSelectedDate('')} className={`px-2 text-[10px] font-black rounded border transition-all ${!selectedDate ? 'bg-blue-600 text-white' : 'bg-white text-slate-400'}`}>TẤT CẢ</button>
            </div>
         </div>

         {/* Passenger Search Section */}
         <div className="flex flex-col relative">
            <label className="text-[10px] font-bold text-slate-500 uppercase mb-1">Tìm kiếm khách hàng</label>
            <div className="relative group">
               <UserSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500" size={16} />
               <input 
                 type="text" 
                 placeholder="Tên hoặc SĐT khách..." 
                 className="bg-white border border-slate-300 rounded pl-10 pr-3 py-1.5 text-sm w-72 outline-none focus:border-blue-400 shadow-sm font-bold"
                 value={passengerSearch}
                 onChange={e => handlePassengerSearch(e.target.value)}
               />
               {isSearchingPax && <RefreshCw size={14} className="absolute right-3 top-1/2 -translate-y-1/2 animate-spin text-blue-500" />}
            </div>

            <AnimatePresence>
               {passengerResults.length > 0 && (
                  <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} className="absolute top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded shadow-2xl z-[150] max-h-80 overflow-y-auto">
                     {passengerResults.map(pax => (
                        <button key={pax.id} onClick={() => openTripFromPax(pax)} className="w-full text-left px-4 py-3 hover:bg-blue-50 border-b border-slate-50 last:border-0 transition-colors group">
                           <div className="flex justify-between items-start">
                              <div className="font-black text-slate-800 text-xs uppercase">{pax.name}</div>
                              <div className="text-[10px] font-black text-blue-600 bg-blue-50 px-1.5 rounded">{pax.seat}</div>
                           </div>
                           <div className="text-[10px] text-slate-500 font-bold mt-0.5">{pax.phone}</div>
                           <div className="mt-2 flex items-center gap-1 text-[9px] font-black text-slate-400 uppercase tracking-tighter">
                              <Bus size={10} /> {pax.trip_route}
                           </div>
                           <div className="text-[8px] text-slate-400 mt-0.5 font-medium">{new Date(pax.departure_time).toLocaleString('vi-VN')}</div>
                        </button>
                     ))}
                  </motion.div>
               )}
            </AnimatePresence>
         </div>

         <div className="flex items-end h-full pt-4 ml-auto">
            <button onClick={() => setShowCreate(true)} className="px-6 py-2.5 bg-orange-500 text-white rounded text-sm font-black flex items-center gap-2 shadow-md hover:bg-orange-600 transition-all uppercase tracking-widest">
               <Plus size={18} /> THÊM CHUYẾN MỚI
            </button>
         </div>
      </div>

      <div className="px-6 py-4 bg-white border-b border-slate-100 flex flex-wrap items-center gap-4 shadow-sm">
         <span className="text-[12px] font-black text-slate-800 uppercase tracking-widest border-r border-slate-200 pr-4">LỊCH TRÌNH</span>
         
         <div className="flex bg-[#f1f3f5] p-1 rounded-md">
            {['current', 'history'].map(tab => (
               <button key={tab} onClick={() => setActiveTab(tab)} className={`px-4 py-1.5 rounded text-[10px] font-black uppercase tracking-widest transition-all ${activeTab === tab ? 'bg-white text-orange-600 shadow-sm' : 'text-slate-400 hover:text-slate-600'}`}>
                  {tab === 'current' ? 'Đang hoạt động' : 'Lịch sử chuyến'}
               </button>
            ))}
         </div>

         <div className="flex gap-6 text-[11px] font-bold text-slate-500 overflow-x-auto no-scrollbar ml-auto">
            <span>Đang chạy: <span className="text-blue-600 font-black">{trips.filter(t => t.status === 'Running').length}</span></span>
            <span>Chờ xuất bến: <span className="text-orange-500 font-black">{trips.filter(t => t.status === 'Scheduled').length}</span></span>
            <span>Đã hoàn thành: <span className="text-green-600 font-black">{trips.filter(t => t.status === 'Completed').length}</span></span>
         </div>
      </div>

      <div className="flex-1 bg-white overflow-hidden m-6 rounded shadow-sm border border-slate-200">
        <div className="overflow-x-auto h-full">
          <table className="w-full text-left border-collapse min-w-[1200px]">
            <thead className="bg-[#f8f9fa] text-[12px] font-bold text-slate-700 border-b border-slate-200 sticky top-0 z-10">
              <tr>
                <th className="px-3 py-3 w-10 text-center border-r border-slate-200 bg-[#f8f9fa]"><input type="checkbox" className="rounded-sm border-slate-300 w-4 h-4 cursor-pointer" /></th>
                <th className="px-4 py-3 border-r border-slate-200">Thông tin Tuyến đường <ChevronDown size={12} className="inline ml-1" /></th>
                <th className="px-4 py-3 w-32 border-r border-slate-200">Xe vận hành</th>
                <th className="px-4 py-3 w-40 border-r border-slate-200 text-center">Thời gian đi</th>
                <th className="px-4 py-3 w-40 border-r border-slate-200">Lấp đầy / Ghế</th>
                <th className="px-4 py-3 w-40 border-r border-slate-200 text-center">Trạng thái</th>
                <th className="px-4 py-3 text-center">Tác vụ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr><td colSpan="7" className="text-center py-20 text-slate-400 italic">Đang đồng bộ dữ liệu lịch trình...</td></tr>
              ) : filteredTrips.length === 0 ? (
                <tr><td colSpan="7" className="text-center py-24">
                   <div className="flex flex-col items-center gap-3 text-slate-300">
                      <Bus size={64} strokeWidth={1} />
                      <span className="font-black italic uppercase text-xs tracking-widest">Không có lịch trình phù hợp</span>
                   </div>
                </td></tr>
              ) : filteredTrips.map((trip) => (
                <tr key={trip.id} className="hover:bg-slate-50 transition-colors text-[13px] text-slate-600 group">
                  <td className="px-3 py-4 text-center border-r border-slate-100"><input type="checkbox" className="rounded-sm border-slate-300 w-4 h-4 cursor-pointer" /></td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-orange-100 text-orange-600 rounded flex items-center justify-center font-black">
                           <Bus size={18} />
                        </div>
                        <div>
                           <div className="text-slate-800 text-sm font-black uppercase">{trip.route}</div>
                           <div className="text-[9px] text-slate-400 font-medium tracking-widest mt-0.5">MÃ CHUYẾN: #HB-{trip.id}</div>
                        </div>
                     </div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="text-blue-600 font-black text-sm tracking-tight">{trip.bus}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100 text-center">
                     <div className="text-slate-900 font-black text-sm leading-none">{new Date(trip.departure_time).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</div>
                     <div className="text-[10px] text-slate-400 font-bold mt-1 uppercase tracking-tighter">{new Date(trip.departure_time).toLocaleDateString('vi-VN')}</div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100">
                     <div className="flex flex-col gap-1.5 w-full">
                        <div className="flex justify-between items-end">
                           <span className="text-[9px] font-black text-slate-400 uppercase">Hệ số</span>
                           <span className="text-[10px] font-black text-slate-800">{trip.occupancy}</span>
                        </div>
                        <div className="h-1.5 bg-slate-100 rounded-full overflow-hidden border border-slate-200">
                           <div 
                             className={`h-full rounded-full transition-all duration-1000 ${
                                (parseInt(trip.occupancy.split('/')[0]) / parseInt(trip.occupancy.split('/')[1])) > 0.8 ? 'bg-orange-500' : 'bg-green-500'
                             }`}
                             style={{ width: `${(parseInt(trip.occupancy.split('/')[0]) / parseInt(trip.occupancy.split('/')[1]) * 100)}%` }}
                           />
                        </div>
                     </div>
                  </td>
                  <td className="px-4 py-4 border-r border-slate-100 text-center">
                    <div className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded border text-[9px] font-black uppercase tracking-widest ${
                      trip.status === 'Running' ? 'bg-green-50 border-green-200 text-green-700' : 
                      trip.status === 'Scheduled' ? 'bg-blue-50 border-blue-200 text-blue-700' : 
                      trip.status === 'Broken' ? 'bg-red-50 border-red-200 text-red-700' : 'bg-slate-100 border-slate-200 text-slate-500'
                    }`}>
                      {trip.status === 'Running' ? 'Đang chạy' : 
                       trip.status === 'Scheduled' ? 'Chờ chạy' : 
                       trip.status === 'Broken' ? 'Sự cố' : 'Hoàn thành'}
                    </div>
                  </td>
                  <td className="px-4 py-4">
                     <div className="flex items-center justify-center gap-1.5 opacity-60 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => setSelectedTrip(trip)} className="w-8 h-8 bg-blue-500 text-white rounded flex items-center justify-center hover:bg-blue-600 shadow transition-all active:scale-90" title="Chi tiết khách"><Users size={14} /></button>
                        <button onClick={() => navigate(`/admin/manifest/${trip.id}`)} className="w-8 h-8 bg-green-600 text-white rounded flex items-center justify-center hover:bg-green-700 shadow transition-all active:scale-90" title="Phơi hàng"><Package size={14} /></button>
                        <button className="w-8 h-8 bg-white border border-slate-200 text-slate-400 rounded flex items-center justify-center hover:bg-slate-50 transition-all" title="In vé"><Printer size={14} /></button>
                        <button className="w-8 h-8 bg-white border border-slate-200 text-red-400 rounded flex items-center justify-center hover:bg-red-50 transition-all" title="Hủy chuyến"><XCircle size={14} /></button>
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

const CreateTripModal = ({ onClose, onCreated }) => {
  const [formData, setFormData] = useState({
    route_id: '',
    bus_id: '',
    driver_id: '',
    departure_time: ''
  });
  const [data, setData] = useState({ routes: [], buses: [], drivers: [] });
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    fetch('/api/admin/routes').then(r => r.json()).then(res => setData(p => ({ ...p, routes: Array.isArray(res) ? res : [] })));
  }, []);

  useEffect(() => {
    let urlBus = '/api/admin/buses';
    let urlDriver = '/api/admin/staff/DRIVER';
    if (formData.departure_time && formData.route_id) {
       urlBus += `?departure_time=${formData.departure_time}&route_id=${formData.route_id}`;
       urlDriver += `?departure_time=${formData.departure_time}&route_id=${formData.route_id}`;
    }
    fetch(urlBus).then(r => r.json()).then(res => {
      setData(p => ({ ...p, buses: Array.isArray(res) ? res : [] }));
      // If current bus is no longer in the list, clear it
      if (Array.isArray(res) && formData.bus_id && !res.find(b => b.id == formData.bus_id)) {
        setFormData(prev => ({ ...prev, bus_id: '' }));
      }
    });
    fetch(urlDriver).then(r => r.json()).then(res => {
      setData(p => ({ ...p, drivers: Array.isArray(res) ? res : [] }));
      // If current driver is no longer in the list, clear it
      if (Array.isArray(res) && formData.driver_id && !res.find(d => d.id == formData.driver_id)) {
        setFormData(prev => ({ ...prev, driver_id: '' }));
      }
    });
  }, [formData.departure_time, formData.route_id]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const response = await fetch('/api/admin/trips', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      const resData = await response.json().catch(() => ({}));
      if (response.ok) {
        onCreated();
      } else {
        alert(resData.error || resData.message || 'Lỗi khi lưu chuyến xe!');
      }
    } catch (err) {
      alert('Lỗi kết nối máy chủ: ' + err.message);
    }
    setIsSubmitting(false);
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[210] flex items-center justify-center p-6">
      <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="bg-white w-full max-w-lg rounded-lg shadow-2xl overflow-hidden">
        <div className="bg-[#f8f9fa] border-b border-slate-200 px-6 py-4 flex justify-between items-center">
           <h2 className="text-lg font-bold text-slate-800 flex items-center gap-3 uppercase">
              <Bus className="text-orange-500" size={20} />
              Thêm chuyến mới
           </h2>
           <button onClick={onClose} className="text-slate-400 hover:text-slate-600"><XCircle size={24} /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          <div className="space-y-1">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Tuyến đường vận hành</label>
            <select className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required
              value={formData.route_id} onChange={e => setFormData({...formData, route_id: e.target.value})}>
              <option value="">-- Chọn tuyến đường --</option>
              {data.routes.map(r => <option key={r.id} value={r.id}>{r.start_point} ➝ {r.end_point}</option>)}
            </select>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1">
              <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Xe vận hành</label>
              <select className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required
                value={formData.bus_id} onChange={e => setFormData({...formData, bus_id: e.target.value})}>
                <option value="">-- Chọn xe --</option>
                {data.buses.map(b => <option key={b.id} value={b.id}>{b.license_plate} ({b.type})</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Tài xế</label>
              <select className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required
                value={formData.driver_id} onChange={e => setFormData({...formData, driver_id: e.target.value})}>
                <option value="">-- Chọn tài xế --</option>
                {data.drivers.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
              </select>
            </div>
          </div>
          <div className="space-y-1">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Thời gian xuất bến</label>
            <input type="datetime-local" className="w-full bg-white border border-slate-200 rounded py-2 px-3 text-sm font-bold text-slate-700 outline-none focus:border-orange-400 shadow-sm" required
              value={formData.departure_time} onChange={e => setFormData({...formData, departure_time: e.target.value})} />
          </div>
          <div className="flex gap-3 pt-4">
            <button type="button" onClick={onClose} className="flex-1 py-2.5 font-bold text-slate-500 hover:bg-slate-100 rounded transition-all">Hủy bỏ</button>
            <button type="submit" disabled={isSubmitting} className="flex-2 px-8 py-2.5 bg-orange-500 text-white font-bold rounded shadow-md hover:bg-orange-600 transition-all flex items-center justify-center gap-2 uppercase text-sm tracking-wider">
              {isSubmitting ? <RefreshCw className="animate-spin" size={16} /> : <Plus size={18} />} 
              Lưu chuyến xe
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};

export default Trips;
