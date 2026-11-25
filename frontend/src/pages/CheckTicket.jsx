import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { Search, Ticket, Phone } from 'lucide-react';
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

  const handleSearch = async e => {
    if (e && e.preventDefault) e.preventDefault();
    const p = phone || initialPhone;
    const c = ticketCode || initialCode;
    if (!p || !c) return;

    setLoading(true);
    setError('');
    setTicket(null);

    try {
      const res = await fetch(
        `/api/check-ticket?phone=${encodeURIComponent(p)}&code=${encodeURIComponent(c)}`
      );
      const data = await res.json();

      if (res.ok && data.success) {
        setTicket(data.ticket);
      } else {
        setError(data.message || 'Không tìm thấy vé. Vui lòng kiểm tra lại mã vé và số điện thoại.');
      }
    } catch {
      setError('Lỗi kết nối đến máy chủ. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-[#F7F8FA]">
      <Navbar />

      <main className="flex-1 mx-auto w-full max-w-3xl px-4 py-12 sm:px-6">
        <div className="text-center mb-8">
          <span className="inline-flex items-center gap-1.5 rounded-full bg-[#FFF1E6] px-3 py-1 text-xs font-bold text-[#FF6B00] mb-3">
            <Ticket size={14} /> Vé xe điện tử Triply
          </span>
          <h1 className="text-2xl sm:text-3xl font-black text-[#202938]">
            Tra cứu thông tin vé đã đặt
          </h1>
          <p className="mt-1.5 text-sm text-[#778196]">
            Nhập số điện thoại và mã vé (VD: HT12345678) để kiểm tra trạng thái vé và vị trí ghế
          </p>
        </div>

        <div className="rounded-2xl border border-[#E7EAF0] bg-white p-6 card-shadow mb-6">
          <form onSubmit={handleSearch} className="grid grid-cols-1 sm:grid-cols-12 gap-4 items-end">
            <div className="sm:col-span-5">
              <label className="block text-xs font-bold text-[#202938] mb-1.5">
                Số điện thoại đặt vé
              </label>
              <div className="relative">
                <Phone size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" />
                <input
                  type="tel"
                  required
                  placeholder="VD: 0912345678"
                  value={phone}
                  onChange={e => setPhone(e.target.value.replace(/\D/g, ''))}
                  className="w-full rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] pl-10 pr-3.5 py-2.5 text-sm font-semibold text-[#202938] outline-none focus:border-[#FF6B00] focus:bg-white"
                />
              </div>
            </div>
            <div className="sm:col-span-4">
              <label className="block text-xs font-bold text-[#202938] mb-1.5">Mã đặt vé</label>
              <div className="relative">
                <Ticket size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#778196]" />
                <input
                  type="text"
                  required
                  placeholder="HT12345678"
                  value={ticketCode}
                  onChange={e => setTicketCode(e.target.value.toUpperCase())}
                  className="w-full rounded-xl border border-[#E7EAF0] bg-[#F7F8FA] pl-10 pr-3.5 py-2.5 text-sm font-semibold text-[#202938] outline-none focus:border-[#FF6B00] focus:bg-white"
                />
              </div>
            </div>
            <div className="sm:col-span-3">
              <button
                type="submit"
                disabled={loading || !phone || !ticketCode}
                className="w-full h-[42px] rounded-xl bg-[#FF6B00] hover:bg-[#E85F00] text-white text-sm font-bold transition disabled:opacity-50 flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <Search size={16} />
                {loading ? 'Đang tìm...' : 'Tra cứu'}
              </button>
            </div>
          </form>
        </div>

        {error && (
          <div className="rounded-xl border border-[#F8C6C6] bg-[#FDECEC] p-4 text-center text-sm font-bold text-[#DC4545] mb-6">
            {error}
          </div>
        )}

        {ticket && (
          <div className="overflow-hidden rounded-2xl border border-[#E7EAF0] bg-white card-shadow">
            <div className="flex items-center justify-between bg-[#FF6B00] px-6 py-4 text-white">
              <div>
                <div className="text-[11px] font-bold uppercase tracking-wider text-white/80">
                  Mã vé điện tử
                </div>
                <div className="text-xl font-black">{ticket.ticket_code}</div>
              </div>
              <span
                className={`rounded-lg px-3 py-1 text-xs font-extrabold ${
                  ticket.status === 'CANCELLED'
                    ? 'bg-[#FDECEC] text-[#DC4545]'
                    : 'bg-white text-[#16A36A]'
                }`}
              >
                {ticket.status === 'CANCELLED' ? 'Đã hủy' : 'Đã xác nhận'}
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-5 p-6">
              <div>
                <div className="text-xs font-semibold text-[#778196]">Hành khách</div>
                <div className="mt-1 text-sm font-bold text-[#202938]">{ticket.passenger_name}</div>
              </div>
              <div>
                <div className="text-xs font-semibold text-[#778196]">Hành trình</div>
                <div className="mt-1 text-sm font-bold text-[#202938]">{ticket.route}</div>
              </div>
              <div>
                <div className="text-xs font-semibold text-[#778196]">Thời gian khởi hành</div>
                <div className="mt-1 text-sm font-bold text-[#202938]">
                  {new Date(ticket.departure_time).toLocaleString('vi-VN')}
                </div>
              </div>
              <div>
                <div className="text-xs font-semibold text-[#778196]">Vị trí ghế</div>
                <div className="mt-1 text-sm font-black text-[#FF6B00]">Ghế {ticket.seat_number}</div>
              </div>
              <div>
                <div className="text-xs font-semibold text-[#778196]">Điểm đón</div>
                <div className="mt-1 text-sm font-bold text-[#202938]">
                  {ticket.pickup_point || 'Tại bến xuất phát'}
                </div>
              </div>
              <div>
                <div className="text-xs font-semibold text-[#778196]">Tổng tiền & Thanh toán</div>
                <div className="mt-1 text-sm font-black text-[#FF6B00]">
                  {ticket.ticket_price.toLocaleString('vi-VN')} đ{' '}
                  <span className="text-xs font-medium text-[#778196]">({ticket.payment_status})</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      <Footer />
    </div>
  );
};

export default CheckTicket;
