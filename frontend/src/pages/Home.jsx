import React, { useState, useEffect } from 'react';
import {
  Search,
  MapPin,
  Calendar,
  ArrowRightLeft,
  ShieldCheck,
  Headphones,
  Zap,
  CreditCard,
  Bus,
  ChevronDown,
  Star,
  Clock,
  HeartHandshake,
  ArrowRight,
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const PopularRouteCard = ({ from, to, price, image, onSelect }) => (
  <div
    onClick={onSelect}
    className="group cursor-pointer overflow-hidden rounded-2xl border border-[#E7EAF0] bg-white transition hover:border-[#FF6B00]/50 card-shadow"
  >
    <div className="relative h-40 overflow-hidden bg-[#FFF1E6]">
      {image ? (
        <img
          src={image}
          alt={`${from} - ${to}`}
          className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
        />
      ) : (
        <div className="grid h-full w-full place-items-center text-[#FF6B00]">
          <Bus size={42} />
        </div>
      )}
      <div className="absolute top-3 left-3 rounded-lg bg-[#FF6B00] px-2.5 py-1 text-[11px] font-bold text-white">
        Tuyến phổ biến
      </div>
    </div>
    <div className="p-4">
      <h3 className="text-base font-extrabold text-[#202938] group-hover:text-[#FF6B00] transition-colors">
        {from} → {to}
      </h3>
      <div className="mt-2 flex items-center justify-between">
        <div>
          <span className="text-xs text-[#778196]">Giá vé từ </span>
          <strong className="text-base font-black text-[#FF6B00]">{price} đ</strong>
        </div>
        <span className="inline-flex items-center gap-1 text-xs font-bold text-[#FF6B00]">
          Đặt vé <ArrowRight size={14} />
        </span>
      </div>
    </div>
  </div>
);

const CustomSelect = ({ value, onChange, options, label, icon: Icon, placeholder, className, isEnd }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');
  const dropdownRef = React.useRef(null);

  useEffect(() => {
    const handleClickOutside = event => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const filteredOptions = options.filter(opt => opt.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className={`relative ${className} ${isOpen ? 'z-[60]' : 'z-10'}`} ref={dropdownRef}>
      <div
        onClick={() => setIsOpen(!isOpen)}
        className={`flex items-center gap-3.5 px-4 py-3.5 bg-[#F7F8FA] border rounded-xl cursor-pointer h-full transition-all hover:border-[#FF6B00]/50 ${
          isOpen ? 'ring-2 ring-[#FF6B00]/15 border-[#FF6B00] bg-white' : 'border-[#E7EAF0]'
        }`}
      >
        <div
          className={`grid size-9 shrink-0 place-items-center rounded-lg ${
            isEnd ? 'bg-[#E9F8F0] text-[#16A36A]' : 'bg-[#FFF1E6] text-[#FF6B00]'
          }`}
        >
          <Icon size={18} />
        </div>
        <div className="flex-1 min-w-0 text-left">
          <div className="text-[11px] font-semibold text-[#778196]">{label}</div>
          <div className="font-bold text-sm text-[#202938] truncate">{value || placeholder}</div>
        </div>
        <ChevronDown
          size={16}
          className={`text-[#778196] shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`}
        />
      </div>

      {isOpen && (
        <div className="absolute left-0 right-0 top-full mt-2 rounded-2xl border border-[#E7EAF0] bg-white shadow-xl z-50 overflow-hidden">
          <div className="p-3 border-b border-[#E7EAF0]">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#778196]" size={15} />
              <input
                type="text"
                placeholder="Tìm tỉnh / thành phố..."
                className="w-full pl-9 pr-3 py-2 bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl text-sm font-medium text-[#202938] outline-none focus:border-[#FF6B00]"
                value={search}
                onChange={e => setSearch(e.target.value)}
                autoFocus
              />
            </div>
          </div>
          <div className="max-h-60 overflow-y-auto p-1.5">
            {filteredOptions.length > 0 ? (
              filteredOptions.map(opt => (
                <div
                  key={opt}
                  onClick={() => {
                    onChange(opt);
                    setIsOpen(false);
                    setSearch('');
                  }}
                  className={`px-3.5 py-2.5 rounded-xl text-sm font-semibold cursor-pointer transition-all flex items-center justify-between ${
                    value === opt
                      ? 'bg-[#FFF1E6] text-[#FF6B00]'
                      : 'hover:bg-[#F7F8FA] text-[#202938]'
                  }`}
                >
                  {opt}
                  {value === opt && <span className="text-xs font-bold">Đã chọn</span>}
                </div>
              ))
            ) : (
              <div className="py-6 text-center text-[#778196] text-xs font-medium">
                Không tìm thấy địa điểm phù hợp
              </div>
            )}
          </div>
        </div>
      )}
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
    date: new Date().toISOString().split('T')[0],
  });

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [provRes, routesRes] = await Promise.all([
          fetch('/api/provinces'),
          fetch('/api/popular-routes'),
        ]);
        const provData = await provRes.json();
        const routesData = await routesRes.json();

        const cleanProvinces = [...new Set((Array.isArray(provData) ? provData : []).map(p => p.trim()))].sort();

        setProvinces(cleanProvinces);
        setPopularRoutes(Array.isArray(routesData) ? routesData : []);
      } catch (err) {
        console.error(err);
      }
    };
    fetchData();
  }, []);

  const handleSearch = e => {
    e.preventDefault();
    if (!searchData.start_point || !searchData.end_point) {
      alert('Vui lòng chọn đầy đủ điểm đi và điểm đến!');
      return;
    }
    const params = new URLSearchParams(searchData);
    navigate(`/search?${params.toString()}`);
  };

  const swapPoints = () => {
    setSearchData({
      ...searchData,
      start_point: searchData.end_point,
      end_point: searchData.start_point,
    });
  };

  return (
    <div className="min-h-screen bg-[#F7F8FA]">
      {/* Hero & Search Banner */}
      <section className="border-b border-[#E7EAF0] bg-white pt-10 pb-14">
        <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-3xl text-center mb-8">
            <span className="inline-flex items-center gap-1.5 rounded-full border border-[#FF6B00]/25 bg-[#FFF1E6] px-3.5 py-1 text-xs font-bold text-[#FF6B00] mb-4">
              <Bus size={14} /> Nền tảng đặt vé xe khách thông minh
            </span>
            <h1 className="text-3xl sm:text-5xl font-black tracking-tight text-[#202938] mb-3">
              Đặt vé xe nhanh chóng cùng <span className="text-[#FF6B00]">TRIPLY</span>
            </h1>
            <p className="text-sm sm:text-base text-[#778196] font-medium">
              So sánh lịch trình, chọn đúng vị trí ghế yêu thích và nhận vé điện tử QR chỉ trong 30 giây.
            </p>
          </div>

          {/* Search Box */}
          <form
            onSubmit={handleSearch}
            className="rounded-2xl border border-[#E7EAF0] bg-white p-4 sm:p-6 shadow-lg shadow-[#202938]/5"
          >
            <div className="grid grid-cols-1 md:grid-cols-12 gap-3 items-stretch">
              <CustomSelect
                className="md:col-span-4"
                label="Điểm khởi hành"
                placeholder="Chọn nơi xuất phát"
                icon={MapPin}
                options={provinces}
                value={searchData.start_point}
                onChange={val => setSearchData({ ...searchData, start_point: val })}
              />

              <div className="relative md:col-span-4">
                <CustomSelect
                  label="Điểm đến"
                  placeholder="Chọn nơi đến"
                  icon={MapPin}
                  isEnd={true}
                  options={provinces}
                  value={searchData.end_point}
                  onChange={val => setSearchData({ ...searchData, end_point: val })}
                />
                <button
                  type="button"
                  onClick={swapPoints}
                  title="Đổi chiều hành trình"
                  className="absolute right-4 -top-3 md:-left-4 md:top-1/2 md:-translate-y-1/2 z-30 grid size-8 place-items-center rounded-full border border-[#FF6B00]/30 bg-white text-[#FF6B00] shadow-md hover:bg-[#FFF1E6] transition"
                >
                  <ArrowRightLeft size={15} />
                </button>
              </div>

              <div className="md:col-span-2">
                <label className="relative flex items-center gap-3 px-4 py-3.5 bg-[#F7F8FA] border border-[#E7EAF0] rounded-xl cursor-pointer h-full hover:border-[#FF6B00]/50">
                  <Calendar className="text-[#FF6B00] shrink-0" size={18} />
                  <div className="flex-1 min-w-0">
                    <div className="text-[11px] font-semibold text-[#778196]">Ngày khởi hành</div>
                    <input
                      type="date"
                      value={searchData.date}
                      onChange={e => setSearchData({ ...searchData, date: e.target.value })}
                      className="absolute inset-0 opacity-0 cursor-pointer z-10"
                      onClick={e => e.currentTarget.showPicker?.()}
                    />
                    <div className="font-bold text-sm text-[#202938]">
                      {searchData.date
                        ? new Date(searchData.date).toLocaleDateString('vi-VN')
                        : 'Chọn ngày'}
                    </div>
                  </div>
                </label>
              </div>

              <div className="md:col-span-2 flex">
                <button
                  type="submit"
                  className="w-full min-h-[54px] rounded-xl bg-[#FF6B00] hover:bg-[#E85F00] text-white font-bold text-sm transition shadow-sm flex items-center justify-center gap-2 cursor-pointer"
                >
                  <Search size={17} />
                  Tìm chuyến
                </button>
              </div>
            </div>

            {/* Trust badges */}
            <div className="mt-5 pt-4 border-t border-[#E7EAF0] grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs font-semibold text-[#778196]">
              <div className="flex items-center gap-2">
                <ShieldCheck size={16} className="text-[#FF6B00] shrink-0" />
                <span>Cam kết 100% giữ ghế</span>
              </div>
              <div className="flex items-center gap-2">
                <Zap size={16} className="text-[#FF6B00] shrink-0" />
                <span>Xuất vé điện tử tức thì</span>
              </div>
              <div className="flex items-center gap-2">
                <CreditCard size={16} className="text-[#FF6B00] shrink-0" />
                <span>Giá niêm yết minh bạch</span>
              </div>
              <div className="flex items-center gap-2">
                <Headphones size={16} className="text-[#FF6B00] shrink-0" />
                <span>Trợ lý Triply hỗ trợ 24/7</span>
              </div>
            </div>
          </form>
        </div>
      </section>

      {/* Popular Routes Section */}
      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-8">
          <div>
            <h2 className="text-2xl font-black text-[#202938]">Tuyến đường phổ biến</h2>
            <p className="text-sm text-[#778196] mt-1">
              Lựa chọn những lộ trình liên tỉnh có tần suất chuyến dày và giá tốt nhất hôm nay
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          {popularRoutes.length > 0 ? (
            popularRoutes.map(route => (
              <PopularRouteCard
                key={route.id || `${route.from}-${route.to}`}
                from={route.from}
                to={route.to}
                price={route.price}
                image={route.image}
                onSelect={() => {
                  const params = new URLSearchParams({
                    start_point: route.from,
                    end_point: route.to,
                    date: searchData.date,
                  });
                  navigate(`/search?${params.toString()}`);
                }}
              />
            ))
          ) : (
            <div className="col-span-full rounded-2xl border border-[#E7EAF0] bg-white py-14 text-center text-sm font-semibold text-[#778196]">
              Đang tải danh sách các tuyến đường phổ biến...
            </div>
          )}
        </div>
      </section>

      {/* Value Proposition Section */}
      <section className="border-t border-[#E7EAF0] bg-white py-14">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-2xl mx-auto mb-10">
            <h2 className="text-2xl font-black text-[#202938]">Vì sao khách hàng tin chọn Triply?</h2>
            <p className="text-sm text-[#778196] mt-2">
              Thiết kế hướng tới sự thuận tiện, minh bạch và an tâm trên mọi hành trình
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="rounded-2xl border border-[#E7EAF0] bg-[#F7F8FA] p-6">
              <div className="grid size-12 place-items-center rounded-xl bg-[#FFF1E6] text-[#FF6B00] mb-4">
                <Star size={24} />
              </div>
              <h3 className="text-base font-extrabold text-[#202938] mb-2">
                Sơ đồ ghế trực quan & minh bạch
              </h3>
              <p className="text-sm text-[#778196] leading-relaxed">
                Xem chính xác sơ đồ ghế từng tầng, tình trạng ghế trống theo thời gian thực và giá vé niêm yết rõ ràng.
              </p>
            </div>

            <div className="rounded-2xl border border-[#E7EAF0] bg-[#F7F8FA] p-6">
              <div className="grid size-12 place-items-center rounded-xl bg-[#FFF1E6] text-[#FF6B00] mb-4">
                <Clock size={24} />
              </div>
              <h3 className="text-base font-extrabold text-[#202938] mb-2">
                Đặt vé siêu tốc qua Trợ lý Triply
              </h3>
              <p className="text-sm text-[#778196] leading-relaxed">
                Chỉ cần nhắn điểm đi, điểm đến và số lượng vé — Trợ lý Triply sẽ gợi ý chuyến và giữ ghế cho bạn ngay trong khung chat.
              </p>
            </div>

            <div className="rounded-2xl border border-[#E7EAF0] bg-[#F7F8FA] p-6">
              <div className="grid size-12 place-items-center rounded-xl bg-[#FFF1E6] text-[#FF6B00] mb-4">
                <HeartHandshake size={24} />
              </div>
              <h3 className="text-base font-extrabold text-[#202938] mb-2">
                Đồng hành & hỗ trợ 24/7
              </h3>
              <p className="text-sm text-[#778196] leading-relaxed">
                Tra cứu mã vé điện tử dễ dàng, theo dõi lộ trình xe trực tiếp trên bản đồ và hỗ trợ đổi/hủy vé linh hoạt.
              </p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default Home;
