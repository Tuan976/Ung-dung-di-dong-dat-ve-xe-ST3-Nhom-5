import React from 'react';
import { useParams } from 'react-router-dom';

const policyData = {
  'quy-che-hoat-dong': {
    title: 'Quy chế hoạt động',
    content: (
      <>
        <p>Chào mừng bạn đến với Hutech Bus. Dưới đây là các quy chế hoạt động của chúng tôi:</p>
        <h3>1. Nguyên tắc chung</h3>
        <p>Hệ thống đặt vé trực tuyến Hutech Bus cung cấp dịch vụ vé xe khách chất lượng cao. Khách hàng tham gia giao dịch trên Hutech Bus là các cá nhân, tổ chức có nhu cầu mua vé và sử dụng dịch vụ vận tải của chúng tôi.</p>
        <h3>2. Quy trình giao dịch</h3>
        <p>Khách hàng có thể tìm kiếm chuyến đi, chọn chỗ ngồi và tiến hành thanh toán trực tuyến qua các cổng thanh toán được hỗ trợ. Vé điện tử sẽ được gửi qua email sau khi thanh toán thành công.</p>
        <h3>3. Trách nhiệm của các bên</h3>
        <p>Hutech Bus cam kết cung cấp dịch vụ đúng như mô tả, bảo mật thông tin khách hàng và hỗ trợ giải quyết các vấn đề phát sinh. Khách hàng cần cung cấp thông tin chính xác khi đặt vé và tuân thủ các quy định của nhà xe.</p>
      </>
    )
  },
  'chinh-sach-bao-mat': {
    title: 'Chính sách bảo mật thông tin',
    content: (
      <>
        <p>Hutech Bus cam kết bảo vệ thông tin cá nhân của bạn. Chính sách bảo mật này giải thích cách chúng tôi thu thập, sử dụng và bảo vệ dữ liệu của bạn.</p>
        <h3>1. Mục đích thu thập</h3>
        <p>Chúng tôi thu thập thông tin để hỗ trợ quá trình đặt vé, thông báo lịch trình và cải thiện chất lượng dịch vụ.</p>
        <h3>2. Phạm vi sử dụng</h3>
        <p>Thông tin của bạn chỉ được sử dụng nội bộ và chia sẻ với các đối tác liên quan trực tiếp đến chuyến đi (như nhà xe, cổng thanh toán).</p>
        <h3>3. Cam kết bảo mật</h3>
        <p>Hutech Bus áp dụng các biện pháp kỹ thuật và an ninh để ngăn chặn truy cập trái phép. Chúng tôi không bán hoặc trao đổi thông tin khách hàng cho bên thứ ba vì mục đích thương mại.</p>
      </>
    )
  },
  'chinh-sach-thanh-toan': {
    title: 'Chính sách thanh toán',
    content: (
      <>
        <p>Hutech Bus hỗ trợ đa dạng phương thức thanh toán nhằm mang lại sự tiện lợi tối đa cho khách hàng.</p>
        <h3>1. Phương thức thanh toán</h3>
        <p>Chúng tôi chấp nhận thanh toán qua thẻ tín dụng, thẻ ghi nợ, chuyển khoản ngân hàng và các ví điện tử phổ biến như Momo, ZaloPay, PayOS.</p>
        <h3>2. Quy định hoàn trả</h3>
        <p>Trong trường hợp hủy vé hợp lệ theo quy định của nhà xe, số tiền hoàn lại sẽ được chuyển vào tài khoản của bạn trong vòng 3-5 ngày làm việc.</p>
        <h3>3. Bảo mật thanh toán</h3>
        <p>Mọi giao dịch thanh toán đều được mã hóa và xử lý qua các cổng thanh toán uy tín, đảm bảo an toàn tuyệt đối cho thông tin tài chính của bạn.</p>
      </>
    )
  },
  'giai-quyet-khieu-nai': {
    title: 'Giải quyết khiếu nại',
    content: (
      <>
        <p>Chúng tôi luôn lắng nghe và sẵn sàng giải quyết mọi thắc mắc, khiếu nại của khách hàng một cách nhanh chóng và công bằng.</p>
        <h3>1. Quy trình tiếp nhận</h3>
        <p>Khách hàng có thể gửi khiếu nại qua email hotro@hutechbus.vn hoặc gọi điện đến hotline 1900 1234. Chúng tôi sẽ ghi nhận và phản hồi trong vòng 24 giờ.</p>
        <h3>2. Thời gian xử lý</h3>
        <p>Tùy vào tính chất của khiếu nại, thời gian xử lý có thể kéo dài từ 1 đến 3 ngày làm việc. Chúng tôi sẽ cập nhật tiến độ thường xuyên cho khách hàng.</p>
        <h3>3. Nguyên tắc giải quyết</h3>
        <p>Mọi khiếu nại đều được giải quyết trên tinh thần thiện chí, tuân thủ các quy định của pháp luật và chính sách của công ty để đảm bảo quyền lợi tối đa cho khách hàng.</p>
      </>
    )
  },
  'huong-dan-thanh-toan': {
    title: 'Hướng dẫn thanh toán',
    content: (
      <>
        <p>Để hoàn tất quá trình đặt vé, vui lòng làm theo các bước thanh toán dưới đây:</p>
        <h3>Bước 1: Chọn chuyến đi và ghế ngồi</h3>
        <p>Sau khi chọn được chuyến đi và vị trí ghế ưng ý, hãy điền đầy đủ thông tin hành khách.</p>
        <h3>Bước 2: Chọn phương thức thanh toán</h3>
        <p>Tại trang thanh toán, bạn có thể chọn một trong các phương thức: Chuyển khoản ngân hàng (PayOS), Ví Momo, ZaloPay, hoặc thẻ tín dụng.</p>
        <h3>Bước 3: Xác nhận và thanh toán</h3>
        <p>Kiểm tra lại thông tin đơn hàng và tiến hành thanh toán. Khi giao dịch thành công, bạn sẽ nhận được vé điện tử qua email đã đăng ký.</p>
      </>
    )
  },
  'faq': {
    title: 'Câu hỏi thường gặp (FAQ)',
    content: (
      <>
        <h3>1. Tôi có thể đổi hoặc trả vé không?</h3>
        <p>Có, bạn có thể đổi hoặc trả vé tùy thuộc vào quy định của từng nhà xe. Vui lòng kiểm tra kỹ chính sách hoàn hủy khi đặt vé hoặc liên hệ tổng đài để được hỗ trợ.</p>
        <h3>2. Tôi có cần in vé điện tử không?</h3>
        <p>Không, bạn chỉ cần xuất trình vé điện tử trên điện thoại hoặc mã vé (booking code) cùng với giấy tờ tùy thân khi lên xe.</p>
        <h3>3. Làm sao để nhận biết xe đã đến đón?</h3>
        <p>Tài xế hoặc phụ xe sẽ liên hệ với bạn trước giờ khởi hành. Bạn cũng có thể theo dõi vị trí xe qua tính năng tra cứu vé trên website Hutech Bus.</p>
        <h3>4. Trẻ em có được miễn phí vé không?</h3>
        <p>Chính sách giá vé cho trẻ em phụ thuộc vào từng nhà xe, thông thường trẻ em dưới 3 tuổi hoặc dưới 100cm ngồi chung với người lớn sẽ được miễn phí.</p>
      </>
    )
  }
};

const Policy = () => {
  const { slug } = useParams();
  const policy = policyData[slug];

  if (!policy) {
    return (
      <div style={{ padding: '100px 20px', textAlign: 'center', minHeight: '60vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <h2 style={{ fontSize: '28px', color: '#1e293b', fontWeight: '700', marginBottom: '16px' }}>Không tìm thấy trang</h2>
        <p style={{ color: '#64748b', fontSize: '16px' }}>Trang bạn đang tìm kiếm không tồn tại hoặc đã bị xóa.</p>
      </div>
    );
  }

  return (
    <div style={{ background: '#f8fafc', padding: '60px 20px', flex: 1, display: 'flex', justifyContent: 'center' }}>
      <div style={{ maxWidth: '800px', width: '100%', background: '#fff', borderRadius: '16px', padding: '48px', boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.01)' }}>
        <h1 style={{ fontSize: '32px', fontWeight: '800', color: '#1e293b', marginBottom: '40px', textAlign: 'center', position: 'relative', paddingBottom: '20px' }}>
          {policy.title}
          <span style={{ position: 'absolute', bottom: 0, left: '50%', transform: 'translateX(-50%)', width: '80px', height: '4px', background: 'linear-gradient(90deg, #EF5222 0%, #F97316 100%)', borderRadius: '4px' }}></span>
        </h1>
        <div className="policy-content" style={{ color: '#475569', lineHeight: '1.8', fontSize: '16px' }}>
          {policy.content}
        </div>
        <style dangerouslySetInnerHTML={{__html: `
          .policy-content h3 {
            color: #1e293b;
            font-size: 20px;
            font-weight: 700;
            margin-top: 36px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
          }
          .policy-content h3::before {
            content: '';
            display: inline-block;
            width: 8px;
            height: 8px;
            background: #EF5222;
            border-radius: 50%;
            margin-right: 12px;
          }
          .policy-content p {
            margin-bottom: 16px;
            text-align: justify;
          }
        `}} />
      </div>
    </div>
  );
};

export default Policy;
