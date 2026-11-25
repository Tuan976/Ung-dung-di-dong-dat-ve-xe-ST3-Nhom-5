import { useEffect, useRef, useState } from 'react';
import { ArrowUp, Bus, CalendarDays, ChevronRight, CircleHelp, LoaderCircle, MessageSquare, RotateCcw, Ticket, X } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';

const initialMessage = { response: 'Bạn muốn tìm chuyến, đặt vé hay tra vé đã đặt?' };
const primary = 'rounded-xl bg-[#d44519] px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-[#ad3515] disabled:cursor-not-allowed disabled:opacity-50';
const secondary = 'rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 transition hover:border-orange-300 hover:text-[#ad3515] disabled:opacity-50';
const field = 'min-w-0 rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none focus:border-orange-500 focus:ring-2 focus:ring-orange-100';
const currency = new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' });
const labels = { CONFIRMED: 'Đã xác nhận', HOLD: 'Đang giữ chỗ', CANCELLED: 'Đã hủy', Paid: 'Đã thanh toán', Pending: 'Chờ thu tiền', Unpaid: 'Chưa thanh toán', 'Refund Pending': 'Chờ hoàn tiền', Expired: 'Hết hạn', Cancelled: 'Đã hủy' };

function SearchForm({ criteria, places, busy, send }) {
  return (
    <form className="grid gap-2.5 rounded-2xl border border-slate-200 bg-white p-3.5" onSubmit={event => {
      event.preventDefault();
      const data = new FormData(event.currentTarget);
      send({ action: 'search', from: data.get('from'), to: data.get('to'), date: data.get('date'), pax: Number(data.get('pax')) });
    }}>
      {['from', 'to'].map(key => (
        <label key={key} className="grid gap-1 text-xs font-semibold text-slate-700">
          {key === 'from' ? 'Điểm đi' : 'Điểm đến'}
          <select className={field} name={key} defaultValue={criteria?.[key] || ''} required>
            <option value="">Chọn địa điểm</option>
            {places.map(place => <option key={place}>{place}</option>)}
          </select>
        </label>
      ))}
      <div className="grid grid-cols-[minmax(0,1fr)_5rem] gap-2">
        <label className="grid gap-1 text-xs font-semibold text-slate-700">
          Ngày đi
          <input className={field} name="date" type="date" defaultValue={criteria?.date || ''} required />
        </label>
        <label className="grid gap-1 text-xs font-semibold text-slate-700">
          Số vé
          <input className={field} name="pax" type="number" min="1" max="20" defaultValue={criteria?.pax || 1} required />
        </label>
      </div>
      <button className={primary} disabled={busy || !places.length}>Tìm chuyến</button>
    </form>
  );
}

function LookupForm({ code, busy, send }) {
  return (
    <form className="grid gap-2.5 rounded-2xl border border-slate-200 bg-white p-3.5" onSubmit={event => {
      event.preventDefault();
      const data = new FormData(event.currentTarget);
      send({ action: 'lookup', code: data.get('code'), phone: data.get('phone') }, 'Tra cứu vé');
    }}>
      <label className="grid gap-1 text-xs font-semibold text-slate-700">
        Mã vé
        <input className={field} name="code" defaultValue={code || ''} placeholder="HT12345678" maxLength={10} required />
      </label>
      <label className="grid gap-1 text-xs font-semibold text-slate-700">
        Số điện thoại đặt vé
        <input className={field} name="phone" type="tel" inputMode="tel" maxLength={20} required />
      </label>
      <button className={primary} disabled={busy}>Tra cứu</button>
    </form>
  );
}

function TripCard({ trip, onSelect, busy }) {
  return (
    <article className="grid gap-2 rounded-2xl border border-orange-100 bg-white p-3.5">
      <div className="flex items-start justify-between gap-2.5">
        <div className="min-w-0">
          <p className="text-sm font-bold text-slate-900">{trip.route_text}</p>
          <p className="mt-0.5 break-words text-xs text-slate-500">{trip.company_name} · {trip.bus_type_text}</p>
        </div>
        <span className="shrink-0 rounded-full bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-800">{trip.available_seats} ghế</span>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
        <span className="flex items-center gap-1.5 text-slate-600"><CalendarDays size={14} />{trip.time_text}</span>
        <strong className="text-[#ad3515]">{currency.format(trip.price_value)} <span className="text-xs font-normal text-slate-500">/ vé</span></strong>
      </div>
      <button type="button" className={primary} disabled={busy} onClick={onSelect}>Chọn ghế</button>
    </article>
  );
}

function TicketCard({ ticket, onCancel, busy }) {
  return (
    <article className="grid gap-2 rounded-2xl border border-slate-200 bg-white p-3.5 text-sm">
      <div className="flex items-center justify-between gap-2">
        <strong className="flex items-center gap-1.5 text-slate-900"><Ticket size={16} />{ticket.code}</strong>
        <span className="rounded-full bg-slate-100 px-2 py-1 text-xs text-slate-700">{labels[ticket.status] || ticket.status}</span>
      </div>
      <p className="font-semibold text-slate-800">{ticket.route}</p>
      <p className="text-xs leading-relaxed text-slate-600">{ticket.departure} · Ghế {ticket.seat} · {currency.format(ticket.price)}</p>
      {ticket.pickup && <p className="break-words text-xs text-slate-600">Điểm đón: {ticket.pickup}</p>}
      {ticket.dropoff && <p className="break-words text-xs text-slate-600">Điểm trả: {ticket.dropoff}</p>}
      <p className="text-xs text-slate-600">{labels[ticket.payment_status] || ticket.payment_status}</p>
      {ticket.can_cancel && <button type="button" onClick={onCancel} disabled={busy} className={secondary}>Hủy vé</button>}
    </article>
  );
}

function BookingForm({ checkout, onDone, onBack }) {
  const { trip, pax, contact } = checkout;
  const [map, setMap] = useState(null);
  const [selected, setSelected] = useState([]);
  const [summary, setSummary] = useState(null);
  const [error, setError] = useState('');
  const [sending, setSending] = useState(false);
  const submitting = useRef(false);

  useEffect(() => {
    const controller = new AbortController();
    fetch('/api/trip/' + trip.trip_id, { signal: controller.signal })
      .then(response => {
        if (!response.ok) throw new Error();
        return response.json();
      })
      .then(setMap)
      .catch(() => {
        if (!controller.signal.aborted) setError('Không tải được sơ đồ ghế. Bạn hãy chọn lại chuyến.');
      });
    return () => controller.abort();
  }, [trip.trip_id]);

  const available = map?.seat_map?.flatMap(floor => floor.rows.flat()).filter(seat => seat.status === 'available') || [];

  function toggleSeat(id) {
    setError('');
    setSelected(current => current.includes(id) ? current.filter(seat => seat !== id) : current.length < pax ? [...current, id] : current);
  }

  function prepare(event) {
    event.preventDefault();
    setError('');
    if (selected.length !== pax) {
      setError('Bạn cần chọn đủ ' + pax + ' ghế.');
      return;
    }
    const values = Object.fromEntries(new FormData(event.currentTarget));
    if (!values.name.trim()) {
      setError('Bạn nhập tên hành khách nhé.');
      return;
    }
    setSummary(values);
  }

  async function confirm() {
    if (submitting.current) return;
    submitting.current = true;
    setSending(true);
    setError('');
    try {
      const response = await fetch('/api/book', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...summary, trip_id: trip.trip_id, seats: selected, expected_price: map.price }),
      });
      const data = await response.json();
      if (!response.ok || !data.success) {
        setError(data.message || 'Chưa thể đặt vé. Bạn kiểm tra lại ghế đã chọn.');
        return;
      }
      if (data.checkoutUrl) {
        const checkoutUrl = new URL(data.checkoutUrl);
        if (checkoutUrl.protocol !== 'https:') throw new Error();
        onDone({ response: 'Đã giữ ghế. Bạn mở cổng thanh toán để hoàn tất.', paymentUrl: checkoutUrl.href });
      } else {
        onDone({ response: 'Đã đặt vé thành công. Bạn thanh toán tiền mặt trên xe.', codes: data.ticket_codes || [] });
      }
    } catch {
      setError('Không nhận được kết quả. Bạn kiểm tra vé đã đặt trước khi thử lại.');
    } finally {
      submitting.current = false;
      setSending(false);
    }
  }

  return (
    <section className="grid gap-3 rounded-2xl border border-orange-100 bg-white p-3.5">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="text-sm font-bold text-slate-900">{summary ? 'Xác nhận đặt vé' : 'Chọn ghế và thông tin'}</h3>
          <p className="mt-1 text-xs text-slate-600">{trip.route_text} · {trip.time_text}</p>
        </div>
        <button type="button" className={secondary} disabled={sending} onClick={onBack}>Quay lại</button>
      </div>
      {!map && !error && <p className="text-sm text-slate-500">Đang tải sơ đồ ghế…</p>}
      {map && <form className={summary ? 'hidden' : 'grid gap-3'} onSubmit={prepare}>
        <div className="flex flex-wrap items-center justify-between gap-2 text-xs font-semibold text-slate-700">
          <span>Đã chọn {selected.length}/{pax} ghế</span>
          <button type="button" className={secondary} disabled={available.length < pax} onClick={() => {
            setSelected(available.slice(0, pax).map(seat => seat.id));
            setError('');
          }}>Chọn giúp {pax} ghế</button>
        </div>
        <div className="max-h-56 space-y-2 overflow-auto rounded-xl bg-slate-50 p-2.5">
          {map.seat_map.map((floor, index) => <fieldset className="space-y-1.5" key={index}>
            <legend className="py-1 text-xs font-semibold text-slate-600">{floor.floor}</legend>
            {floor.rows.map((row, rowIndex) => <div key={rowIndex} className="flex flex-wrap gap-1.5">
              {row.map(seat => <button type="button" key={seat.id}
                aria-label={'Ghế ' + seat.id}
                aria-pressed={selected.includes(seat.id)}
                disabled={seat.status !== 'available'}
                className={'min-w-10 rounded-lg border px-2 py-1.5 text-xs font-semibold disabled:bg-slate-200 disabled:text-slate-500 ' + (selected.includes(seat.id) ? 'border-[#d44519] bg-orange-100 text-[#ad3515]' : 'border-slate-200 bg-white text-slate-700')}
                onClick={() => toggleSeat(seat.id)}>{seat.name || seat.id}</button>)}
            </div>)}
          </fieldset>)}
        </div>
        <label className="grid gap-1 text-xs font-semibold text-slate-700">Họ tên
          <input className={field} name="name" defaultValue={contact?.name || ''} maxLength={100} autoComplete="name" required />
        </label>
        <label className="grid gap-1 text-xs font-semibold text-slate-700">Số điện thoại
          <input className={field} name="phone" type="tel" defaultValue={contact?.phone || ''} maxLength={20} autoComplete="tel" required />
        </label>
        <div className="grid grid-cols-2 gap-2">
          <label className="grid min-w-0 gap-1 text-xs font-semibold text-slate-700">Điểm đón
            <input className={field} name="pickup" maxLength={200} />
          </label>
          <label className="grid min-w-0 gap-1 text-xs font-semibold text-slate-700">Điểm trả
            <input className={field} name="dropoff" maxLength={200} />
          </label>
        </div>
        <label className="grid gap-1 text-xs font-semibold text-slate-700">Thanh toán
          <select className={field} name="payment_method">
            <option value="cash">Tiền mặt trên xe</option>
            {checkout.online_payment && <option value="payos">Thanh toán qua PayOS</option>}
          </select>
        </label>
        <button className={primary} disabled={selected.length !== pax}>Xem lại đơn</button>
      </form>}
      {summary && <div className="grid gap-2.5 text-sm text-slate-700">
        <p>Ghế <strong>{selected.join(', ')}</strong> · {summary.name} · {summary.phone}</p>
        {(summary.pickup || summary.dropoff) && <p>{summary.pickup || 'Điểm đón mặc định'} → {summary.dropoff || 'Điểm trả mặc định'}</p>}
        <p>{summary.payment_method === 'cash' ? 'Tiền mặt trên xe' : 'Thanh toán qua PayOS'}</p>
        <p>Tổng cộng <strong className="text-[#ad3515]">{currency.format(map.price * selected.length)}</strong></p>
        <div className="flex flex-wrap gap-2">
          <button type="button" className={secondary} disabled={sending} onClick={() => { setSummary(null); setError(''); }}>Chỉnh sửa</button>
          <button type="button" className={primary} disabled={sending} onClick={confirm}>{sending ? 'Đang đặt vé…' : 'Xác nhận đặt vé'}</button>
        </div>
      </div>}
      {error && <p role="alert" className="text-sm text-red-700">{error}</p>}
    </section>
  );
}

export default function Chatbot() {
  const location = useLocation();
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState([initialMessage]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [panel, setPanel] = useState(null);
  const [pendingCancel, setPendingCancel] = useState(null);
  const [places, setPlaces] = useState([]);
  const [placesError, setPlacesError] = useState(false);
  const [usesGemini, setUsesGemini] = useState(false);
  const inFlight = useRef(false);
  const log = useRef(null);
  const toggle = useRef(null);

  useEffect(() => {
    if (!open) return;
    const controller = new AbortController();
    fetch('/api/provinces', { signal: controller.signal })
      .then(response => {
        if (!response.ok) throw new Error();
        return response.json();
      })
      .then(data => { setPlaces(Array.isArray(data) ? data : []); setPlacesError(false); })
      .catch(() => { if (!controller.signal.aborted) setPlacesError(true); });
    fetch('/api/ai/chatbot', { signal: controller.signal })
      .then(response => response.ok ? response.json() : null)
      .then(data => { if (data) setUsesGemini(data.gemini_enabled === true); })
      .catch(() => {});

    return () => controller.abort();
  }, [open]);

  useEffect(() => {
    if (open && log.current) log.current.scrollTop = log.current.scrollHeight;
  }, [messages, panel, busy, pendingCancel, open]);

  if (location.pathname.startsWith('/admin') || location.pathname.startsWith('/driver')) return null;

  async function send(payload, userText) {
    if (inFlight.current) return;
    inFlight.current = true;
    if (userText) setMessages(current => [...current, { response: userText, user: true }]);
    setBusy(true);
    try {
      const response = await fetch('/api/ai/chatbot', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await response.json();
      if (payload.action === 'reset' && response.ok) {
        setMessages([initialMessage]);
        setPanel(null);
        setPendingCancel(null);
        setInput('');
        return;
      }
      setMessages(current => [...current, { ...data, response: data.response || 'Bạn thử lại nhé.' }]);
      if (response.ok) {
        setPanel(data.checkout ? { type: 'checkout', checkout: data.checkout } : data.panel ? { type: data.panel, ...data } : null);
        setPendingCancel(null);
      }
    } catch {
      setMessages(current => [...current, { response: 'Không kết nối được với máy chủ. Bạn thử lại nhé.' }]);
    } finally {
      setBusy(false);
      inFlight.current = false;
    }
  }

  function close() {
    setOpen(false);
    toggle.current?.focus();
  }

  function complete(data) {
    setPanel(null);
    setMessages(current => [...current, data]);
  }

  return (
    <div className="fixed bottom-4 right-4 z-[1100] sm:bottom-6 sm:right-6">
      {open && <section id="hutech-assistant" aria-label="Trợ lý HUTECH BUS"
        onKeyDown={event => { if (event.key === 'Escape') close(); }}
        className="absolute bottom-[4.25rem] right-0 flex h-[min(650px,calc(100dvh-6rem))] w-[min(430px,calc(100vw-2rem))] flex-col overflow-hidden rounded-3xl border border-slate-200 bg-[#f7f8fa] shadow-2xl">
        <header className="flex shrink-0 items-center gap-3 bg-[#18243a] px-4 py-3.5 text-white">
          <span className="grid size-10 place-items-center rounded-xl bg-[#d44519]"><Bus size={22} /></span>
          <h2 className="flex-1 text-base font-bold">Trợ lý HUTECH BUS</h2>
          <button type="button" title="Cuộc trò chuyện mới" aria-label="Cuộc trò chuyện mới" disabled={busy || panel?.type === 'checkout'} className="rounded-lg p-2 hover:bg-white/15 disabled:opacity-50" onClick={() => send({ action: 'reset' })}><RotateCcw size={17} /></button>
          <button type="button" aria-label="Đóng trợ lý" className="rounded-lg p-2 hover:bg-white/15" onClick={close}><X size={19} /></button>
        </header>
        <div ref={log} className="min-h-0 flex-1 overflow-y-auto overscroll-contain p-3.5 sm:p-4">
          <div role="log" aria-live="polite" className="grid gap-3">
            {messages.map((message, index) => <div key={index} className="grid gap-2">
              <p className={(message.user ? 'ml-auto bg-[#d44519] text-white' : 'mr-auto border border-slate-200 bg-white text-slate-800') + ' max-w-[92%] whitespace-pre-wrap break-words rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed'}>{message.response}</p>
              {message.criteria?.from && message.criteria?.to && <p className="text-xs font-semibold text-slate-600">
                {[message.criteria.from + ' → ' + message.criteria.to, message.criteria.date?.split('-').reverse().join('/'), message.criteria.pax && message.criteria.pax + ' vé', message.criteria.time].filter(Boolean).join(' · ')}
              </p>}
              {message.trips?.map(trip => <TripCard key={trip.trip_id} trip={trip} busy={busy || panel?.type === 'checkout'} onSelect={() => send({ action: 'select_trip', trip_id: trip.trip_id }, 'Chọn chuyến ' + trip.time_text)} />)}
              {message.tickets?.map(ticket => <TicketCard key={ticket.code} ticket={ticket} busy={busy || panel?.type === 'checkout'} onCancel={() => { setPanel(null); setPendingCancel(ticket); }} />)}
              {message.links?.length > 0 && <div className="flex flex-wrap gap-2">
                {message.links.map(link => <Link key={link.href} to={link.href} onClick={close} className={secondary + ' inline-flex items-center gap-1'}>{link.label}<ChevronRight size={15} /></Link>)}
              </div>}
              {message.clear_filters && <button type="button" className={secondary + ' justify-self-start'} disabled={busy || panel?.type === 'checkout'} onClick={() => send({ action: 'clear_filters' })}>Bỏ lọc giờ và loại xe</button>}
              {message.codes?.map(code => <button key={code} type="button"
                disabled={busy || panel?.type === 'checkout'} className="rounded-xl bg-emerald-50 px-3 py-2 text-left text-sm font-semibold text-emerald-900 hover:bg-emerald-100 disabled:opacity-50"
                onClick={() => { setPendingCancel(null); setPanel({ type: 'lookup', code }); }}>Tra vé {code}</button>)}
              {message.paymentUrl && <a href={message.paymentUrl} className={primary + ' justify-self-start'}>Mở cổng thanh toán</a>}
            </div>)}
            {busy && <p role="status" className="flex items-center gap-1.5 text-xs text-slate-600"><LoaderCircle size={14} className="animate-spin" />Đang xử lý…</p>}
          </div>
          {panel && <div className="mt-3">
            {panel.type === 'search' && <SearchForm key={messages.length} criteria={panel.criteria} places={places} busy={busy} send={send} />}
            {panel.type === 'search' && placesError && <p className="mt-2 text-xs text-red-700">Chưa tải được địa điểm. Bạn đóng rồi mở lại trợ lý để thử lại.</p>}
            {panel.type === 'lookup' && <LookupForm key={panel.code} code={panel.code} busy={busy} send={send} />}
            {panel.type === 'checkout' && <BookingForm key={panel.checkout.trip.trip_id} checkout={panel.checkout} onDone={complete} onBack={() => setPanel(null)} />}
          </div>}
          {pendingCancel && <div className="mt-3 grid gap-2 rounded-2xl border border-orange-200 bg-white p-3.5">
            <p className="text-sm text-slate-800">Hủy vé <strong>{pendingCancel.code}</strong> · ghế {pendingCancel.seat}?</p>
            <div className="flex flex-wrap gap-2">
              <button type="button" className={secondary} disabled={busy} onClick={() => setPendingCancel(null)}>Giữ vé</button>
              <button type="button" className={primary} disabled={busy} onClick={() => send({ action: 'cancel_ticket', code: pendingCancel.code, confirmed: true })}>Xác nhận hủy vé</button>
            </div>
          </div>}
        </div>
        <div className="shrink-0 border-t border-slate-200 bg-white px-3.5 pb-3 pt-2.5 sm:px-4">
          <div className="mb-2 flex gap-1.5 overflow-x-auto whitespace-nowrap pb-1">
            <button type="button" className={secondary} disabled={busy || panel?.type === 'checkout'} onClick={() => { setPendingCancel(null); setPanel({ type: 'search' }); }}>Tìm chuyến</button>
            <button type="button" className={secondary} disabled={busy || panel?.type === 'checkout'} onClick={() => { setPendingCancel(null); setPanel({ type: 'lookup' }); }}>Tra vé</button>
            <button type="button" className={secondary} disabled={busy || panel?.type === 'checkout'} onClick={() => send({ action: 'tickets' }, 'Vé của tôi')}>Vé của tôi</button>
            <Link className={secondary + ' inline-flex items-center gap-1'} to="/thong-tin/giai-quyet-khieu-nai" onClick={close}><CircleHelp size={15} />Hỗ trợ</Link>
          </div>
          <form className="flex items-center gap-2" onSubmit={event => {
            event.preventDefault();
            const message = input.trim();
            if (!message || busy || panel?.type === 'checkout') return;
            setInput('');
            send({ message }, message);
          }}>
            <input className={field + ' flex-1'} value={input} aria-label="Tin nhắn cho trợ lý" maxLength={500}
              disabled={panel?.type === 'checkout'} placeholder="VD: TP.HCM đi Cư Jút mai, 2 vé"
              onChange={event => setInput(event.target.value)} />
            <button className={primary + ' grid size-10 place-items-center !p-0'} aria-label="Gửi tin nhắn" disabled={busy || !input.trim() || panel?.type === 'checkout'}><ArrowUp size={19} /></button>
          </form>
          {usesGemini && <p className="mt-1.5 text-xs text-slate-500">
            Câu tìm chuyến có thể được xử lý bằng Google Gemini. Nhập số điện thoại trong biểu mẫu tra vé hoặc đặt vé.
          </p>}
        </div>
      </section>}
      <button ref={toggle} type="button" aria-expanded={open} aria-controls={open ? 'hutech-assistant' : undefined}
        onClick={() => open ? close() : setOpen(true)}
        className="flex h-12 items-center gap-2 rounded-full bg-[#d44519] px-4 text-sm font-bold text-white shadow-lg transition hover:bg-[#ad3515]"
        aria-label={open ? 'Đóng trợ lý HUTECH BUS' : 'Mở trợ lý HUTECH BUS'}>
        {open ? <X size={19} /> : <MessageSquare size={19} />}<span>Trợ lý Hutech</span>
      </button>
    </div>
  );
}
