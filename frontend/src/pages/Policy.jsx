import React from 'react';
import { useParams } from 'react-router-dom';

const policyData = {
  'quy-che-hoat-dong': {
    title: 'Quy chế hoạt động',
    content: (
      <>
        <p>Chào mừng bạn đến với nền tảng đặt vé xe khách thông minh Triply. Dưới đây là các quy chế hoạt động của chúng tôi:</p>
        <h3>1. Nguyên tắc chung</h3>
        <p>Nền tảng đặt vé trực tuyến Triply cung cấp dịch vụ tìm kiếm và đặt vé xe khách chất lượng cao. Khách hàng tham gia giao dịch trên Triply là các cá nhân, tổ chức có nhu cầu mua vé và sử dụng dịch vụ vận tải hợp pháp.</p>
        <h3>2. Quy trình giao dịch</h3>
        <p>Khách hàng có thể tìm kiếm chuyến đi, chọn vị trí ghế ngồi trực quan và tiến hành thanh toán trực tuyến hoặc giữ chỗ thanh toán tiền mặt. Vé điện tử kèm mã QR sẽ được xác nhận ngay sau khi đặt vé thành công.</p>
        <h3>3. Trách nhiệm của các bên</h3>
        <p>Triply cam kết cung cấp thông tin chuyến đi minh bạch, bảo mật dữ liệu khách hàng và hỗ trợ giải quyết các vấn đề phát sinh 24/7. Khách hàng cần cung cấp thông tin liên hệ chính xác khi đặt vé để nhận mã vé điện tử.</p>
      </>
    ),
  },
  'chinh-sach-bao-mat': {
    title: 'Chính sách bảo mật thông tin',
    content: (
      <>
        <p>Triply cam kết bảo vệ thông tin cá nhân của bạn. Chính sách bảo mật này giải thích cách chúng tôi thu thập, sử dụng và bảo vệ dữ liệu của bạn.</p>
        <h3>1. Mục đích thu thập</h3>
        <p>Chúng tôi thu thập họ tên, số điện thoại và email nhằm xuất mã vé điện tử, thông báo lịch trình khởi hành và hỗ trợ đón trả khách.</p>
        <h3>2. Phạm vi sử dụng</h3>
        <p>Thông tin của bạn chỉ được sử dụng nội bộ và chia sẻ với nhà xe trực tiếp vận hành chuyến đi mà bạn đã đặt.</p>
        <h3>3. Cam kết bảo mật</h3>
        <p>Triply áp dụng các tiêu chuẩn mã hóa và an ninh dữ liệu để ngăn chặn truy cập trái phép. Chúng tôi tuyệt đối không bán hoặc chia sẻ thông tin khách hàng cho bên thứ ba.</p>
      </>
    ),
  },
  'chinh-sach-thanh-toan': {
    title: 'Chính sách thanh toán & hoàn vé',
    content: (
      <>
        <p>Triply hỗ trợ đa dạng phương thức thanh toán nhằm mang lại sự tiện lợi tối đa cho hành khách.</p>
        <h3>1. Phương thức thanh toán</h3>
        <p>Chúng tôi hỗ trợ thanh toán tiền mặt khi lên xe và thanh toán trực tuyến qua cổng PayOS QR (hỗ trợ VietQR, MoMo, ZaloPay và hơn 40 ngân hàng nội địa).</p>
        <h3>2. Quy định hoàn hủy</h3>
        <p>Hành khách có thể hủy vé trực tiếp trên ứng dụng hoặc qua Trợ lý Triply trước giờ khởi hành theo quy định của nhà xe.</p>
        <h3>3. Bảo mật giao dịch</h3>
        <p>Mọi giao dịch thanh toán đều được xác thực tự động theo thời gian thực, đảm bảo an toàn tuyệt đối cho khách hàng.</p>
      </>
    ),
  },
  'giai-quyet-khieu-nai': {
    title: 'Trung tâm Hỗ trợ & Giải quyết khiếu nại',
    content: (
      <>
        <p>Triply luôn lắng nghe và sẵn sàng giải quyết mọi thắc mắc, yêu cầu hỗ trợ của hành khách nhanh chóng và minh bạch.</p>
        <h3>1. Kênh tiếp nhận hỗ trợ 24/7</h3>
        <p>Khách hàng có thể nhắn tin trực tiếp với Trợ lý Triply ngay trên góc phải màn hình, gửi email về hotro@triply.vn hoặc gọi hotline 1900 1234.</p>
        <h3>2. Thời gian phản hồi</h3>
        <p>Yêu cầu tra cứu, đổi ghế hoặc hủy vé được xử lý tức thì. Các khiếu nại về chất lượng nhà xe được phản hồi trong vòng 24 giờ làm việc.</p>
        <h3>3. Nguyên tắc bảo vệ hành khách</h3>
        <p>Mọi phản ánh đều được Triply phối hợp cùng đối tác nhà xe xác minh trên tinh thần bảo vệ quyền lợi chính đáng của hành khách.</p>
      </>
    ),
  },
  'huong-dan-thanh-toan': {
    title: 'Hướng dẫn đặt vé & thanh toán',
    content: (
      <>
        <p>Đặt vé trên Triply chỉ gồm 4 bước đơn giản và minh bạch:</p>
        <h3>Bước 1: Tìm kiếm hành trình</h3>
        <p>Chọn Điểm đi, Điểm đến và Ngày khởi hành tại Trang chủ hoặc nhắn trực tiếp cho Trợ lý Triply.</p>
        <h3>Bước 2: Chọn chuyến & vị trí ghế</h3>
        <p>So sánh giờ khởi hành, loại xe, giá vé và chạm chọn ghế trống trên sơ đồ ghế từng tầng.</p>
        <h3>Bước 3: Nhập thông tin hành khách</h3>
        <p>Điền họ tên, số điện thoại liên hệ và điểm đón/trả mong muốn.</p>
        <h3>Bước 4: Xác nhận & nhận vé điện tử</h3>
        <p>Chọn thanh toán tiền mặt hoặc quét mã PayOS QR để nhận ngay mã vé điện tử HTxxxxxxxx.</p>
      </>
    ),
  },
  faq: {
    title: 'Câu hỏi thường gặp (FAQ)',
    content: (
      <>
        <h3>1. Tôi có thể hủy vé đã đặt không?</h3>
        <p>Có. Bạn có thể mở Trợ lý Triply hoặc mục Vé của tôi để hủy vé trước giờ xe khởi hành.</p>
        <h3>2. Tôi có cần in vé giấy không?</h3>
        <p>Không cần. Bạn chỉ cần lưu mã vé điện tử (VD: HT12345678) hoặc mã QR trên điện thoại để xuất trình khi lên xe.</p>
        <h3>3. Làm sao để đặt vé nhanh bằng Trợ lý Triply?</h3>
        <p>Bạn chỉ cần mở nút "Trợ lý Triply" ở góc dưới màn hình và gõ câu tự nhiên như: "TP.HCM đi Đà Lạt ngày mai, 2 vé", trợ lý sẽ tự động tìm chuyến và mở sơ đồ ghế cho bạn.</p>
      </>
    ),
  },
};

const Policy = () => {
  const { slug } = useParams();
  const policy = policyData[slug];

  if (!policy) {
    return (
      <div className="py-24 px-4 text-center min-h-[60vh] flex flex-col items-center justify-center">
        <h2 className="text-2xl font-extrabold text-[#202938] mb-2">Không tìm thấy nội dung</h2>
        <p className="text-sm text-[#778196]">Trang bạn đang tìm kiếm không tồn tại.</p>
      </div>
    );
  }

  return (
    <div className="bg-[#F7F8FA] py-12 px-4 flex-1 flex justify-center">
      <div className="max-w-3xl w-full bg-white rounded-2xl border border-[#E7EAF0] p-8 sm:p-10 card-shadow">
        <h1 className="text-2xl sm:text-3xl font-black text-[#202938] mb-8 pb-4 border-b border-[#E7EAF0]">
          {policy.title}
        </h1>
        <div className="policy-content text-[#778196] leading-relaxed text-sm sm:text-base">
          {policy.content}
        </div>
        <style
          dangerouslySetInnerHTML={{
            __html: `
          .policy-content h3 {
            color: #202938;
            font-size: 17px;
            font-weight: 800;
            margin-top: 24px;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
          }
          .policy-content h3::before {
            content: '';
            display: inline-block;
            width: 8px;
            height: 8px;
            background: #FF6B00;
            border-radius: 50%;
            margin-right: 10px;
          }
          .policy-content p {
            margin-bottom: 14px;
          }
        `,
          }}
        />
      </div>
    </div>
  );
};

export default Policy;
