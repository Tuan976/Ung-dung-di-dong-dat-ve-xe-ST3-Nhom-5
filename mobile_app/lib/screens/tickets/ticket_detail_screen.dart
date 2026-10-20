import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../services/smart_boarding_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final int bookingId;
  const TicketDetailScreen({super.key, required this.bookingId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  Booking? _booking;
  bool _isLoading = true;
  String? _error;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final booking = await context.read<BookingService>().getBookingById(widget.bookingId);
      if (mounted) setState(() { _booking = booking; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy vé?'),
        content: const Text('Bạn có chắc chắn muốn hủy vé này không? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy vé', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final success = await context.read<BookingService>().cancelBooking(widget.bookingId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hủy vé thành công'), backgroundColor: Colors.green),
        );
        await _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Chi tiết vé xe', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: _buildBody(currencyFormatter),
    );
  }

  Widget _buildBody(NumberFormat currencyFormatter) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _loadDetail, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ],
        ),
      );
    }

    final booking = _booking!;
    final statusColor = booking.isCancelled ? const Color(0xFFEF4444) : booking.isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusLabel = booking.isCancelled ? 'Đã hủy' : booking.isPaid ? 'Đã xác nhận' : 'Chờ thanh toán';
    
    // Formatting date
    String departureFormatted = booking.departureTime;
    try {
      final dt = DateTime.parse(booking.departureTime);
      departureFormatted = DateFormat('HH:mm • dd/MM/yyyy').format(dt);
    } catch (_) {}

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main dark ticket card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ShapeDecoration(
              color: const Color(0xFF0B192C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('MÃ ĐẶT VÉ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w400)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: ShapeDecoration(
                        color: statusColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      booking.ticketCode,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    if (booking.trip != null)
                      Text(
                        '${_getShortCity(booking.trip!.startPoint)} → ${_getShortCity(booking.trip!.endPoint)}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2, size: 120, color: Colors.black87),
                      const SizedBox(height: 8),
                      const Text(
                        'Quét mã khi lên xe để soát vé nhanh chóng',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trip info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thông tin chuyến đi', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _buildInfoRow('Nhà xe', booking.trip?.companyName ?? 'N/A', isBold: true),
                const SizedBox(height: 12),
                _buildInfoRow('Loại xe', 'Limousine 34 chỗ'),
                const SizedBox(height: 12),
                _buildInfoRow('Khởi hành', departureFormatted, isBold: true),
                const SizedBox(height: 12),
                _buildInfoRow('Vị trí ghế', 'Ghế ${booking.seatNumber}', valueColor: const Color(0xFF00639B), isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Passenger info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hành khách & Điểm đón/trả', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _buildInfoRow('Hành khách', booking.passengerName, isBold: true),
                const SizedBox(height: 12),
                _buildInfoRow('Điểm đón', booking.trip?.startPoint ?? 'N/A'),
                const SizedBox(height: 12),
                _buildInfoRow('Điểm trả', booking.trip?.endPoint ?? 'N/A'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng thanh toán', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(currencyFormatter.format(booking.ticketPrice), style: const TextStyle(color: Color(0xFF00639B), fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Smart Boarding Card (Redmi Watch 5 Active / Smart Watch Sync)
          _buildSmartBoardingCard(booking),
          const SizedBox(height: 20),

          // Actions
          if (!booking.isCancelled)
            InkWell(
              onTap: _isCancelling ? null : _cancelBooking,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 48,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1.50, color: Color(0xFFEF4444)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Center(
                  child: _isCancelling
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)))
                      : const Text('Hủy vé', style: TextStyle(color: Color(0xFFEF4444), fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: InkWell(
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Text('Liên hệ hỗ trợ', style: TextStyle(color: Color(0xFF00639B), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  String _getShortCity(String location) {
    if (location.toLowerCase().contains('hà nội')) return 'HN';
    if (location.toLowerCase().contains('hải phòng')) return 'HP';
    if (location.toLowerCase().contains('hồ chí minh')) return 'HCM';
    if (location.toLowerCase().contains('đà nẵng')) return 'ĐN';
    return location.split(' ').last;
  }

  Widget _buildSmartBoardingCard(Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.watch_outlined, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Smart Boarding',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                          ),
                          child: const Text(
                            'Sẵn sàng',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Đồng bộ Redmi Watch 5 Active (qua Mi Fitness)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Nhấn nút dưới đây để kích hoạt rung thử nghiệm trên đồng hồ:',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWatchActionButton(
                icon: Icons.check_circle_outline,
                label: '1. Vé xác nhận',
                color: const Color(0xFF10B981),
                onTap: () async {
                  await SmartBoardingService.instance.testScenario(scenario: 1, booking: booking);
                  _showWatchToast('Đã gửi thông báo Vé xác nhận tới Redmi Watch 5 Active!');
                },
              ),
              _buildWatchActionButton(
                icon: Icons.alarm,
                label: '2. Nhắc 30 phút',
                color: const Color(0xFFF59E0B),
                onTap: () async {
                  await SmartBoardingService.instance.testScenario(scenario: 2, booking: booking);
                  _showWatchToast('Đã gửi cảnh báo Sắp đến giờ xe chạy tới đồng hồ!');
                },
              ),
              _buildWatchActionButton(
                icon: Icons.directions_bus,
                label: '3. Xe đến đón (5p)',
                color: const Color(0xFF38BDF8),
                onTap: () async {
                  await SmartBoardingService.instance.testScenario(scenario: 3, booking: booking);
                  _showWatchToast('Đã gửi cảnh báo Xe sắp đến đón tới đồng hồ!');
                },
              ),
              _buildWatchActionButton(
                icon: Icons.warning_amber_rounded,
                label: '4. Đổi xe / Điểm',
                color: const Color(0xFFEF4444),
                onTap: () async {
                  await SmartBoardingService.instance.testScenario(scenario: 4, booking: booking);
                  _showWatchToast('Đã gửi cảnh báo khẩn cấp Đổi xe tới đồng hồ!');
                },
              ),
              _buildWatchActionButton(
                icon: Icons.vibration,
                label: '⚡ Test rung (Sau 3s - Khóa màn hình)',
                color: const Color(0xFF8B5CF6),
                onTap: () async {
                  _showWatchToast('Đang đếm ngược 3s... Hãy BẤM KHÓA MÀN HÌNH ngay để đồng hồ rung!');
                  await SmartBoardingService.instance.testScenarioWithDelay(
                    scenario: 1,
                    booking: booking,
                    delaySeconds: 3,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lưu ý Apple iOS: Khi bạn đang nhìn vào màn hình iPhone, iOS sẽ không làm rung đồng hồ. Hãy bấm nút hẹn giờ 3s và KHÓA MÀN HÌNH để đồng hồ rung mạnh trên cổ tay!',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showWatchToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.watch, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5))),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
