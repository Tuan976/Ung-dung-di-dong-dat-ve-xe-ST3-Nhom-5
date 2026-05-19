import React, { useState, useEffect } from 'react';
import { Bus, MapPin, Users, CheckCircle, Navigation, Phone, MessageSquare, AlertTriangle, ChevronRight, LogOut, Package } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const PassengerCard = ({ passenger, onCheckIn }) => (
  <div className="bg-white p-5 rounded-3xl border border-slate-100 shadow-sm flex items-center justify-between group">
    <div className="flex items-center gap-4">
      <div className={`w-14 h-14 rounded-2xl flex items-center justify-center font-black text-xl transition-all ${
        passenger.boarding_status === 'BOARDED' ? 'bg-green-500 text-white shadow-lg shadow-green-100' : 'bg-slate-100 text-slate-400'
      }`}>
        {passenger.seat}
      </div>
      <div>
        <div className="font-bold text-slate-800 text-lg leading-tight">{passenger.name}</div>
        <div className="flex items-center gap-4 mt-1">
           <div className="text-sm font-bold text-slate-400 flex items-center gap-1"><Phone size={14} /> {passenger.phone}</div>
           <div className="text-sm font-bold text-slate-400 flex items-center gap-1 italic"><MapPin size={14} /> {passenger.pickup}</div>
        </div>
      </div>
    </div>
    
    <button 
      onClick={() => onCheckIn(passenger.id)}
      className={`px-6 py-3 rounded-2xl font-black text-xs uppercase tracking-widest transition-all ${
        passenger.boarding_status === 'BOARDED' ? 'bg-green-50 text-green-600' : 'bg-[#EF5222] text-white shadow-lg shadow-orange-100'
      }`}
    >
      {passenger.boarding_status === 'BOARDED' ? 'Đã lên xe' : 'Check-in'}
    </button>
  </div>
);

const DriverTrips = () => {
  const [assignedTrips, setAssignedTrips] = useState([]);
  const [activeTrip, setActiveTrip] = useState(null);
  const [passengers, setPassengers] = useState([]);

  useEffect(() => {
    // Mock fetching assigned trips for driver
    setAssignedTrips([
      { id: 19, route: 'Hồ Chí Minh - Cư Jut', time: '13:28:00 20/5/2026', bus: '51B17000', status: 'Active' }
    ]);
  }, []);

  const startTrip = (trip) => {
    setActiveTrip(trip);
    // Fetch passengers for this trip
    fetch(`/api/admin/trip/${trip.id}/passengers`)
      .then(res => res.json())
      .then(data => setPassengers(data));
  };

  const handleCheckIn = (id) => {
    setPassengers(prev => prev.map(p => 
      p.id === id ? { ...p, boarding_status: 'BOARDED' } : p
    ));
    // In real app, would call API to sync with Admin
  };

  if (!activeTrip) {
    return (
      <div className="min-h-screen bg-slate-50 p-6 flex flex-col pt-20">
        <div className="mb-8">
           <h1 className="text-3xl font-black text-slate-800 uppercase italic tracking-tighter">HUTECH DRIVER</h1>
           <p className="text-slate-500 font-bold">Chào buổi sáng, Tài xế Nguyễn Văn A!</p>
        </div>

        <div className="space-y-4">
           <div className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Chuyến xe hôm nay</div>
           {assignedTrips.map(trip => (
             <motion.div 
               whileTap={{ scale: 0.98 }}
               key={trip.id} 
               onClick={() => startTrip(trip)}
               className="bg-white p-6 rounded-3xl shadow-xl border-none flex items-center justify-between group cursor-pointer"
             >
               <div className="flex items-center gap-5">
                 <div className="bg-[#EF5222] p-4 rounded-2xl text-white shadow-lg shadow-orange-100"><Bus size={28} /></div>
                 <div>
                   <div className="text-xl font-black text-slate-800">{trip.route}</div>
                   <div className="text-sm font-bold text-slate-400 mt-1">{trip.time} • Xe: {trip.bus}</div>
                 </div>
               </div>
               <div className="bg-slate-50 p-3 rounded-full text-slate-300 group-hover:bg-[#EF5222] group-hover:text-white transition-all"><ChevronRight size={24} /></div>
             </motion.div>
           ))}
        </div>
        
        <button className="mt-auto w-full py-4 bg-slate-200 text-slate-600 font-black rounded-2xl flex items-center justify-center gap-2">
          <LogOut size={20} /> Đăng xuất
        </button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
       {/* Active Trip Header */}
       <div className="bg-slate-900 text-white p-8 pt-12 rounded-b-[40px] shadow-2xl relative z-10">
          <button onClick={() => setActiveTrip(null)} className="absolute top-6 left-6 text-slate-400 hover:text-white font-bold flex items-center gap-1">Quay lại</button>
          
          <div className="flex justify-between items-start mt-4">
            <div>
               <div className="text-[10px] font-black text-orange-400 uppercase tracking-[4px] mb-2">Đang vận hành</div>
               <h2 className="text-2xl font-black tracking-tight">{activeTrip.route}</h2>
               <p className="opacity-60 text-sm font-bold mt-1">Khởi hành: {activeTrip.time} • {activeTrip.bus}</p>
            </div>
            <div className="text-center">
               <div className="text-4xl font-black text-orange-400">{passengers.filter(p => p.boarding_status === 'BOARDED').length}/{passengers.length}</div>
               <div className="text-[10px] font-bold opacity-40 uppercase">Khách lên xe</div>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4 mt-10">
             <button className="flex flex-col items-center gap-2 p-4 bg-slate-800 rounded-2xl hover:bg-slate-700 transition-all">
                <Navigation size={24} className="text-blue-400" />
                <span className="text-[10px] font-black uppercase">Lộ trình</span>
             </button>
             <button className="flex flex-col items-center gap-2 p-4 bg-slate-800 rounded-2xl hover:bg-slate-700 transition-all">
                <Package size={24} className="text-indigo-400" />
                <span className="text-[10px] font-black uppercase">Hàng hóa</span>
             </button>
             <button className="flex flex-col items-center gap-2 p-4 bg-red-500 rounded-2xl hover:bg-red-600 transition-all">
                <AlertTriangle size={24} className="text-white" />
                <span className="text-[10px] font-black uppercase">Sự cố</span>
             </button>
          </div>
       </div>

       <div className="p-6 space-y-4 flex-1 overflow-y-auto pt-8">
          <div className="flex justify-between items-center px-2">
             <h3 className="text-lg font-black text-slate-800">Danh sách khách đón</h3>
             <button className="text-xs font-bold text-blue-600">Xem bản đồ</button>
          </div>

          <div className="space-y-3 pb-10">
            {passengers.map(p => (
              <PassengerCard key={p.id} passenger={p} onCheckIn={handleCheckIn} />
            ))}
          </div>
       </div>
       
       <div className="p-6 pt-0">
          <button className="w-full py-5 bg-green-600 text-white font-black rounded-3xl shadow-2xl shadow-green-100 uppercase tracking-widest text-sm flex items-center justify-center gap-2 hover:bg-green-700 transition-all">
             <CheckCircle size={24} /> Kết thúc chuyến đi
          </button>
       </div>
    </div>
  );
};

export default DriverTrips;
