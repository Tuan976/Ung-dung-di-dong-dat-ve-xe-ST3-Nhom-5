import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Printer, FileText, ArrowLeft, Bus, MapPin, Calendar, Users, CheckCircle, Plus, Phone, DollarSign, MapPin as MapPinIcon, MoreVertical, Trash2, Save, XCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const getDefaultStation = (city, isDestination) => {
  if (!city) return '';
  const c = city.toLowerCase().replace('tp.', '').trim();
  
  if (c.includes('hồ chí minh') || c === 'hcm' || c === 'ho chi minh') {
    return isDestination ? 'Bến xe Miền Đông' : 'VP.HCM';
  }
  if (c.includes('hà nội') || c === 'hn' || c === 'ha noi') {
    return 'Bến xe Nước Ngầm';
  }
  if (c.includes('cư jut') || c.includes('cư jút')) {
    return 'VP.Cư Jut';
  }
  if (c.includes('đắk mil') || c.includes('đak mil')) {
    return 'Văn phòng Đắk Mil';
  }
  if (c.includes('gia nghĩa') || c.includes('gia nghia')) {
    return 'Văn phòng Gia Nghĩa';
  }
  if (c.includes('đắk nông') || c.includes('đak nông')) {
    return 'Văn phòng Gia Nghĩa';
  }
  if (c.includes('kiến đức') || c.includes('kien duc')) {
    return 'Văn phòng Kiến Đức';
  }
  if (c.includes('đà lạt') || c.includes('da lat') || c.includes('lâm đồng')) {
    return 'Bến xe Đà Lạt';
  }
  if (c.includes('nha trang')) {
    return 'Bến xe Nha Trang';
  }
  if (c.includes('đà nẵng') || c.includes('da nang')) {
    return 'Bến xe Đà Nẵng';
  }
  if (c.includes('cần thơ') || c.includes('can tho')) {
    return 'Bến xe Cần Thơ';
  }
  if (c.includes('gia lai')) {
    return 'Bến xe Gia Lai';
  }
  if (c.includes('đak đoa')) {
    return 'Bến xe Đak Đoa';
  }
  if (c.includes('đắk lắk') || c.includes('dak lak')) {
    return 'Bến xe Buôn Ma Thuột';
  }
  if (c.includes('vũng tàu') || c.includes('vung tau')) {
    return 'Bến xe Vũng Tàu';
  }
  if (c.includes('bạc liêu') || c.includes('bac lieu')) {
    return 'Bến xe Bạc Liêu';
  }
  return city;
};

const Manifest = () => {
  const { tripId } = useParams();
  const navigate = useNavigate();
  const [trip, setTrip] = useState(null);
  const [passengers, setPassengers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [deck, setDeck] = useState('lower');
  
  // Booking Modal State
  const [showBookingModal, setShowBookingModal] = useState(false);
  const [selectedSeat, setSelectedSeat] = useState(null);
  const [editingBooking, setEditingBooking] = useState(null);
  const [bookingForm, setBookingForm] = useState({ name: '', phone: '', pickup: '', dropoff: '', price: '100000' });
  const [isBooking, setIsBooking] = useState(false);

  const fetchData = async () => {
    try {
      const [tripRes, passRes] = await Promise.all([
        fetch(`/api/admin/trip/${tripId}`),
        fetch(`/api/admin/trip/${tripId}/passengers`)
      ]);
      const tripData = await tripRes.json();
      const passData = await passRes.json();
      setTrip(tripData);
      setPassengers(passData);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [tripId]);

  const getPassengerAtSeat = (seatId) => {
    return passengers.find(p => {
      if (!p.seat) return false;
      // Normalize zero-padded seat IDs (e.g. A01 -> A1, B05 -> B5) so DB matches frontend grid
      const normalizedPSeat = p.seat.replace(/([A-Za-z])0+(\d+)/, '$1$2');
      const normalizedSeatId = seatId.replace(/([A-Za-z])0+(\d+)/, '$1$2');
      return normalizedPSeat === normalizedSeatId;
    });
  };

  const handleSeatClick = (seatId) => {
    const p = getPassengerAtSeat(seatId);
    if (trip && trip.status === 'Completed' && !p) {
        alert('Chuyến xe này đã hoàn thành, không thể đặt thêm vé!');
        return;
    }
    setSelectedSeat(seatId);
    if (p) {
      setEditingBooking(p);
      setBookingForm({
        name: p.name,
        phone: p.phone,
        pickup: p.pickup || '',
        dropoff: p.dropoff || '',
        price: p.price || '100000'
      });
    } else {
      setEditingBooking(null);
      setBookingForm({ name: '', phone: '', pickup: '', dropoff: '', price: '100000' });
    }
    setShowBookingModal(true);
  };

  const handleBooking = async (e) => {
    e.preventDefault();
    setIsBooking(true);
    try {
      const method = editingBooking ? 'PUT' : 'POST';
      const url = editingBooking ? `/api/admin/bookings/${editingBooking.id}` : '/api/book';
      
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(editingBooking ? bookingForm : {
          trip_id: tripId,
          seats: [selectedSeat],
          ...bookingForm
        })
      });
      const data = await res.json();
      if (data.success || res.ok) {
        setShowBookingModal(false);
        fetchData(); 
      } else {
        alert(data.message || 'Lỗi xử lý vé');
      }
    } catch (err) {
      alert('Lỗi kết nối máy chủ');
    } finally {
      setIsBooking(false);
    }
  };

  const handleDeleteBooking = async () => {
    if (!editingBooking || !window.confirm('Bạn có chắc muốn xóa vé này?')) return;
    setIsBooking(true);
    try {
      const res = await fetch(`/api/admin/bookings/${editingBooking.id}`, { method: 'DELETE' });
      if (res.ok) {
        setShowBookingModal(false);
        fetchData();
      } else {
        alert('Lỗi khi xóa vé');
      }
    } catch (err) {
      alert('Lỗi kết nối');
    } finally {
      setIsBooking(false);
    }
  };

  const handlePrintManifest = () => {
    window.open(`/api/admin/trip/${tripId}/export/manifest`, '_blank');
  };

  const handlePrintOrder = () => {
    window.open(`/api/admin/trip/${tripId}/export/order`, '_blank');
  };

  if (isLoading) return <div className="p-20 text-center text-slate-400 font-bold italic animate-pulse tracking-widest uppercase text-xs">Đang tải dữ liệu phơi khách...</div>;
  if (!trip) return <div className="p-20 text-center text-red-500 font-bold">Không tìm thấy chuyến xe.</div>;

  const [routeStart, routeEnd] = trip.route ? trip.route.split(' - ') : ['Bến đi', 'Bến đến'];

  return (
    <div className="min-h-screen bg-[#f1f3f6] p-4 font-sans text-slate-700">
      <div className="max-w-[1600px] mx-auto">
        {/* Compact Header */}
        <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-4 mb-4 flex justify-between items-center">
          <div className="flex items-center gap-4">
            <button onClick={() => navigate(-1)} className="p-2 hover:bg-slate-100 rounded-lg transition-all text-slate-400">
              <ArrowLeft size={20} />
            </button>
            <div>
               <h1 className="text-xl font-black text-slate-800 tracking-tight flex items-center gap-2 uppercase">
                  <Users className="text-orange-500" size={20} /> Phơi hành khách
               </h1>
               <div className="flex items-center gap-3 mt-0.5">
                  <span className="text-[10px] font-black text-blue-600 bg-blue-50 px-2 py-0.5 rounded border border-blue-100 uppercase">{trip.route}</span>
                  <span className="text-[10px] font-black text-slate-400 bg-slate-50 px-2 py-0.5 rounded border border-slate-200 uppercase">{new Date(trip.departure_time).toLocaleString('vi-VN')}</span>
                  <span className="text-[10px] font-black text-orange-600 bg-orange-50 px-2 py-0.5 rounded border border-orange-100 uppercase">Xe: {trip.bus}</span>
               </div>
            </div>
          </div>
          <div className="flex gap-2">
             <button onClick={handlePrintManifest} className="px-4 py-2 bg-white border border-slate-200 rounded-lg font-black text-slate-600 hover:bg-slate-50 transition-all flex items-center gap-2 shadow-sm uppercase text-[10px] tracking-widest">
               <Printer size={14} /> In Phơi (.docx)
             </button>
             <button onClick={handlePrintOrder} className="px-4 py-2 bg-[#EF5222] text-white rounded-lg font-black hover:bg-[#D43D11] transition-all flex items-center gap-2 shadow-md uppercase text-[10px] tracking-widest">
               <FileText size={14} /> Lệnh vận chuyển
             </button>
          </div>
        </div>

        {/* Manifest Main Layout */}
        <div className="bg-white rounded-xl shadow-md border border-slate-200 overflow-hidden">
           <div className="bg-slate-50 border-b border-slate-200 p-3 flex justify-center gap-2">
              <button onClick={() => setDeck('lower')} className={`px-6 py-2 rounded-lg font-black uppercase text-[10px] tracking-widest transition-all ${deck === 'lower' ? 'bg-slate-800 text-white shadow-md' : 'bg-white text-slate-400 border border-slate-200 hover:bg-slate-50'}`}>Tầng dưới (A)</button>
              <button onClick={() => setDeck('upper')} className={`px-6 py-2 rounded-lg font-black uppercase text-[10px] tracking-widest transition-all ${deck === 'upper' ? 'bg-slate-800 text-white shadow-md' : 'bg-white text-slate-400 border border-slate-200 hover:bg-slate-50'}`}>Tầng trên (B)</button>
           </div>

           <div className="p-6 bg-[#f8fafc]">
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-3">
                 {Array.from({ length: 22 }).map((_, i) => {
                   const id = `${deck === 'lower' ? 'A' : 'B'}${i + 1}`;
                   const p = getPassengerAtSeat(id);
                   return (
                     <div 
                       key={id} 
                       onClick={() => handleSeatClick(id)}
                       className={`relative min-h-[140px] bg-white border rounded-lg overflow-hidden transition-all group cursor-pointer ${p ? 'border-blue-200 shadow-sm ring-1 ring-blue-50' : 'border-slate-200 border-dashed hover:border-blue-300'}`}
                     >
                        <div className="p-2 border-b border-slate-50 flex justify-between items-start bg-slate-50/50">
                           <span className={`text-xs font-black uppercase ${p ? 'text-orange-500' : 'text-slate-400'}`}>{id}</span>
                           {p ? (
                              <div className="bg-white border border-slate-800 rounded px-1.5 py-0.5 text-[9px] font-black text-slate-800 shadow-sm">
                                 {p.phone}
                              </div>
                           ) : (
                              trip?.status !== 'Completed' && (
                                 <div className="w-5 h-5 bg-white border border-blue-500 text-blue-500 rounded flex items-center justify-center group-hover:bg-blue-500 group-hover:text-white transition-all shadow-sm">
                                    <Plus size={12} strokeWidth={3} />
                                 </div>
                              )
                           )}
                        </div>

                        <div className="p-2.5 space-y-1.5">
                           {p ? (
                               <>
                                  <div className="text-[11px] font-bold text-slate-500">Tên : <span className="text-slate-800 font-black uppercase">{p.name}</span></div>
                                  <div className="text-[11px] font-bold text-slate-500">Giá : <span className="text-red-500 font-black">{(p.price || 100000).toLocaleString()} VNĐ</span></div>
                                  <div className="text-[9px] font-bold text-slate-400 leading-tight italic">
                                     {p.pickup ? `Đón: ${p.pickup}` : 'Đón tại bến'} {p.dropoff ? `| Trả: ${p.dropoff}` : ''}
                                  </div>
                                  <div className={`text-[10px] font-black uppercase tracking-tighter ${
                                    p.payment_status === 'Paid' ? 'text-green-600' : 'text-orange-500'
                                  }`}>{p.payment_status === 'Paid' ? '✓ ĐÃ THANH TOÁN' : '⏳ CHỜ THANH TOÁN'}</div>
                                 
                                 <div className="pt-2 mt-2 border-t border-slate-50 space-y-1">
                                    <div className="flex items-center gap-1.5 text-[9px] font-bold text-slate-600" title={`Điểm đón: ${p.pickup || getDefaultStation(routeStart, false)}`}>
                                       <MapPin size={10} className="text-slate-400" /> 
                                       <span className="truncate">{p.pickup || getDefaultStation(routeStart, false)}</span>
                                    </div>
                                    <div className="flex items-center gap-1.5 text-[9px] font-bold text-slate-600" title={`Điểm trả: ${p.dropoff || getDefaultStation(routeEnd, true)}`}>
                                       <MapPinIcon size={10} className="text-slate-400" /> 
                                       <span className="truncate">{p.dropoff || getDefaultStation(routeEnd, true)}</span>
                                    </div>
                                    <div className="text-[9px] font-black text-slate-800 text-right mt-1">{p.ticket_code || '---'}</div>
                                 </div>
                              </>
                           ) : (
                              <div className="h-full flex items-center justify-center py-6">
                                 <span className="text-[10px] font-black text-slate-200 uppercase tracking-widest italic opacity-50">TRỐNG</span>
                              </div>
                           )}
                        </div>
                        
                        {p && <div className="absolute bottom-0 left-0 right-0 h-1 bg-blue-500" />}
                     </div>
                   );
                 })}
              </div>
           </div>

           <div className="bg-white border-t border-slate-200 p-8 grid grid-cols-3 gap-8">
              <div className="text-center">
                 <div className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-12 italic">Lệnh trưởng / Chủ xe</div>
                 <div className="w-40 mx-auto border-b border-dashed border-slate-300"></div>
              </div>
              <div className="text-center border-x border-slate-100">
                 <div className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-12 italic">Điều hành bến (Ký đóng dấu)</div>
                 <div className="w-40 mx-auto border-b border-dashed border-slate-300"></div>
              </div>
              <div className="text-center">
                 <div className="text-[9px] font-black text-slate-400 uppercase tracking-widest mb-12 italic">Tài xế nhận lệnh</div>
                 <div className="w-40 mx-auto border-b border-dashed border-slate-300"></div>
              </div>
           </div>
        </div>

        {/* Booking Modal */}
        <AnimatePresence>
          {showBookingModal && (
            <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
              <motion.div 
                initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                className="absolute inset-0 bg-slate-900/40 backdrop-blur-[2px]"
                onClick={() => setShowBookingModal(false)}
              />
              <motion.div 
                initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.95, opacity: 0 }}
                className="bg-white w-full max-w-md rounded-2xl shadow-2xl z-10 overflow-hidden relative"
              >
                <div className={`px-6 py-4 flex justify-between items-center border-b border-slate-200 ${editingBooking ? 'bg-blue-50' : 'bg-slate-50'}`}>
                   <h2 className="text-lg font-black text-slate-800 uppercase tracking-tight">
                      {editingBooking ? `Chỉnh sửa thông tin - Ghế ${selectedSeat}` : `Đặt vé nhanh - Ghế ${selectedSeat}`}
                   </h2>
                   <button onClick={() => setShowBookingModal(false)} className="text-slate-400 hover:text-slate-600">
                      <XCircle size={24} />
                   </button>
                </div>
                
                <form onSubmit={handleBooking} className="p-6 space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                     <div>
                        <label className="block text-[9px] font-black text-slate-400 uppercase mb-1.5 ml-1">Số điện thoại</label>
                        <input 
                           type="tel" required
                           className="w-full bg-white border border-slate-200 rounded-lg p-3 text-sm font-bold focus:border-blue-400 outline-none transition-all shadow-sm"
                           placeholder="09xx..."
                           value={bookingForm.phone}
                           onChange={(e) => setBookingForm({...bookingForm, phone: e.target.value})}
                        />
                     </div>
                     <div>
                        <label className="block text-[9px] font-black text-slate-400 uppercase mb-1.5 ml-1">Giá vé (VNĐ)</label>
                        <input 
                           type="number" required
                           className="w-full bg-white border border-slate-200 rounded-lg p-3 text-sm font-black text-red-500 focus:border-blue-400 outline-none transition-all shadow-sm"
                           value={bookingForm.price}
                           onChange={(e) => setBookingForm({...bookingForm, price: e.target.value})}
                        />
                     </div>
                  </div>
                  <div>
                    <label className="block text-[9px] font-black text-slate-400 uppercase mb-1.5 ml-1">Họ tên khách</label>
                    <input 
                      type="text" required
                      className="w-full bg-white border border-slate-200 rounded-lg p-3 text-sm font-bold focus:border-blue-400 outline-none transition-all shadow-sm"
                      placeholder="NGUYỄN VĂN A"
                      value={bookingForm.name}
                      onChange={(e) => setBookingForm({...bookingForm, name: e.target.value})}
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                     <div>
                       <label className="block text-[9px] font-black text-slate-400 uppercase mb-1.5 ml-1">Điểm đón (Pickup)</label>
                       <input 
                         type="text"
                         className="w-full bg-white border border-slate-200 rounded-lg p-3 text-sm font-bold focus:border-blue-400 outline-none transition-all shadow-sm"
                         placeholder={getDefaultStation(routeStart, false)}
                         value={bookingForm.pickup}
                         onChange={(e) => setBookingForm({...bookingForm, pickup: e.target.value})}
                       />
                     </div>
                     <div>
                       <label className="block text-[9px] font-black text-slate-400 uppercase mb-1.5 ml-1">Điểm trả (Dropoff)</label>
                       <input 
                         type="text"
                         className="w-full bg-white border border-slate-200 rounded-lg p-3 text-sm font-bold focus:border-blue-400 outline-none transition-all shadow-sm"
                         placeholder={getDefaultStation(routeEnd, true)}
                         value={bookingForm.dropoff}
                         onChange={(e) => setBookingForm({...bookingForm, dropoff: e.target.value})}
                       />
                     </div>
                  </div>
                  <div className="pt-4 flex gap-2">
                    {editingBooking && (
                       <button 
                         type="button" onClick={handleDeleteBooking}
                         className="flex-1 px-4 py-3 rounded-lg font-black text-red-500 hover:bg-red-50 border border-red-100 transition-all flex items-center justify-center gap-2 uppercase text-[10px] tracking-widest"
                       >
                         <Trash2 size={14} /> Hủy vé
                       </button>
                    )}
                    <button 
                      type="submit" disabled={isBooking}
                      className="flex-[2] bg-[#EF5222] text-white px-4 py-3 rounded-lg font-black shadow-lg shadow-orange-100 hover:bg-[#D43D11] transition-all flex items-center justify-center gap-2 uppercase text-[10px] tracking-widest disabled:opacity-50"
                    >
                      {isBooking ? 'Đang xử lý...' : editingBooking ? <><Save size={14} /> Cập nhật</> : 'Xác nhận giữ chỗ'}
                    </button>
                  </div>
                </form>
              </motion.div>
            </div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
};

export default Manifest;
