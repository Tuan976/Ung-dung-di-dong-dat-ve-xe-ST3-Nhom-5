import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../models/trip.dart';
import '../../core/services/notification_service.dart';

class PaymentScreen extends StatefulWidget {
  final Booking booking;
  final Trip trip;

  const PaymentScreen({super.key, required this.booking, required this.trip});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Map<String, dynamic>? _paymentData;
  bool _isCreatingPayment = true;
  bool _isPaid = false;
  bool _isChecking = false;
  String? _error;
  Timer? _pollingTimer;
  int _countdown = 900; // 15 minutes
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _createPaymentLink();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPaymentLink() async {
    setState(() { _isCreatingPayment = true; _error = null; });
    try {
      final data = await context.read<BookingService>().createPayment(widget.booking.id);
      if (mounted) {
        setState(() { _paymentData = data; _isCreatingPayment = false; });
        _startPolling();
        _startCountdown();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isCreatingPayment = false; });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isPaid) return;
      await _checkPaymentStatus(silent: true);
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_countdown <= 0) {
        _countdownTimer?.cancel();
        _pollingTimer?.cancel();
        return;
      }
      setState(() => _countdown--);
    });
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (!silent) setState(() => _isChecking = true);
    try {
      final status = await context.read<BookingService>().getPaymentStatus(widget.booking.id);
      if (status['is_paid'] == true && mounted) {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        setState(() => _isPaid = true);
        await NotificationService().showPaymentSuccess(widget.booking.ticketCode);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) context.pushReplacement('/booking_confirmation', extra: {'booking': widget.booking, 'trip': widget.trip});
      } else if (!silent && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Thanh toán thất bại', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Chưa nhận được thanh toán hoặc giao dịch đã bị huỷ.\n\nVui lòng thử lại hoặc chọn "Huỷ vé" nếu bạn không muốn tiếp tục.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ vé', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
              ),
            ],
          )
        );
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => _isChecking = false);
  }

  Future<void> _openPaymentUrl() async {
    final url = _paymentData?['checkout_url'];
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String get _countdownDisplay {
    final m = (_countdown ~/ 60).toString().padLeft(2, '0');
    final s = (_countdown % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isExpired => _countdown <= 0;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final amount = _paymentData?['amount'] ?? widget.booking.ticketPrice ?? widget.trip.price;
    final isMock = _paymentData?['is_mock'] == true;
    final checkoutUrl = _paymentData?['checkout_url'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isCreatingPayment
            ? _buildLoading()
            : _isPaid
                ? _buildPaidSuccess(fmt, amount)
                : _error != null
                    ? _buildError()
                    : _buildPaymentContent(fmt, amount, isMock, checkoutUrl),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0B192C)),
          SizedBox(height: 16),
          Text('Đang tạo liên kết thanh toán...',
              style: TextStyle(color: Color(0xFF475569), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPaidSuccess(NumberFormat fmt, num amount) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(color: Color(0xFF0B192C), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('Thanh toán thành công!',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(fmt.format(amount),
              style: const TextStyle(color: Color(0xFF00639B), fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFF0B192C)),
          const SizedBox(height: 12),
          const Text('Đang chuyển đến vé của bạn...',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(36)),
            child: const Icon(Icons.error_outline, size: 36, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 16),
          const Text('Không thể tạo liên kết thanh toán',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createPaymentLink,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B192C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/tickets'),
            child: const Text('Xem vé của tôi', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentContent(NumberFormat fmt, num amount, bool isMock, String? checkoutUrl) {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF0F172A)),
              ),
              const Expanded(
                child: Text('Thanh toán vé xe',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 28),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Mock warning
                if (isMock)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, size: 18, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Môi trường phát triển — PayOS chưa được cấu hình.',
                              style: TextStyle(color: Color(0xFFD97706), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                // Amount card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0x0A0F172A), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      const Text('Số tiền cần thanh toán',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(fmt.format(amount),
                          style: const TextStyle(color: Color(0xFF0B192C), fontSize: 32, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),

                      // Ticket code
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.confirmation_number, size: 14, color: Color(0xFF475569)),
                            const SizedBox(width: 6),
                            Text(widget.booking.ticketCode,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: widget.booking.ticketCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã sao chép mã vé'), duration: Duration(seconds: 1)),
                                );
                              },
                              child: const Icon(Icons.copy, size: 14, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Countdown timer
                      if (!_isExpired) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            Text('Còn $_countdownDisplay để thanh toán',
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _countdown / 900,
                            backgroundColor: const Color(0xFFFEE2E2),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFDC2626)),
                            minHeight: 6,
                          ),
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Phiên thanh toán đã hết hạn',
                              style: TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // QR / PayOS card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0x0A0F172A), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B192C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PayOS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          const Text('Quét mã QR để thanh toán',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // QR Placeholder / actual QR
                      Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                        ),
                        child: isMock
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_2, size: 100, color: Color(0xFF0B192C)),
                                  const SizedBox(height: 4),
                                  Text(widget.booking.ticketCode,
                                      style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Color(0xFF94A3B8))),
                                ],
                              )
                            : checkoutUrl != null
                                ? QrImageView(
                                    data: checkoutUrl,
                                    version: QrVersions.auto,
                                    size: 180.0,
                                    padding: const EdgeInsets.all(12),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_2, size: 100, color: Color(0xFF0B192C)),
                                      Text('Lỗi tạo mã QR', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                    ],
                                  ),
                      ),

                      const SizedBox(height: 16),
                      const Text('Hỗ trợ: MoMo, VNPay, VietQR, Internet Banking',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info note
                const Text(
                  '* Trạng thái vé sẽ tự động cập nhật sau khi thanh toán thành công.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: const Color(0x0A0F172A), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Column(
            children: [
              // Open PayOS button
              if (checkoutUrl != null && !isMock && !_isExpired)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openPaymentUrl,
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('Mở trang thanh toán PayOS',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B192C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                  ),
                ),

              if (checkoutUrl != null && !isMock && !_isExpired) const SizedBox(height: 10),

              // Check status button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: (_isChecking || _isExpired) ? null : () => _checkPaymentStatus(),
                  icon: _isChecking
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B192C)))
                      : const Icon(Icons.refresh, size: 18, color: Color(0xFF0B192C)),
                  label: Text(
                    _isExpired ? 'Phiên hết hạn' : 'Kiểm tra trạng thái thanh toán',
                    style: const TextStyle(color: Color(0xFF0B192C), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0B192C)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.go('/tickets'),
                child: const Text('Xem tất cả vé của tôi',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
