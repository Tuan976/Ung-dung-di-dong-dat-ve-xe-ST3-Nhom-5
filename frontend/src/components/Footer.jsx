import React from 'react';
import { Link } from 'react-router-dom';

const Footer = () => {
  return (
    <footer style={{ background: '#1e293b', color: '#f8fafc', padding: '60px 24px 40px', marginTop: 'auto' }}>
      <div style={{ maxWidth: 1200, margin: '0 auto', display: 'flex', flexWrap: 'wrap', gap: 40, justifyContent: 'space-between' }}>
        
        {/* Brand & Info */}
        <div style={{ flex: '1 1 300px' }}>
          <h2 style={{ fontSize: 24, fontWeight: 900, fontStyle: 'italic', color: '#EF5222', marginBottom: 16 }}>
            HUTECH BUS
          </h2>
          <p style={{ color: '#94a3b8', fontSize: 13, lineHeight: 1.6, marginBottom: 24 }}>
            Hệ thống đặt vé xe khách trực tuyến hàng đầu, mang đến trải nghiệm di chuyển an toàn, tiện lợi và đẳng cấp cho mọi hành khách trên khắp mọi nẻo đường.
          </p>
          <div style={{ display: 'flex', gap: 16 }}>
            <div style={{ width: 40, height: 40, borderRadius: '50%', background: '#334155', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', fontWeight: 900, fontSize: 14 }}>FB</div>
            <div style={{ width: 40, height: 40, borderRadius: '50%', background: '#334155', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', fontWeight: 900, fontSize: 14 }}>IG</div>
            <div style={{ width: 40, height: 40, borderRadius: '50%', background: '#334155', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', fontWeight: 900, fontSize: 14 }}>YT</div>
          </div>
        </div>

        {/* Links */}
        <div style={{ flex: '1 1 200px' }}>
          <h3 style={{ fontSize: 14, fontWeight: 900, textTransform: 'uppercase', letterSpacing: 2, marginBottom: 20, color: '#fff' }}>Chính sách</h3>
          <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 12 }}>
            <li><Link to="/thong-tin/quy-che-hoat-dong" style={{ color: '#94a3b8', textDecoration: 'none', fontSize: 13, fontWeight: 600 }}>Quy chế hoạt động</Link></li>
            <li><Link to="/thong-tin/chinh-sach-bao-mat" style={{ color: '#94a3b8', textDecoration: 'none', fontSize: 13, fontWeight: 600 }}>Chính sách bảo mật thông tin</Link></li>
            <li><Link to="/thong-tin/chinh-sach-thanh-toan" style={{ color: '#94a3b8', textDecoration: 'none', fontSize: 13, fontWeight: 600 }}>Chính sách thanh toán</Link></li>
            <li><Link to="/thong-tin/giai-quyet-khieu-nai" style={{ color: '#94a3b8', textDecoration: 'none', fontSize: 13, fontWeight: 600 }}>Giải quyết khiếu nại</Link></li>
          </ul>
        </div>

        {/* Support */}
        <div style={{ flex: '1 1 200px' }}>
          <h3 style={{ fontSize: 14, fontWeight: 900, textTransform: 'uppercase', letterSpacing: 2, marginBottom: 20, color: '#fff' }}>Hỗ trợ</h3>
          <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 12 }}>
            <li><Link to="/thong-tin/huong-dan-thanh-toan" style={{ color: '#94a3b8', textDecoration: 'none', fontSize: 13, fontWeight: 600 }}>Hướng dẫn thanh toán</Link></li>
            <li><Link to="/thong-tin/faq" style={{ color: '#94a3b8', textDecoration: 'none', fontSize: 13, fontWeight: 600 }}>Câu hỏi thường gặp (FAQ)</Link></li>
            <li><span style={{ color: '#94a3b8', fontSize: 13, fontWeight: 600 }}>Hotline: 1900 1234</span></li>
            <li><span style={{ color: '#94a3b8', fontSize: 13, fontWeight: 600 }}>Email: hotro@hutechbus.vn</span></li>
          </ul>
        </div>
      </div>

      <div style={{ maxWidth: 1200, margin: '40px auto 0', paddingTop: 24, borderTop: '1px solid #334155', textAlign: 'center' }}>
        <p style={{ color: '#64748b', fontSize: 12, fontWeight: 600 }}>
          © 2026 Hutech Bus. Bản quyền thuộc về Công ty CP Vận tải Hutech.
        </p>
      </div>
    </footer>
  );
};

export default Footer;
