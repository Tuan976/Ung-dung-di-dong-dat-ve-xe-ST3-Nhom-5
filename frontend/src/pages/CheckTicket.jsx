import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import Navbar from '../components/Navbar';
import Footer from '../components/Footer';

const CheckTicket = () => {
  const location = useLocation();
  const searchParams = new URLSearchParams(location.search);
  const initialPhone = searchParams.get('phone') || '';
  const initialCode = searchParams.get('code') || '';

  const [phone, setPhone] = useState(initialPhone);
  const [ticketCode, setTicketCode] = useState(initialCode);
  const [loading, setLoading] = useState(false);
  const [ticket, setTicket] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (initialPhone && initialCode) {
      handleSearch(new Event('submit'));
    }
  }, []);

  const handleSearch = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    const p = phone || initialPhone;
    const c = ticketCode || initialCode;
    if (!p || !c) return;
    
    setLoading(true);
    setError('');
    setTicket(null);
    
    try {
      const res = await fetch(`/api/check-ticket?phone=${encodeURIComponent(p)}&code=${encodeURIComponent(c)}`);
      const data = await res.json();
      
      if (res.ok && data.success) {
        setTicket(data.ticket);
      } else {
        setError(data.message || 'Không tìm thấy vé. Vui lòng kiểm tra lại thông tin.');
      }
    } catch (err) {
      setError('Lỗi kết nối đến máy chủ. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', background: '#f8fafc' }}>
      <Navbar />
      
      <main style={{ flex: 1, padding: '120px 24px 60px', display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: '100%', maxWidth: 800 }}>
          <div style={{ textAlign: 'center', marginBottom: 40 }}>
            <h1 style={{ fontSize: 32, fontWeight: 900, color: '#1e293b', fontStyle: 'italic', textTransform: 'uppercase', marginBottom: 12 }}>
              Tra cứu thông tin vé
            </h1>
            <p style={{ color: '#64748b', fontSize: 14, fontWeight: 600 }}>
              Kiểm tra tình trạng chuyến đi và thông tin ghế ngồi của bạn
            </p>
          </div>
          
          <div style={{ background: '#fff', borderRadius: 24, padding: 32, boxShadow: '0 10px 30px rgba(0,0,0,0.05)', border: '1px solid #f1f5f9', marginBottom: 32 }}>
            <form onSubmit={handleSearch} style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
              <div style={{ flex: '1 1 200px' }}>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 8 }}>Số điện thoại đặt vé</label>
                <input 
                  type="tel" 
                  required
                  placeholder="Nhập số điện thoại..." 
                  value={phone}
                  onChange={e => setPhone(e.target.value.replace(/\D/g, ''))}
                  style={{ width: '100%', padding: '16px 20px', borderRadius: 16, border: '2px solid #f1f5f9', fontSize: 14, fontWeight: 700, color: '#1e293b', outline: 'none', transition: 'border-color 0.2s', boxSizing: 'border-box' }}
                  onFocus={e => e.target.style.borderColor = '#EF5222'}
                  onBlur={e => e.target.style.borderColor = '#f1f5f9'}
                />
              </div>
              <div style={{ flex: '1 1 200px' }}>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 8 }}>Mã vé</label>
                <input 
                  type="text" 
                  required
                  placeholder="Ví dụ: HT12345678" 
                  value={ticketCode}
                  onChange={e => setTicketCode(e.target.value)}
                  style={{ width: '100%', padding: '16px 20px', borderRadius: 16, border: '2px solid #f1f5f9', fontSize: 14, fontWeight: 700, color: '#1e293b', outline: 'none', transition: 'border-color 0.2s', boxSizing: 'border-box' }}
                  onFocus={e => e.target.style.borderColor = '#EF5222'}
                  onBlur={e => e.target.style.borderColor = '#f1f5f9'}
                />
              </div>
              <div style={{ flex: '0 0 auto', display: 'flex', alignItems: 'flex-end' }}>
                <button 
                  type="submit" 
                  disabled={loading || !phone || !ticketCode}
                  style={{ height: 55, padding: '0 32px', background: '#EF5222', color: '#fff', border: 'none', borderRadius: 16, fontSize: 13, fontWeight: 900, textTransform: 'uppercase', letterSpacing: 2, cursor: (loading || !phone || !ticketCode) ? 'not-allowed' : 'pointer', opacity: (loading || !phone || !ticketCode) ? 0.6 : 1, transition: 'all 0.2s' }}
                >
                  {loading ? 'Đang tìm...' : 'Tra cứu vé'}
                </button>
              </div>
            </form>
          </div>

          {error && (
            <div style={{ background: '#fef2f2', border: '1px solid #fecaca', borderRadius: 16, padding: 20, textAlign: 'center', marginBottom: 32 }}>
              <p style={{ color: '#ef4444', fontWeight: 700, fontSize: 14 }}>{error}</p>
            </div>
          )}

          {ticket && (
            <div style={{ background: '#fff', borderRadius: 24, padding: 32, boxShadow: '0 10px 30px rgba(0,0,0,0.05)', border: '1px solid #f1f5f9', position: 'relative', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', top: 0, left: 0, width: 8, height: '100%', background: ticket.status === 'CANCELLED' ? '#ef4444' : '#22c55e' }} />
              
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px dashed #e2e8f0', paddingBottom: 24, marginBottom: 24 }}>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Mã vé</div>
                  <div style={{ fontSize: 24, fontWeight: 900, color: '#1e293b' }}>{ticket.ticket_code}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Trạng thái</div>
                  <div style={{ display: 'inline-block', padding: '6px 12px', borderRadius: 8, fontSize: 11, fontWeight: 900, textTransform: 'uppercase', background: ticket.status === 'CANCELLED' ? '#fef2f2' : '#f0fdf4', color: ticket.status === 'CANCELLED' ? '#ef4444' : '#22c55e' }}>
                    {ticket.status === 'CANCELLED' ? 'Đã hủy' : 'Thành công'}
                  </div>
                </div>
              </div>
              
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 24 }}>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Hành khách</div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>{ticket.passenger_name}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Tuyến đường</div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>{ticket.route}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Thời gian khởi hành</div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>{new Date(ticket.departure_time).toLocaleString('vi-VN')}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Ghế / Tầng</div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#EF5222' }}>{ticket.seat_number}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Điểm đón</div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>{ticket.pickup_point || 'Tại bến'}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 900, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 }}>Thanh toán</div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#1e293b' }}>{ticket.ticket_price.toLocaleString()}đ <span style={{ color: '#94a3b8', fontSize: 12 }}>({ticket.payment_status})</span></div>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default CheckTicket;
