import React, { useState, useEffect } from 'react';
import { 
  Search, MapPin, Calendar, ArrowRightLeft, 
  ShieldCheck, Headphones, Zap, CreditCard, 
  Sparkles, Bus, ChevronDown, Star, Clock, HeartHandshake 
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import Navbar from '../components/Navbar';

const PopularRoute = ({ from, to, price, image }) => (
  <div className="group cursor-pointer">
    <div className="relative h-40 rounded-2xl overflow-hidden mb-3">
      <img src={image} alt={to} className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110" />
      <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
      <div className="absolute bottom-3 left-3 text-white font-bold">{from} - {to}</div>
    </div>
    <div className="flex justify-between items-center px-1">
      <div className="text-sm font-bold text-[#EF5222]">Từ {price} đ</div>
    </div>
  </div>
);

const CustomSelect = ({ value, onChange, options, label, icon: Icon, placeholder, className, isEnd }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');
  const dropdownRef = React.useRef(null);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const filteredOptions = options.filter(opt => 
    opt.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className={`relative ${className} ${isOpen ? 'z-[60]' : 'z-10'}`} ref={dropdownRef}>
      <div 
        onClick={() => setIsOpen(!isOpen)}
        className={`flex items-center gap-4 px-6 py-4 bg-white border border-slate-200 rounded-2xl cursor-pointer h-full transition-all hover:bg-slate-50 hover:border-orange-200 ${isOpen ? 'ring-2 ring-orange-500/20 border-orange-500' : ''}`}
      >
        <Icon className={`${isEnd ? 'text-red-500' : 'text-blue-500'} shrink-0`} size={24} />
        <div className="flex-1 min-w-0">
          <div className="text-[10px] uppercase font-black text-slate-400 tracking-widest mb-0.5">{label}</div>
          <div className="font-black text-slate-800 truncate pr-4">{value || placeholder}</div>
        </div>
        <ChevronDown size={16} className={`text-slate-300 shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </div>

      <AnimatePresence>
        {isOpen && (
          <motion.div 
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 10 }}
            className="absolute left-0 right-0 top-full mt-2 bg-white rounded-3xl shadow-2xl border border-slate-100 z-50 overflow-hidden"
          >
            <div className="p-4 border-b border-slate-50">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                <input 
                  type="text" 
                  placeholder="Tìm kiếm tỉnh thành..."
                  className="w-full pl-10 pr-4 py-2 bg-slate-50 rounded-xl text-sm font-bold outline-none focus:ring-2 focus:ring-orange-100"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  autoFocus
                />
              </div>
            </div>
            <div className="max-h-60 overflow-y-auto p-2 custom-scrollbar">
              {filteredOptions.length > 0 ? (
                filteredOptions.map(opt => (
                  <div 
                    key={opt}
                    onClick={() => {
                      onChange(opt);
                      setIsOpen(false);
                      setSearch('');
                    }}
                    className={`px-4 py-3 rounded-xl text-sm font-bold cursor-pointer transition-all flex items-center justify-between ${
                      value === opt ? 'bg-orange-50 text-orange-600' : 'hover:bg-slate-50 text-slate-600'
                    }`}
                  >
                    {opt}
                    {value === opt && <Zap size={14} fill="currentColor" />}
                  </div>
                ))
              ) : (
                <div className="py-8 text-center text-slate-400 text-xs font-bold italic">Không tìm thấy địa điểm</div>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

const Home = () => {
  const navigate = useNavigate();
  const [provinces, setProvinces] = useState([]);
  const [popularRoutes, setPopularRoutes] = useState([]);
  const [searchData, setSearchData] = useState({
    start_point: '',
    end_point: '',
    date: new Date().toISOString().split('T')[0]
  });

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [provRes, routesRes] = await Promise.all([
          fetch('/api/provinces'),
          fetch('/api/popular-routes')
        ]);
        const provData = await provRes.json();
        const routesData = await routesRes.json();
        
        const cleanProvinces = [...new Set(provData.map(p => p.trim()))].sort();
        
        setProvinces(cleanProvinces);
        setPopularRoutes(Array.isArray(routesData) ? routesData : []);
      } catch (err) {
        console.error(err);
      }
    };
    fetchData();
  }, []);

  const handleSearch = (e) => {
    e.preventDefault();
    if (!searchData.start_point || !searchData.end_point) {
      alert("Vui lòng chọn đầy đủ điểm đi và điểm đến!");
      return;
    }
    const params = new URLSearchParams(searchData);
    navigate(`/search?${params.toString()}`);
  };

  const swapPoints = () => {
    setSearchData({
      ...searchData,
      start_point: searchData.end_point,
      end_point: searchData.start_point
    });
  };

  return (
    <div className="min-h-screen bg-white">
      <div className="relative min-h-[650px] md:h-[650px] flex flex-col items-center pt-24 md:pt-32 pb-12 md:pb-0 overflow-visible">
        <div className="absolute inset-0 overflow-hidden pointer-events-none rounded-b-[3rem]">
          <div className="absolute inset-0 bg-[url('/hero-banner.png')] bg-cover bg-center transform scale-105 animate-[pulse_20s_ease-in-out_infinite_alternate]"></div>
          <div className="absolute inset-0 bg-gradient-to-b from-black/70 via-black/40 to-black/80"></div>
        </div>
        <div className="relative z-10 w-full max-w-5xl px-6 text-center text-white mb-8 md:mb-10">
          <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="inline-flex items-center gap-2 px-5 py-2 bg-white/10 rounded-full border border-white/20 backdrop-blur-md text-[10px] md:text-xs font-black uppercase tracking-[0.3em] mb-4 md:mb-6 shadow-2xl max-w-full text-center">
            <Sparkles size={14} className="text-yellow-400 shrink-0" />
            <span className="truncate">Hành trình đẳng cấp - Trải nghiệm xứng tầm</span>
          </motion.div>
          <motion.h1 initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="text-4xl md:text-7xl font-black mb-3 md:mb-4 tracking-tighter uppercase italic drop-shadow-2xl">
            HUTECH <span className="text-[#EF5222]">BUS</span>
          </motion.h1>
          <p className="text-base md:text-xl font-medium opacity-90 drop-shadow-md text-slate-100 px-4">Hệ thống vận tải hành khách chất lượng cao hàng đầu Việt Nam</p>
        </div>
        
        <div className="relative z-30 w-full max-w-6xl px-4 md:px-6 overflow-visible">
          <form onSubmit={handleSearch} className="bg-white rounded-[2rem] md:rounded-[3.5rem] shadow-2xl p-2 pb-6 md:pb-8 border border-slate-100 overflow-visible">
            <div className="flex gap-8 px-6 md:px-12 py-4 md:py-6 border-b border-slate-50">
              <button type="button" className="flex items-center gap-3 text-[#EF5222] font-black border-b-2 border-[#EF5222] pb-2 uppercase text-[10px] tracking-[0.2em]"><Bus size={18} /> Đặt vé xe khách</button>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-12 gap-3 md:gap-4 p-3 md:p-4 items-stretch relative z-40 overflow-visible">
              <CustomSelect 
                className="md:col-span-4"
                label="Nơi xuất phát"
                placeholder="Chọn điểm đi"
                icon={MapPin}
                options={provinces}
                value={searchData.start_point}
                onChange={(val) => setSearchData({...searchData, start_point: val})}
              />
              
              <div className="relative md:col-span-3">
                <CustomSelect 
                  label="Nơi đến"
                  placeholder="Chọn điểm đến"
                  icon={MapPin}
                  isEnd={true}
                  options={provinces}
                  value={searchData.end_point}
                  onChange={(val) => setSearchData({...searchData, end_point: val})}
                />
                <button 
                  type="button" 
                  onClick={swapPoints} 
                  className="absolute right-6 -top-1.5 md:-left-4 md:top-1/2 -translate-y-1/2 z-40 w-8 h-8 bg-white border border-slate-200 rounded-full flex items-center justify-center shadow-lg hover:scale-110 transition-transform hover:border-orange-500 hover:text-orange-500 rotate-90 md:rotate-0"
                >
                  <ArrowRightLeft size={16} />
                </button>
              </div>

              <div className="md:col-span-3 relative group h-full">
                <label className="flex items-center gap-4 px-6 py-4 bg-white border border-slate-200 rounded-2xl cursor-pointer h-full transition-all hover:bg-slate-50 hover:border-orange-200">
                  <Calendar className="text-orange-500 shrink-0" size={24} />
                  <div className="flex-1 min-w-0">
                    <div className="text-[10px] uppercase font-black text-slate-400 tracking-widest mb-0.5">Ngày đi</div>
                    <input 
                      type="date" 
                      value={searchData.date} 
                      onChange={(e) => setSearchData({...searchData, date: e.target.value})} 
                      className="absolute inset-0 opacity-0 cursor-pointer z-10" 
                      onClick={(e) => e.currentTarget.showPicker?.()}
                    />
                    <div className="font-black text-slate-800">
                      {searchData.date ? new Date(searchData.date).toLocaleDateString('vi-VN') : 'Chọn ngày'}
                    </div>
                  </div>
                  <ChevronDown size={16} className="text-slate-300 shrink-0" />
                </label>
              </div>

              <div className="md:col-span-2 pl-0 md:pl-2 flex items-center">
                <button type="submit" className="w-full h-full min-h-[56px] md:min-h-[64px] bg-gradient-to-br from-[#EF5222] to-orange-400 hover:from-[#D43D11] hover:to-[#EF5222] text-white font-black rounded-2xl md:rounded-[2rem] shadow-xl shadow-orange-200 uppercase tracking-widest transition-all active:scale-95 text-xs">Tìm kiếm</button>
              </div>
            </div>
          </form>
        </div>

        <div className="w-full max-w-5xl px-6 mt-8 md:mt-12 grid grid-cols-2 md:grid-cols-4 gap-4 text-white font-black text-[10px] uppercase tracking-[2px] opacity-80">
           <div className="flex items-center gap-2 drop-shadow-md"><ShieldCheck size={18} className="text-yellow-400 shrink-0" /> <span className="truncate">Cam kết có chỗ</span></div>
           <div className="flex items-center gap-2 drop-shadow-md"><Headphones size={18} className="text-yellow-400 shrink-0" /> <span className="truncate">Hỗ trợ 24/7</span></div>
           <div className="flex items-center gap-2 drop-shadow-md"><Zap size={18} className="text-yellow-400 shrink-0" /> <span className="truncate">Thanh toán 1s</span></div>
           <div className="flex items-center gap-2 drop-shadow-md"><CreditCard size={18} className="text-yellow-400 shrink-0" /> <span className="truncate">Giá rẻ mỗi ngày</span></div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 py-16 md:py-24">
        <div className="flex flex-col md:flex-row items-start md:items-end justify-between gap-6 mb-12">
          <div>
            <h2 className="text-3xl md:text-4xl font-black text-slate-800 italic uppercase tracking-tighter mb-2">Tuyến đường phổ biến</h2>
            <div className="h-1.5 w-32 bg-[#EF5222] rounded-full shadow-lg shadow-orange-100"></div>
          </div>
          <p className="text-slate-400 font-bold italic max-w-sm text-left md:text-right">Khám phá các hành trình được yêu thích nhất với mức giá và dịch vụ tốt nhất.</p>
        </div>
        
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-8">
          {popularRoutes.length > 0 ? (
            popularRoutes.map(route => (
              <PopularRoute key={route.id} from={route.from} to={route.to} price={route.price} image={route.image} />
            ))
          ) : (
            <div className="col-span-full text-center text-slate-400 font-bold py-20 border-2 border-dashed border-slate-100 rounded-[2rem] md:rounded-[3rem]">
               Đang cập nhật các tuyến đường hấp dẫn...
            </div>
          )}
        </div>
      </div>

      {/* Why Choose Us Section */}
      <div className="bg-slate-50 py-16 md:py-24">
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center mb-12 md:mb-16">
            <h2 className="text-3xl md:text-4xl font-black text-slate-800 italic uppercase tracking-tighter mb-4">Tại sao chọn Hutech Bus?</h2>
            <p className="text-slate-500 font-bold max-w-2xl mx-auto">Chúng tôi không chỉ cung cấp một chuyến đi, chúng tôi mang đến những trải nghiệm di chuyển tuyệt vời nhất với tiêu chuẩn dịch vụ 5 sao.</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-white p-8 rounded-[2rem] border border-slate-100 hover:shadow-xl hover:-translate-y-2 transition-all duration-300">
              <div className="w-16 h-16 bg-orange-50 text-[#EF5222] rounded-2xl flex items-center justify-center mb-6">
                <Star size={32} />
              </div>
              <h3 className="text-xl font-black text-slate-800 mb-3">Chất lượng 5 Sao</h3>
              <p className="text-slate-500 font-medium leading-relaxed">Dòng xe giường nằm đời mới nhất, trang bị đầy đủ tiện nghi: wifi tốc độ cao, cổng sạc USB, màn hình giải trí riêng biệt.</p>
            </div>
            
            <div className="bg-white p-8 rounded-[2rem] border border-slate-100 hover:shadow-xl hover:-translate-y-2 transition-all duration-300">
              <div className="w-16 h-16 bg-blue-50 text-blue-500 rounded-2xl flex items-center justify-center mb-6">
                <Clock size={32} />
              </div>
              <h3 className="text-xl font-black text-slate-800 mb-3">Đúng giờ, Đúng tuyến</h3>
              <p className="text-slate-500 font-medium leading-relaxed">Cam kết khởi hành đúng giờ, không bắt khách dọc đường. Đảm bảo lịch trình của bạn luôn diễn ra suôn sẻ và chính xác nhất.</p>
            </div>
            
            <div className="bg-white p-8 rounded-[2rem] border border-slate-100 hover:shadow-xl hover:-translate-y-2 transition-all duration-300">
              <div className="w-16 h-16 bg-green-50 text-green-500 rounded-2xl flex items-center justify-center mb-6">
                <HeartHandshake size={32} />
              </div>
              <h3 className="text-xl font-black text-slate-800 mb-3">Phục vụ tận tâm</h3>
              <p className="text-slate-500 font-medium leading-relaxed">Đội ngũ lái xe và tiếp viên được đào tạo chuyên nghiệp, luôn sẵn sàng hỗ trợ hành khách với thái độ ân cần và chu đáo nhất.</p>
            </div>
          </div>
        </div>
      </div>

      {/* App Download Promo */}
      <div className="max-w-7xl mx-auto px-6 py-16 md:py-24">
        <div className="bg-gradient-to-br from-[#1e293b] to-[#0f172a] rounded-[2rem] md:rounded-[3rem] p-8 md:p-16 flex flex-col md:flex-row items-center justify-between relative overflow-hidden shadow-2xl">
          <div className="absolute top-0 right-0 w-96 h-96 bg-[#EF5222] rounded-full blur-[120px] opacity-20 pointer-events-none"></div>
          <div className="absolute bottom-0 left-0 w-96 h-96 bg-blue-500 rounded-full blur-[120px] opacity-20 pointer-events-none"></div>
          
          <div className="relative z-10 md:w-1/2 mb-10 md:mb-0">
            <h2 className="text-3xl md:text-5xl font-black text-white italic uppercase tracking-tighter mb-6">
              Đặt vé siêu tốc <br/>
              <span className="text-[#EF5222]">Nhận ngàn siêu hời</span>
            </h2>
            <p className="text-slate-300 font-medium text-lg mb-8 leading-relaxed">Tải ngay ứng dụng Hutech Bus để nhận ngay mã giảm giá 50.000đ cho chuyến đi đầu tiên. Quản lý vé dễ dàng, tích điểm đổi quà và nhiều đặc quyền khác.</p>
            <div className="flex flex-wrap gap-4">
              <button className="bg-white text-slate-900 px-8 py-4 rounded-xl font-black uppercase tracking-widest hover:bg-slate-100 transition-colors shadow-lg">App Store</button>
              <button className="bg-white text-slate-900 px-8 py-4 rounded-xl font-black uppercase tracking-widest hover:bg-slate-100 transition-colors shadow-lg">Google Play</button>
            </div>
          </div>
          
          <div className="relative z-10 md:w-5/12 flex justify-center hidden md:flex">
             <div className="w-[280px] h-[560px] bg-white rounded-[3rem] p-4 shadow-2xl transform rotate-6 hover:rotate-0 transition-transform duration-500 border-8 border-slate-800 relative">
               <div className="w-full h-full bg-slate-50 rounded-[2.2rem] overflow-hidden flex flex-col relative">
                  <div className="h-20 bg-gradient-to-r from-[#EF5222] to-orange-400 flex flex-col items-center justify-center text-white font-black italic relative overflow-hidden">
                    <span className="relative z-10">HUTECH BUS</span>
                  </div>
                  <div className="flex-1 p-5 space-y-4 overflow-hidden bg-slate-50">
                    {/* Mockup UI Elements */}
                    <div className="h-10 bg-white rounded-xl shadow-sm border border-slate-100 flex items-center px-4">
                      <div className="w-4 h-4 rounded-full bg-slate-200"></div>
                      <div className="ml-3 h-2 w-20 bg-slate-200 rounded-full"></div>
                    </div>
                    <div className="h-32 bg-white rounded-2xl shadow-sm border border-slate-100 relative overflow-hidden">
                      <div className="absolute top-0 left-0 w-full h-12 bg-orange-50"></div>
                      <div className="absolute top-4 left-4 h-3 w-24 bg-[#EF5222] rounded-full opacity-50"></div>
                      <div className="absolute top-16 left-4 h-2 w-32 bg-slate-200 rounded-full"></div>
                      <div className="absolute top-22 left-4 h-2 w-20 bg-slate-200 rounded-full"></div>
                    </div>
                    <div className="h-24 bg-white rounded-2xl shadow-sm border border-slate-100 flex items-center justify-center">
                      <div className="flex gap-2">
                        <div className="w-8 h-8 rounded-full bg-slate-100"></div>
                        <div className="w-8 h-8 rounded-full bg-slate-100"></div>
                        <div className="w-8 h-8 rounded-full bg-slate-100"></div>
                      </div>
                    </div>
                  </div>
               </div>
               {/* iPhone Notch */}
               <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-6 bg-slate-800 rounded-b-2xl"></div>
             </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Home;
