import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: const Text(
          'Điều khoản sử dụng',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '1. Chấp nhận điều khoản',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Bằng việc tải xuống, cài đặt hoặc sử dụng ứng dụng này, bạn đồng ý chịu sự ràng buộc của các Điều khoản Sử dụng này. Nếu bạn không đồng ý với bất kỳ phần nào của điều khoản, vui lòng không sử dụng ứng dụng.',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            
            Text(
              '2. Dịch vụ đặt vé',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Chúng tôi cung cấp nền tảng để bạn tìm kiếm, so sánh và đặt vé xe khách từ các đối tác nhà xe. Chúng tôi không phải là nhà cung cấp dịch vụ vận tải và không chịu trách nhiệm trực tiếp về chất lượng xe, thái độ phục vụ của tài xế hay thời gian khởi hành thực tế.',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),

            Text(
              '3. Thanh toán và hoàn hủy',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Giao dịch thanh toán được thực hiện qua các cổng thanh toán an toàn. Việc hủy vé và hoàn tiền sẽ tuân theo chính sách cụ thể của từng nhà xe. Vui lòng đọc kỹ chính sách hủy vé trước khi tiến hành thanh toán.',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),

            Text(
              '4. Bảo mật thông tin',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Chúng tôi cam kết bảo vệ thông tin cá nhân của bạn theo Chính sách Bảo mật. Thông tin của bạn chỉ được chia sẻ với nhà xe để phục vụ cho mục đích xác nhận chuyến đi.',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
