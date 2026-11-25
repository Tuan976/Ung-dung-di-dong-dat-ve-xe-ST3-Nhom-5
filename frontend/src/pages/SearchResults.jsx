import React, { useState, useEffect, useMemo, Component } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { Bus, Calendar, MapPin, CheckCircle2, ArrowRight, Filter, X } from 'lucide-react';
import Navbar from '../components/Navbar';

class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(e) {
    return { hasError: true, error: e };
  }
  render() {
    if (this.state.hasError) {
      return (
        <div className="p-10 text-center">
          <h2 className="text-lg font-bold text-[#DC4545]">Không thể hiển thị trang</h2>
          <pre className="mt-4 rounded-xl bg-[#FDECEC] p-4 text-xs text-[#DC4545] text-left overflow-auto">
            {String(this.state.error)}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}

// ---- Booking Modal ----
const BookingModal = ({ tripId, onClose }) => {
  const [trip, setTrip] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState([]);
  const [form, setForm] = useState({
    name: '',
    phone: '',
    pickup: '',
    dropoff: '',
    payment_method: 'cash',
  });
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [ticketCodes, setTicketCodes] = useState([]);

  useEffect(() => {
    if (!tripId) return;
    fetch(`/api/trip/${tripId}`)
      .then(r => r.json())
      .then(data => {
        setTrip(data);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [tripId]);

  const toggle = id =>
    setSelected(prev => (prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]));

  const handleBook = async e => {
    e.preventDefault();
    if (!selected.length) return alert('Vui lòng chọn ít nhất 1 ghế');
    setSubmitting(true);
    try {
      const r = await fetch('/api/book', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ trip_id: tripId, seats: selected, ...form }),
      });
      const d = await r.json();
      if (d.success) {
        if (d.checkoutUrl) {
          window.location.href = d.checkoutUrl;
        } else {
          setTicketCodes(d.ticket_codes || []);
          setDone(true);
        }
      } else {
        alert(d.message);
      }
    } catch {
      alert('Lỗi kết nối máy chủ');
    }
    setSubmitting(false);
  };

  const seatMap = useMemo(() => {
    if (!trip || !Array.isArray(trip.seat_map)) return [];
    return trip.seat_map;
  }, [trip]);

  const totalPrice = (selected.length * (trip?.price || 0)).toLocaleString('vi-VN');

  return (
    <div
      onClick={e => e.target === e.currentTarget && onClose()}
      className="fixed inset-0 z-[1000] flex items-center justify-center bg-[#202938]/50 p-4"
    >
      <div className="flex max-h-[90vh] w-full max-w-4xl flex-col overflow-hidden rounded-2xl border border-[#E7EAF0] bg-white shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-[#E7EAF0] px-6 py-4">
          <div className="flex items-center gap-3">
            <span className="grid size-10 place-items-center rounded-xl bg-[#FFF1E6] text-[#FF6B00]">
              <Bus size={20} />
            </span>
            <div>
              <h2 className="text-lg font-extrabold text-[#202938]">Chọn vị trí ghế & Thông tin đặt vé</h2>
              <p className="text-xs font-medium text-[#778196]">
                {trip?.company_name || 'Nhà xe Triply'} • {trip?.bus_type || 'Limousine'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="grid size-9 place-items-center rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] text-[#778196] hover:border-[#FF6B00] hover:text-[#FF6B00]"
          >
            <X size={18} />
          </button>
        </div>

        {loading ? (
          <div className="flex flex-1 flex-col items-center justify-center gap-3 p-16">
            <div className="size-8 animate-spin rounded-full border-3 border-[#FF6B00] border-t-transparent" />
            <p className="text-sm font-semibold text-[#778196]">Đang tải sơ đồ ghế...</p>
          </div>
        ) : done ? (
          <div className="flex flex-1 flex-col items-center justify-center gap-4 p-12 text-center">
            <div className="grid size-16 place-items-center rounded-full bg-[#E9F8F0] text-[#16A36A]">
              <CheckCircle2 size={36} />
            </div>
            <h3 className="text-2xl font-black text-[#202938]">Đặt vé thành công!</h3>
            <div className="rounded-xl border border-[#FF6B00]/30 bg-[#FFF9F5] px-6 py-4">
              <p className="text-xs font-bold uppercase tracking-wider text-[#778196] mb-2">
                Mã vé điện tử của bạn
              </p>
              <div className="flex flex-wrap justify-center gap-2">
                {ticketCodes.map(code => (
                  <span
                    key={code}
                    className="rounded-lg bg-[#FF6B00] px-3.5 py-1.5 text-base font-black text-white"
                  >
                    {code}
                  </span>
                ))}
              </div>
            </div>
            <p className="max-w-md text-sm text-[#778196]">
              Vui lòng lưu lại mã vé để tra cứu lịch trình hoặc xuất trình khi lên xe.
            </p>
            <button
              onClick={onClose}
              className="mt-2 rounded-xl bg-[#FF6B00] hover:bg-[#E85F00] px-6 py-2.5 text-sm font-bold text-white"
            >
              Hoàn tất
            </button>
          </div>
        ) : (
          <div className="flex flex-1 flex-col md:flex-row gap-6 overflow-y-auto p-6">
            {/* Seat Map */}
            <div className="flex-1">
              <div className="mb-4 flex items-center justify-center gap-6 rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] py-2.5 px-4 text-xs font-semibold text-[#778196]">
                <span className="flex items-center gap-1.5">
                  <span className="inline-block size-3.5 rounded border border-[#D5DBE5] bg-white" /> Ghế trống
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="inline-block size-3.5 rounded bg-[#FF6B00]" /> Đang chọn
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="inline-block size-3.5 rounded bg-[#E2E6ED]" /> Đã đặt
                </span>
              </div>

              <div className="flex flex-wrap justify-center gap-5">
                {seatMap.map((floor, fi) => (
                  <div
                    key={fi}
                    className="rounded-2xl border border-[#E7EAF0] bg-[#F7F8FA] p-5"
                  >
                    <p className="mb-4 text-center text-xs font-extrabold uppercase tracking-wider text-[#202938]">
                      {floor.floor || `Tầng ${fi + 1}`}
                    </p>
                    <div className="flex flex-col gap-2.5">
                      {Array.isArray(floor.rows) &&
                        floor.rows.map((row, ri) => (
                          <div key={ri} className="flex gap-2.5 justify-center">
                            {Array.isArray(row) &&
                              row.map(seat => {
                                const occ = seat.status === 'occupied';
                                const sel = selected.includes(seat.id);
                                return (
                                  <button
                                    key={seat.id}
                                    type="button"
                                    disabled={occ}
                                    onClick={() => toggle(seat.id)}
                                    className={`size-11 rounded-xl border text-xs font-extrabold transition ${
                                      occ
                                        ? 'border-[#E2E6ED] bg-[#E2E6ED] text-[#98A2B3] cursor-not-allowed'
                                        : sel
                                          ? 'border-[#FF6B00] bg-[#FF6B00] text-white shadow-sm'
                                          : 'border-[#D5DBE5] bg-white text-[#202938] hover:border-[#FF6B00]'
                                    }`}
                                  >
                                    {seat.name || seat.id}
                                  </button>
                                );
                              })}
                          </div>
                        ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Passenger & Payment Form */}
            <div className="w-full md:w-80 shrink-0">
              <div className="mb-4 rounded-xl border border-[#FF6B00]/25 bg-[#FFF9F5] p-4">
                <h4 className="text-xs font-extrabold uppercase tracking-wider text-[#202938] pb-2 mb-2 border-b border-[#E7EAF0]">
                  Tóm tắt đặt vé
                </h4>
                <div className="flex justify-between text-xs mb-1.5">
                  <span className="text-[#778196]">Ghế đã chọn:</span>
                  <strong className="text-[#202938]">
                    {selected.length > 0 ? selected.join(', ') : 'Chưa chọn'}
                  </strong>
                </div>
                <div className="flex justify-between items-baseline">
                  <span className="text-xs text-[#778196]">Tổng tiền:</span>
                  <strong className="text-lg font-black text-[#FF6B00]">{totalPrice} đ</strong>
                </div>
              </div>

              <form onSubmit={handleBook} className="grid gap-3">
                <input
                  type="text"
                  placeholder="Họ và tên hành khách *"
                  required
                  value={form.name}
                  onChange={e => setForm({ ...form, name: e.target.value })}
                  className="w-full rounded-xl border border-[#E7EAF0] bg-white px-3.5 py-2.5 text-sm font-medium text-[#202938] outline-none focus:border-[#FF6B00]"
                />
                <input
                  type="tel"
                  placeholder="Số điện thoại liên hệ *"
                  required
                  value={form.phone}
                  onChange={e => setForm({ ...form, phone: e.target.value.replace(/\D/g, '') })}
                  className="w-full rounded-xl border border-[#E7EAF0] bg-white px-3.5 py-2.5 text-sm font-medium text-[#202938] outline-none focus:border-[#FF6B00]"
                />
                <input
                  type="text"
                  placeholder="Điểm đón (Tùy chọn)"
                  value={form.pickup}
                  onChange={e => setForm({ ...form, pickup: e.target.value })}
                  className="w-full rounded-xl border border-[#E7EAF0] bg-white px-3.5 py-2.5 text-sm font-medium text-[#202938] outline-none focus:border-[#FF6B00]"
                />
                <input
                  type="text"
                  placeholder="Điểm trả (Tùy chọn)"
                  value={form.dropoff}
                  onChange={e => setForm({ ...form, dropoff: e.target.value })}
                  className="w-full rounded-xl border border-[#E7EAF0] bg-white px-3.5 py-2.5 text-sm font-medium text-[#202938] outline-none focus:border-[#FF6B00]"
                />
                <select
                  value={form.payment_method}
                  onChange={e => setForm({ ...form, payment_method: e.target.value })}
                  className="w-full rounded-xl border border-[#E7EAF0] bg-white px-3.5 py-2.5 text-sm font-semibold text-[#202938] outline-none focus:border-[#FF6B00]"
                >
                  <option value="cash">Thanh toán tiền mặt khi lên xe</option>
                  <option value="payos">Thanh toán trực tuyến (PayOS QR)</option>
                </select>
                <button
                  type="submit"
                  disabled={submitting || !selected.length}
                  className="mt-1 w-full rounded-xl bg-[#FF6B00] hover:bg-[#E85F00] py-3 text-sm font-bold text-white transition disabled:opacity-50 cursor-pointer"
                >
                  {submitting ? 'Đang xử lý...' : 'Xác nhận đặt vé'}
                </button>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

// ---- Trip Card ----
const TripCard = React.memo(({ trip, onSelect }) => {
  if (!trip || !trip.id) return null;

  const fmt = iso => {
    try {
      return new Date(iso).toLocaleTimeString('vi-VN', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
      });
    } catch {
      return '--:--';
    }
  };

  const depTime = fmt(trip.departure_time);
  const arrTime = fmt(new Date(new Date(trip.departure_time).getTime() + 4.75 * 3600000));
  const seats = trip.available_seats ?? 0;
  const isLow = seats <= 5;

  return (
    <div className="mb-4 rounded-2xl border border-[#E7EAF0] bg-white p-5 transition hover:border-[#FF6B00]/50 card-shadow">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-5">
        <div className="flex-1">
          <div className="flex items-center justify-between sm:justify-start gap-3 mb-4">
            <div className="flex items-center gap-3">
              <div className="grid size-10 place-items-center rounded-xl bg-[#FFF1E6] text-[#FF6B00]">
                <Bus size={20} />
              </div>
              <div>
                <h3 className="text-base font-extrabold text-[#202938]">
                  {trip.company_name || 'Nhà xe Triply'}
                </h3>
                <span className="inline-block rounded-md border border-[#E7EAF0] bg-[#F7F8FA] px-2 py-0.5 text-xs font-semibold text-[#778196]">
                  {trip.bus_type || 'Limousine'}
                </span>
              </div>
            </div>
            <span
              className={`rounded-lg px-2.5 py-1 text-xs font-bold ${
                isLow ? 'bg-[#FFF5E5] text-[#E99A22]' : 'bg-[#E9F8F0] text-[#16A36A]'
              }`}
            >
              Còn {seats} chỗ trống
            </span>
          </div>

          <div className="flex items-center gap-4 rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] px-4 py-3">
            <div>
              <div className="text-xl font-black text-[#202938]">{depTime}</div>
              <div className="text-xs font-semibold text-[#778196]">{trip.start_point || 'Điểm đi'}</div>
            </div>
            <div className="flex-1 text-center px-2">
              <div className="text-[11px] font-semibold text-[#778196]">Chuyến thẳng</div>
              <div className="my-1 flex items-center">
                <span className="size-2 rounded-full bg-[#FF6B00]" />
                <span className="flex-1 border-t border-dashed border-[#D0D5DD]" />
                <ArrowRight size={14} className="text-[#FF6B00]" />
              </div>
              <div className="text-[11px] font-medium text-[#16A36A]">Giữ chỗ tức thì</div>
            </div>
            <div className="text-right">
              <div className="text-xl font-black text-[#202938]">{arrTime}</div>
              <div className="text-xs font-semibold text-[#778196]">{trip.end_point || 'Điểm đến'}</div>
            </div>
          </div>
        </div>

        <div className="flex sm:flex-col items-center sm:items-end justify-between border-t sm:border-t-0 sm:border-l border-[#E7EAF0] pt-3 sm:pt-0 sm:pl-6 min-w-[165px]">
          <div className="sm:text-right sm:mb-3">
            <span className="block text-xs text-[#778196]">Giá vé niêm yết</span>
            <div className="text-2xl font-black text-[#FF6B00]">
              {(trip.price || 0).toLocaleString('vi-VN')} đ
            </div>
          </div>
          <button
            onClick={() => onSelect(trip.id)}
            className="rounded-xl bg-[#FF6B00] hover:bg-[#E85F00] px-5 py-2.5 text-sm font-bold text-white transition w-auto sm:w-full cursor-pointer"
          >
            Chọn ghế
          </button>
        </div>
      </div>
    </div>
  );
});

// ---- Main Page ----
const SearchResults = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [trips, setTrips] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedTripId, setSelectedTripId] = useState(searchParams.get('trip_id') || null);
  const [sortBy, setSortBy] = useState('default');
  const [filterCompanies, setFilterCompanies] = useState([]);
  const [maxPrice, setMaxPrice] = useState(1000000);

  const from = searchParams.get('start_point') || '';
  const to = searchParams.get('end_point') || '';
  const date = searchParams.get('date') || new Date().toISOString().split('T')[0];

  useEffect(() => {
    setIsLoading(true);
    setTrips([]);
    fetch(
      `/api/search?start_point=${encodeURIComponent(from)}&end_point=${encodeURIComponent(to)}&date=${encodeURIComponent(date)}`
    )
      .then(r => r.json())
      .then(data => {
        setTrips(Array.isArray(data) ? data : []);
        setIsLoading(false);
      })
      .catch(() => {
        setTrips([]);
        setIsLoading(false);
      });
  }, [from, to, date]);

  useEffect(() => {
    const tid = searchParams.get('trip_id');
    if (tid) setSelectedTripId(tid);
  }, [searchParams]);

  const companies = useMemo(() => {
    if (!Array.isArray(trips) || trips.length === 0) return [];
    return [...new Set(trips.map(t => t?.company_name).filter(Boolean))];
  }, [trips]);

  const displayed = useMemo(() => {
    if (!Array.isArray(trips)) return [];
    let r = trips.filter(t => t && typeof t === 'object');
    if (filterCompanies.length > 0) r = r.filter(t => filterCompanies.includes(t.company_name));
    r = r.filter(t => (t.price || 0) <= maxPrice);
    if (sortBy === 'time_asc')
      r = [...r].sort((a, b) => new Date(a.departure_time) - new Date(b.departure_time));
    if (sortBy === 'time_desc')
      r = [...r].sort((a, b) => new Date(b.departure_time) - new Date(a.departure_time));
    if (sortBy === 'price_asc') r = [...r].sort((a, b) => (a.price || 0) - (b.price || 0));
    if (sortBy === 'price_desc') r = [...r].sort((a, b) => (b.price || 0) - (a.price || 0));
    return r;
  }, [trips, sortBy, filterCompanies, maxPrice]);

  const toggleCompany = name => {
    setFilterCompanies(prev =>
      prev.includes(name) ? prev.filter(c => c !== name) : [...prev, name]
    );
  };

  return (
    <div className="min-h-screen bg-[#F7F8FA]">
      <Navbar />

      {/* Route Summary Sub-header */}
      <div className="border-b border-[#E7EAF0] bg-white py-4">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 sm:px-6 lg:px-8">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex items-center gap-2 rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] px-3.5 py-2 text-sm font-bold text-[#202938]">
              <MapPin size={16} className="text-[#FF6B00]" />
              <span>{from || 'Điểm đi'}</span>
              <ArrowRight size={14} className="text-[#778196]" />
              <span>{to || 'Điểm đến'}</span>
            </div>
            <div className="flex items-center gap-2 rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] px-3.5 py-2 text-sm font-bold text-[#202938]">
              <Calendar size={16} className="text-[#FF6B00]" />
              <span>{new Date(date + 'T00:00:00').toLocaleDateString('vi-VN')}</span>
            </div>
          </div>
          <button
            onClick={() => navigate('/')}
            className="rounded-xl border border-[#E7EAF0] bg-white px-4 py-2 text-xs font-bold text-[#202938] hover:border-[#FF6B00] hover:text-[#FF6B00] transition cursor-pointer"
          >
            Đổi hành trình
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="mx-auto flex max-w-7xl flex-col lg:flex-row gap-6 px-4 py-8 sm:px-6 lg:px-8">
        {/* Sidebar Filters */}
        <aside className="w-full lg:w-64 shrink-0 space-y-4">
          <div className="rounded-2xl border border-[#E7EAF0] bg-white p-5 card-shadow">
            <h3 className="text-xs font-extrabold uppercase tracking-wider text-[#202938] mb-3.5 flex items-center gap-2">
              <Filter size={14} className="text-[#FF6B00]" /> Sắp xếp theo
            </h3>
            <div className="space-y-2.5">
              {[
                ['default', 'Mặc định'],
                ['time_asc', 'Giờ khởi hành sớm nhất'],
                ['time_desc', 'Giờ khởi hành muộn nhất'],
                ['price_asc', 'Giá vé thấp đến cao'],
                ['price_desc', 'Giá vé cao đến thấp'],
              ].map(([val, label]) => (
                <label
                  key={val}
                  onClick={() => setSortBy(val)}
                  className="flex items-center gap-2.5 cursor-pointer text-sm"
                >
                  <span
                    className={`grid size-4 place-items-center rounded-full border ${
                      sortBy === val ? 'border-[#FF6B00]' : 'border-[#D0D5DD]'
                    }`}
                  >
                    {sortBy === val && <span className="size-2 rounded-full bg-[#FF6B00]" />}
                  </span>
                  <span
                    className={
                      sortBy === val
                        ? 'font-bold text-[#202938]'
                        : 'font-medium text-[#778196]'
                    }
                  >
                    {label}
                  </span>
                </label>
              ))}
            </div>
          </div>

          <div className="rounded-2xl border border-[#E7EAF0] bg-white p-5 card-shadow">
            <div className="flex items-center justify-between mb-3.5">
              <h3 className="text-xs font-extrabold uppercase tracking-wider text-[#202938]">
                Bộ lọc chuyến
              </h3>
              <button
                onClick={() => {
                  setFilterCompanies([]);
                  setMaxPrice(1000000);
                }}
                className="text-xs font-bold text-[#FF6B00] hover:underline cursor-pointer"
              >
                Đặt lại
              </button>
            </div>

            {companies.length > 0 && (
              <div className="mb-4">
                <p className="text-xs font-bold text-[#778196] mb-2">Nhà xe</p>
                <div className="space-y-2">
                  {companies.map(c => (
                    <label
                      key={c}
                      onClick={() => toggleCompany(c)}
                      className="flex items-center gap-2.5 cursor-pointer text-sm"
                    >
                      <span
                        className={`grid size-4 place-items-center rounded border text-[10px] font-bold ${
                          filterCompanies.includes(c)
                            ? 'border-[#FF6B00] bg-[#FF6B00] text-white'
                            : 'border-[#D0D5DD] bg-white'
                        }`}
                      >
                        {filterCompanies.includes(c) && '✓'}
                      </span>
                      <span className="font-medium text-[#202938]">{c}</span>
                    </label>
                  ))}
                </div>
              </div>
            )}

            <div>
              <p className="text-xs font-bold text-[#778196] mb-2">Mức giá tối đa</p>
              <input
                type="range"
                min="0"
                max="1000000"
                step="50000"
                value={maxPrice}
                onChange={e => setMaxPrice(Number(e.target.value))}
                className="w-full accent-[#FF6B00]"
              />
              <div className="mt-1 flex justify-between text-xs font-bold text-[#778196]">
                <span>0 đ</span>
                <span className="text-[#FF6B00]">{maxPrice.toLocaleString('vi-VN')} đ</span>
              </div>
            </div>
          </div>
        </aside>

        {/* Trip Results List */}
        <main className="flex-1 min-w-0">
          <div className="mb-4 flex items-center justify-between">
            <h1 className="text-lg font-extrabold text-[#202938]">
              Tìm thấy <span className="text-[#FF6B00]">{displayed.length} chuyến xe</span> phù hợp
            </h1>
          </div>

          {isLoading && (
            <div className="rounded-2xl border border-[#E7EAF0] bg-white p-16 text-center">
              <div className="mx-auto size-8 animate-spin rounded-full border-3 border-[#FF6B00] border-t-transparent" />
              <p className="mt-3 text-sm font-semibold text-[#778196]">
                Đang tìm kiếm chuyến xe...
              </p>
            </div>
          )}

          {!isLoading && displayed.length === 0 && (
            <div className="rounded-2xl border border-[#E7EAF0] bg-white p-14 text-center">
              <div className="mx-auto grid size-14 place-items-center rounded-full bg-[#FFF1E6] text-[#FF6B00]">
                <Bus size={28} />
              </div>
              <h3 className="mt-4 text-base font-extrabold text-[#202938]">
                Không tìm thấy chuyến xe phù hợp
              </h3>
              <p className="mt-1 text-sm text-[#778196]">
                Bạn hãy thử chọn ngày khởi hành khác hoặc bỏ bớt bộ lọc.
              </p>
            </div>
          )}

          {!isLoading &&
            displayed.length > 0 &&
            displayed.map(trip => (
              <TripCard key={trip.id} trip={trip} onSelect={setSelectedTripId} />
            ))}
        </main>
      </div>

      {selectedTripId && (
        <BookingModal tripId={selectedTripId} onClose={() => setSelectedTripId(null)} />
      )}
    </div>
  );
};

export default function SearchResultsPage() {
  return (
    <ErrorBoundary>
      <SearchResults />
    </ErrorBoundary>
  );
}
