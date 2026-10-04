import React, { useState, useEffect, useMemo, Component } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import Navbar from '../components/Navbar';

class ErrorBoundary extends Component {
  constructor(props) { super(props); this.state = { hasError: false, error: null }; }
  static getDerivedStateFromError(e) { return { hasError: true, error: e }; }
  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: 40, fontFamily: 'sans-serif' }}>
          <h2 style={{ color: 'red' }}>Lỗi render trang</h2>
          <pre style={{ background: '#fee', padding: 16, borderRadius: 8, fontSize: 12, whiteSpace: 'pre-wrap' }}>
            {String(this.state.error)}
            {'\n'}
            {this.state.error?.stack}
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
  const [form, setForm] = useState({ name: '', phone: '', pickup: '', dropoff: '', payment_method: 'cash' });
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [ticketCodes, setTicketCodes] = useState([]);

  useEffect(() => {
    if (!tripId) return;
    fetch(`/api/trip/${tripId}`)
      .then(r => r.json())
      .then(data => { setTrip(data); setLoading(false); })
      .catch(() => setLoading(false));
  }, [tripId]);

  const toggle = (id) => setSelected(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);

  const handleBook = async (e) => {
    e.preventDefault();
    if (!selected.length) return alert('Chọn ít nhất 1 ghế');
    setSubmitting(true);
    try {
      const r = await fetch('/api/book', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ trip_id: tripId, seats: selected, ...form })
      });
      const d = await r.json();
      if (d.success) {
        if (d.checkoutUrl) {
          window.location.href = d.checkoutUrl;
        } else {
          setTicketCodes(d.ticket_codes || []);
          setDone(true);
        }
      } else alert(d.message);
    } catch { alert('Lỗi kết nối'); }
    setSubmitting(false);
  };

  const seatMap = useMemo(() => {
    if (!trip) return [];
    if (Array.isArray(trip.seat_map)) return trip.seat_map;
    return [];
  }, [trip]);

  const totalPrice = (selected.length * (trip?.price || 0)).toLocaleString();

  return (
    <div
      onClick={e => e.target === e.currentTarget && onClose()}
      style={{ position: 'fixed', inset: 0, zIndex: 999, background: 'rgba(15,23,42,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16, backdropFilter: 'blur(4px)' }}
    >
      <div style={{ background: '#fff', borderRadius: 40, width: '100%', maxWidth: 900, maxHeight: '88vh', overflow: 'hidden', display: 'flex', flexDirection: 'column', boxShadow: '0 25px 50px rgba(0,0,0,0.25)' }}>
        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '28px 40px', borderBottom: '1px solid #f8fafc' }}>
          <div>
            <h2 style={{ fontWeight: 900, color: '#1e293b', fontSize: 22, fontStyle: 'italic', textTransform: 'uppercase' }}>Chọn ghế & Đặt vé</h2>
            <p style={{ fontWeight: 700, color: '#94a3b8', fontSize: 11, textTransform: 'uppercase', letterSpacing: 3, marginTop: 4 }}>
              {trip?.company_name || '...'} • {trip?.bus_type || '...'}
            </p>
          </div>
          <button onClick={onClose} style={{ width: 44, height: 44, borderRadius: '50%', background: '#f8fafc', border: 'none', cursor: 'pointer', fontSize: 20, color: '#64748b' }}>✕</button>
        </div>

        {loading ? (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 16, padding: 60 }}>
            <div style={{ fontSize: 48 }}>🚌</div>
            <p style={{ color: '#94a3b8', fontWeight: 700, fontStyle: 'italic' }}>Đang tải sơ đồ ghế...</p>
          </div>
        ) : done ? (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 16, padding: 60, textAlign: 'center' }}>
            <div style={{ fontSize: 64 }}>✅</div>
            <h3 style={{ fontWeight: 900, color: '#1e293b', fontSize: 24 }}>Đặt vé thành công!</h3>
            <div style={{ background: '#f8fafc', padding: '16px 24px', borderRadius: 16, border: '1px dashed #cbd5e1', marginTop: 12 }}>
              <p style={{ color: '#64748b', fontSize: 13, fontWeight: 700, textTransform: 'uppercase', marginBottom: 8 }}>Mã vé của bạn</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center' }}>
                {ticketCodes.map(code => (
                  <span key={code} style={{ background: '#EF5222', color: '#fff', padding: '6px 12px', borderRadius: 8, fontSize: 18, fontWeight: 900 }}>{code}</span>
                ))}
              </div>
            </div>
            <p style={{ color: '#64748b', fontSize: 14, fontWeight: 600, marginTop: 12 }}>Vui lòng lưu lại mã vé để tra cứu thông tin chuyến đi.</p>
            <button onClick={onClose} style={{ marginTop: 24, padding: '12px 32px', background: '#1e293b', color: '#fff', borderRadius: 12, fontWeight: 700, cursor: 'pointer', border: 'none' }}>Đóng & Về trang chủ</button>
          </div>
        ) : (
          <div style={{ flex: 1, overflowY: 'auto', padding: 40, display: 'flex', gap: 40 }}>
            {/* Seat Map */}
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', gap: 20, justifyContent: 'center', marginBottom: 24 }}>
                {[['#f1f5f9', 'Trống'], ['#EF5222', 'Đang chọn'], ['#cbd5e1', 'Đã bán']].map(([c, l]) => (
                  <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 14, height: 14, borderRadius: 4, background: c }}></div>
                    <span style={{ fontWeight: 700, color: '#64748b', fontSize: 11, textTransform: 'uppercase' }}>{l}</span>
                  </div>
                ))}
              </div>
              <div style={{ display: 'flex', gap: 32, justifyContent: 'center', flexWrap: 'wrap' }}>
                {seatMap.map((floor, fi) => (
                  <div key={fi} style={{ background: '#f8fafc', borderRadius: 32, padding: 28, border: '1px solid #f1f5f9' }}>
                    <p style={{ textAlign: 'center', fontWeight: 900, color: '#cbd5e1', fontSize: 10, textTransform: 'uppercase', letterSpacing: 3, marginBottom: 20 }}>{floor.floor || `Tầng ${fi + 1}`}</p>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                      {Array.isArray(floor.rows) && floor.rows.map((row, ri) => (
                        <div key={ri} style={{ display: 'flex', gap: 12 }}>
                          {Array.isArray(row) && row.map(seat => {
                            const occ = seat.status === 'occupied';
                            const sel = selected.includes(seat.id);
                            return (
                              <button key={seat.id} disabled={occ} onClick={() => toggle(seat.id)}
                                style={{ width: 44, height: 44, borderRadius: 12, border: `2px solid ${occ ? '#e2e8f0' : sel ? '#EF5222' : '#e2e8f0'}`, background: occ ? '#e2e8f0' : sel ? '#EF5222' : '#fff', color: occ ? '#cbd5e1' : sel ? '#fff' : '#64748b', fontWeight: 900, fontSize: 10, cursor: occ ? 'not-allowed' : 'pointer', transition: 'all 0.15s', transform: sel ? 'scale(1.1)' : 'scale(1)' }}>
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

            {/* Form */}
            <div style={{ width: 300, flexShrink: 0 }}>
              <div style={{ background: '#f8fafc', borderRadius: 24, padding: 20, marginBottom: 20 }}>
                <h4 style={{ fontWeight: 900, color: '#1e293b', fontSize: 12, textTransform: 'uppercase', letterSpacing: 2, marginBottom: 16, borderBottom: '1px solid #e2e8f0', paddingBottom: 12 }}>Chi tiết</h4>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span style={{ fontWeight: 700, color: '#94a3b8', fontSize: 12 }}>Ghế:</span>
                  <span style={{ fontWeight: 900, color: '#1e293b', fontSize: 12 }}>{selected.length > 0 ? selected.join(', ') : 'Chưa chọn'}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontWeight: 700, color: '#94a3b8', fontSize: 12 }}>Tổng:</span>
                  <span style={{ fontWeight: 900, color: '#EF5222', fontSize: 20 }}>{totalPrice}đ</span>
                </div>
              </div>
              <form onSubmit={handleBook} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <input type="text" placeholder="Họ và tên" required value={form.name} onChange={e => setForm({ ...form, name: e.target.value })}
                  style={{ width: '100%', padding: '14px 16px', border: '1px solid #e2e8f0', borderRadius: 16, fontWeight: 700, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />
                <input type="tel" placeholder="Số điện thoại" required value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value.replace(/\D/g, '') })}
                  style={{ width: '100%', padding: '14px 16px', border: '1px solid #e2e8f0', borderRadius: 16, fontWeight: 700, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />
                <input type="text" placeholder="Điểm đón (nếu có)" value={form.pickup} onChange={e => setForm({ ...form, pickup: e.target.value })}
                  style={{ width: '100%', padding: '14px 16px', border: '1px solid #e2e8f0', borderRadius: 16, fontWeight: 700, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />
                <input type="text" placeholder="Điểm trả (nếu có)" value={form.dropoff} onChange={e => setForm({ ...form, dropoff: e.target.value })}
                  style={{ width: '100%', padding: '14px 16px', border: '1px solid #e2e8f0', borderRadius: 16, fontWeight: 700, fontSize: 13, outline: 'none', boxSizing: 'border-box' }} />
                  
                <select value={form.payment_method} onChange={e => setForm({ ...form, payment_method: e.target.value })}
                  style={{ width: '100%', padding: '14px 16px', border: '1px solid #e2e8f0', borderRadius: 16, fontWeight: 700, fontSize: 13, outline: 'none', boxSizing: 'border-box', appearance: 'none', backgroundColor: '#fff', backgroundImage: 'url("data:image/svg+xml;charset=US-ASCII,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%22292.4%22%20height%3D%22292.4%22%3E%3Cpath%20fill%3D%22%23131313%22%20d%3D%22M287%2069.4a17.6%2017.6%200%200%200-13-5.4H18.4c-5%200-9.3%201.8-12.9%205.4A17.6%2017.6%200%200%200%200%2082.2c0%205%201.8%209.3%205.4%2012.9l128%20127.9c3.6%203.6%207.8%205.4%2012.8%205.4s9.2-1.8%2012.8-5.4L287%2095c3.5-3.5%205.4-7.8%205.4-12.8%200-5-1.9-9.2-5.5-12.8z%22%2F%3E%3C%2Fsvg%3E")', backgroundRepeat: 'no-repeat', backgroundPosition: 'right .7em top 50%', backgroundSize: '.65em auto' }}>
                  <option value="cash">💵 Thanh toán tiền mặt (Trên xe)</option>
                  <option value="payos">💳 Chuyển khoản (PayOS QR)</option>
                </select>
                <button type="submit" disabled={submitting || !selected.length}
                  style={{ padding: 16, background: '#EF5222', color: '#fff', border: 'none', borderRadius: 16, fontWeight: 900, fontSize: 12, textTransform: 'uppercase', letterSpacing: 2, cursor: !selected.length ? 'not-allowed' : 'pointer', opacity: !selected.length ? 0.5 : 1 }}>
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

  const fmt = (iso) => {
    try { return new Date(iso).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', hour12: false }); }
    catch { return '--:--'; }
  };

  const depTime = fmt(trip.departure_time);
  const arrTime = fmt(new Date(new Date(trip.departure_time).getTime() + 4.75 * 3600000));

  return (
    <div style={{ background: '#fff', borderRadius: 24, padding: 24, border: '1px solid #f1f5f9', marginBottom: 16, transition: 'border-color 0.2s, box-shadow 0.2s' }}
      onMouseEnter={e => { e.currentTarget.style.borderColor = '#EF5222'; e.currentTarget.style.boxShadow = '0 8px 30px rgba(239,82,34,0.1)'; }}
      onMouseLeave={e => { e.currentTarget.style.borderColor = '#f1f5f9'; e.currentTarget.style.boxShadow = 'none'; }}
    >
      <div style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
            <div style={{ width: 44, height: 44, background: '#f8fafc', borderRadius: 16, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>🚌</div>
            <div>
              <div style={{ fontWeight: 900, color: '#1e293b', fontSize: 16 }}>{trip.company_name || 'Hutech Bus'}</div>
              <div style={{ fontWeight: 700, color: '#94a3b8', fontSize: 11, textTransform: 'uppercase' }}>{trip.bus_type || 'Standard'}</div>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontWeight: 900, color: '#1e293b', fontSize: 22 }}>{depTime}</div>
              <div style={{ fontWeight: 700, color: '#EF5222', fontSize: 10, textTransform: 'uppercase', marginTop: 4 }}>{trip.start_point || 'N/A'}</div>
            </div>
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontWeight: 700, color: '#94a3b8', fontSize: 11 }}>4h 45m ⚡</div>
              <div style={{ height: 1, borderTop: '1px dashed #e2e8f0', margin: '6px 0' }}></div>
              <div style={{ fontWeight: 700, color: '#94a3b8', fontSize: 10, fontStyle: 'italic' }}>Xác nhận tức thì</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontWeight: 900, color: '#1e293b', fontSize: 22 }}>{arrTime}</div>
              <div style={{ fontWeight: 700, color: '#64748b', fontSize: 10, textTransform: 'uppercase', marginTop: 4 }}>{trip.end_point || 'N/A'}</div>
            </div>
          </div>
        </div>
        <div style={{ borderLeft: '1px solid #f1f5f9', paddingLeft: 24, textAlign: 'right', minWidth: 160 }}>
          <div style={{ fontWeight: 900, color: '#EF5222', fontSize: 26 }}>{(trip.price || 0).toLocaleString()}đ</div>
          <div style={{ fontWeight: 700, color: '#94a3b8', fontSize: 11, marginBottom: 16 }}>Còn {trip.available_seats ?? 0} chỗ</div>
          <button onClick={() => onSelect(trip.id)}
            style={{ background: '#EF5222', color: '#fff', border: 'none', borderRadius: 12, padding: '12px 20px', fontWeight: 900, fontSize: 11, cursor: 'pointer', textTransform: 'uppercase', letterSpacing: 2, width: '100%' }}>
            Chọn chuyến
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
    fetch(`/api/search?start_point=${encodeURIComponent(from)}&end_point=${encodeURIComponent(to)}&date=${encodeURIComponent(date)}`)
      .then(r => r.json())
      .then(data => { setTrips(Array.isArray(data) ? data : []); setIsLoading(false); })
      .catch(() => { setTrips([]); setIsLoading(false); });
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
    if (sortBy === 'time_asc') r = [...r].sort((a, b) => new Date(a.departure_time) - new Date(b.departure_time));
    if (sortBy === 'time_desc') r = [...r].sort((a, b) => new Date(b.departure_time) - new Date(a.departure_time));
    if (sortBy === 'price_asc') r = [...r].sort((a, b) => (a.price || 0) - (b.price || 0));
    if (sortBy === 'price_desc') r = [...r].sort((a, b) => (b.price || 0) - (a.price || 0));
    return r;
  }, [trips, sortBy, filterCompanies, maxPrice]);

  const toggleCompany = (name) => {
    setFilterCompanies(prev => prev.includes(name) ? prev.filter(c => c !== name) : [...prev, name]);
  };

  return (
    <div style={{ minHeight: '100vh', background: '#f8fafc' }}>
      <Navbar />

      {/* Search Bar */}
      <div style={{ background: '#fff', borderBottom: '1px solid #e2e8f0', paddingTop: 112, paddingBottom: 20 }}>
        <div style={{ maxWidth: 1200, margin: '0 auto', padding: '0 24px', display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
          <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 12, padding: '10px 16px', display: 'flex', alignItems: 'center', gap: 8, flex: 1, minWidth: 200 }}>
            <span style={{ fontWeight: 900, color: '#1e293b', fontSize: 14 }}>📍 {from || 'Chưa chọn'}</span>
            <span style={{ color: '#cbd5e1', margin: '0 4px' }}>→</span>
            <span style={{ fontWeight: 900, color: '#1e293b', fontSize: 14 }}>{to || 'Chưa chọn'}</span>
          </div>
          <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 12, padding: '10px 16px' }}>
            <span style={{ fontWeight: 900, color: '#1e293b', fontSize: 14 }}>📅 {new Date(date + 'T00:00:00').toLocaleDateString('vi-VN')}</span>
          </div>
          <button onClick={() => navigate('/')} style={{ background: '#1e293b', color: '#fff', border: 'none', borderRadius: 12, padding: '10px 20px', fontWeight: 900, fontSize: 12, cursor: 'pointer', textTransform: 'uppercase', letterSpacing: 2 }}>
            Thay đổi
          </button>
        </div>
      </div>

      <div style={{ maxWidth: 1200, margin: '0 auto', padding: '32px 24px', display: 'flex', gap: 28, alignItems: 'flex-start' }}>
        {/* Sidebar */}
        <aside style={{ width: 260, flexShrink: 0 }}>
          <div style={{ background: '#fff', borderRadius: 24, padding: 24, marginBottom: 16, border: '1px solid #f1f5f9' }}>
            <h3 style={{ fontWeight: 900, color: '#1e293b', fontSize: 13, textTransform: 'uppercase', letterSpacing: 2, marginBottom: 16 }}>Sắp xếp</h3>
            {[['default', 'Mặc định'], ['time_asc', 'Giờ sớm nhất'], ['time_desc', 'Giờ muộn nhất'], ['price_asc', 'Giá tăng dần'], ['price_desc', 'Giá giảm dần']].map(([val, label]) => (
              <div key={val} onClick={() => setSortBy(val)} style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12, cursor: 'pointer' }}>
                <div style={{ width: 18, height: 18, borderRadius: '50%', border: `2px solid ${sortBy === val ? '#EF5222' : '#e2e8f0'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  {sortBy === val && <div style={{ width: 10, height: 10, borderRadius: '50%', background: '#EF5222' }} />}
                </div>
                <span style={{ fontWeight: 700, color: sortBy === val ? '#1e293b' : '#94a3b8', fontSize: 13 }}>{label}</span>
              </div>
            ))}
          </div>

          <div style={{ background: '#fff', borderRadius: 24, padding: 24, border: '1px solid #f1f5f9' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 20 }}>
              <h3 style={{ fontWeight: 900, color: '#1e293b', fontSize: 13, textTransform: 'uppercase', letterSpacing: 2 }}>Bộ lọc</h3>
              <button onClick={() => { setFilterCompanies([]); setMaxPrice(1000000); }} style={{ background: 'none', border: 'none', color: '#3b82f6', fontWeight: 900, fontSize: 10, cursor: 'pointer', textTransform: 'uppercase' }}>Xóa</button>
            </div>
            <p style={{ fontWeight: 900, color: '#94a3b8', fontSize: 10, textTransform: 'uppercase', letterSpacing: 3, marginBottom: 12 }}>Nhà xe</p>
            {companies.map(c => (
              <div key={c} onClick={() => toggleCompany(c)} style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10, cursor: 'pointer' }}>
                <div style={{ width: 18, height: 18, borderRadius: 6, border: `2px solid ${filterCompanies.includes(c) ? '#EF5222' : '#e2e8f0'}`, background: filterCompanies.includes(c) ? '#EF5222' : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  {filterCompanies.includes(c) && <span style={{ color: '#fff', fontSize: 10, fontWeight: 900 }}>✓</span>}
                </div>
                <span style={{ fontWeight: 700, color: filterCompanies.includes(c) ? '#1e293b' : '#64748b', fontSize: 13 }}>{c}</span>
              </div>
            ))}
            <p style={{ fontWeight: 900, color: '#94a3b8', fontSize: 10, textTransform: 'uppercase', letterSpacing: 3, marginTop: 20, marginBottom: 12 }}>Giá tối đa</p>
            <input type="range" min="0" max="1000000" step="50000" value={maxPrice} onChange={e => setMaxPrice(Number(e.target.value))} style={{ width: '100%', accentColor: '#EF5222' }} />
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, fontWeight: 900, color: '#64748b', marginTop: 8 }}>
              <span>0đ</span><span style={{ color: '#EF5222' }}>{maxPrice.toLocaleString()}đ</span>
            </div>
          </div>
        </aside>

        {/* Main */}
        <main style={{ flex: 1, minWidth: 0 }}>
          <h1 style={{ fontWeight: 900, color: '#1e293b', fontSize: 18, marginBottom: 24 }}>
            Kết quả: <span style={{ color: '#EF5222', fontStyle: 'italic' }}>{displayed.length} chuyến xe</span>
          </h1>

          {isLoading && (
            <div style={{ background: '#fff', borderRadius: 32, padding: 80, textAlign: 'center', border: '1px solid #f1f5f9' }}>
              <div style={{ fontSize: 48 }}>🚌</div>
              <p style={{ color: '#94a3b8', fontWeight: 700, marginTop: 16 }}>Đang tìm chuyến xe...</p>
            </div>
          )}

          {!isLoading && displayed.length === 0 && (
            <div style={{ background: '#fff', borderRadius: 32, padding: 80, textAlign: 'center', border: '1px solid #f1f5f9' }}>
              <div style={{ fontSize: 48 }}>😕</div>
              <h3 style={{ color: '#1e293b', fontWeight: 900, marginTop: 16 }}>Không tìm thấy chuyến xe</h3>
              <p style={{ color: '#94a3b8', fontWeight: 600, marginTop: 8 }}>Thử lại với ngày hoặc điểm đến khác.</p>
            </div>
          )}

          {!isLoading && displayed.length > 0 && displayed.map(trip => (
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
