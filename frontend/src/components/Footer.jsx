import React from 'react';
import { Link } from 'react-router-dom';
import { Bus, Phone, Mail, ShieldCheck } from 'lucide-react';

const Footer = () => {
  return (
    <footer className="mt-auto border-t border-[#E7EAF0] bg-white text-[#202938]">
      <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 gap-8 md:grid-cols-4">
          {/* Brand Info */}
          <div className="md:col-span-2">
            <Link to="/" className="inline-flex items-center gap-2.5 mb-4">
              <div className="grid size-9 place-items-center rounded-xl bg-[#FF6B00] text-white">
                <Bus size={20} />
              </div>
              <span className="text-xl font-black tracking-tight text-[#202938]">
                TRIP<span className="text-[#FF6B00]">LY</span>
              </span>
            </Link>
            <p className="max-w-md text-sm leading-relaxed text-[#778196] mb-5">
              Nền tảng đặt vé xe khách thông minh hàng đầu Việt Nam. Kết nối hàng trăm nhà xe uy tín,
              chọn ghế trực quan, thanh toán an toàn và hỗ trợ hành trình 24/7.
            </p>
            <div className="flex flex-wrap items-center gap-4 text-xs font-semibold text-[#778196]">
              <span className="inline-flex items-center gap-1.5 rounded-lg bg-[#F7F8FA] border border-[#E7EAF0] px-3 py-1.5">
                <ShieldCheck size={15} className="text-[#16A36A]" />
                100% Vé điện tử xác nhận tức thì
              </span>
            </div>
          </div>

          {/* Policies */}
          <div>
            <h3 className="text-xs font-extrabold uppercase tracking-wider text-[#202938] mb-4">
              Quy định & Chính sách
            </h3>
            <ul className="space-y-2.5 text-sm font-medium text-[#778196]">
              <li>
                <Link to="/thong-tin/quy-che-hoat-dong" className="hover:text-[#FF6B00] transition-colors">
                  Quy chế hoạt động
                </Link>
              </li>
              <li>
                <Link to="/thong-tin/chinh-sach-bao-mat" className="hover:text-[#FF6B00] transition-colors">
                  Chính sách bảo mật thông tin
                </Link>
              </li>
              <li>
                <Link to="/thong-tin/chinh-sach-thanh-toan" className="hover:text-[#FF6B00] transition-colors">
                  Chính sách thanh toán & hoàn vé
                </Link>
              </li>
              <li>
                <Link to="/thong-tin/giai-quyet-khieu-nai" className="hover:text-[#FF6B00] transition-colors">
                  Giải quyết khiếu nại
                </Link>
              </li>
            </ul>
          </div>

          {/* Support */}
          <div>
            <h3 className="text-xs font-extrabold uppercase tracking-wider text-[#202938] mb-4">
              Trung tâm Hỗ trợ
            </h3>
            <ul className="space-y-2.5 text-sm font-medium text-[#778196]">
              <li>
                <Link to="/thong-tin/huong-dan-thanh-toan" className="hover:text-[#FF6B00] transition-colors">
                  Hướng dẫn đặt vé & thanh toán
                </Link>
              </li>
              <li>
                <Link to="/thong-tin/faq" className="hover:text-[#FF6B00] transition-colors">
                  Câu hỏi thường gặp (FAQ)
                </Link>
              </li>
              <li className="flex items-center gap-2 pt-1 text-[#202938] font-bold">
                <Phone size={15} className="text-[#FF6B00]" />
                Hotline: 1900 1234 (24/7)
              </li>
              <li className="flex items-center gap-2 text-[#778196]">
                <Mail size={15} className="text-[#FF6B00]" />
                hotro@triply.vn
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-10 border-t border-[#E7EAF0] pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs font-medium text-[#778196]">
          <p>© 2026 TRIPLY Mobility Platform. Bảo lưu mọi quyền.</p>
          <p>Thiết kế theo tiêu chuẩn Modern Mobility — Cam & Trắng.</p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
