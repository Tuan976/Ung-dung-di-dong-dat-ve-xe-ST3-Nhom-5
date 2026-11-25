import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/shared_components.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _sections = [
    (
      title: '1. Chấp nhận điều khoản sử dụng',
      body:
          'Bằng việc tải xuống, truy cập hoặc sử dụng nền tảng đặt vé xe khách thông minh Triply, bạn đồng ý tuân thủ các Điều khoản sử dụng này. Nếu có bất kỳ điều khoản nào bạn chưa đồng ý, vui lòng ngừng sử dụng dịch vụ.',
    ),
    (
      title: '2. Dịch vụ đặt vé & vận chuyển',
      body:
          'Triply cung cấp nền tảng công nghệ giúp hành khách tìm kiếm hành trình, so sánh giá vé, chọn vị trí ghế trực quan và thanh toán vé xe khách từ mạng lưới đối tác nhà xe uy tín trên toàn quốc.',
    ),
    (
      title: '3. Thanh toán & chính sách hoàn hủy',
      body:
          'Mọi giao dịch trực tuyến hoặc giữ chỗ tiền mặt trên Triply đều được xác nhận tức thì bằng mã vé điện tử và QR Code. Quy định đổi hoặc hủy vé được áp dụng minh bạch theo chính sách của từng nhà xe đối tác.',
    ),
    (
      title: '4. Bảo mật dữ liệu khách hàng',
      body:
          'Triply cam kết bảo mật tuyệt đối thông tin cá nhân, số điện thoại và lịch trình di chuyển của bạn. Dữ liệu chỉ được cung cấp cho nhà xe phụ trách chuyến đi nhằm phục vụ việc đón trả và xác thực vé.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: const Text(
          'Điều khoản & Chính sách',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = _sections[index];
          return AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  section.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
