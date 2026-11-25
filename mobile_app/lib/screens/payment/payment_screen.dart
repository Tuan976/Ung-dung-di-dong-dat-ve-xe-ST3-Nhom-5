import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../models/trip.dart';
import '../../core/services/notification_service.dart';
import '../../services/smart_boarding_service.dart';
import '../../widgets/shared_components.dart';

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
    setState(() {
      _isCreatingPayment = true;
      _error = null;
    });
    try {
      final data = await context.read<BookingService>().createPayment(widget.booking.id);
      if (mounted) {
        setState(() {
          _paymentData = data;
          _isCreatingPayment = false;
        });
        _startPolling();
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isCreatingPayment = false;
        });
      }
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
        await SmartBoardingService.instance.cancelPaymentPending();
        await NotificationService().showPaymentSuccess(widget.booking.ticketCode);
        final depTimeStr = widget.trip.departureTime.isNotEmpty
            ? '${widget.trip.departureTime} - ${widget.trip.departureDate}'
            : 'Giờ khởi hành';
        await SmartBoardingService.instance.notifyTicketConfirmed(
          ticketCode: widget.booking.ticketCode,
          routeName: widget.trip.routeName,
          departureTime: depTimeStr,
          seatNumber: widget.booking.seatNumber,
        );
        Booking fullBooking = widget.booking;
        try {
          fullBooking = await context.read<BookingService>().getBookingById(widget.booking.id);
        } catch (e) {
          debugPrint('Không tải được chi tiết vé để lập lịch nhắc: $e');
        }
        await SmartBoardingService.instance.scheduleRemindersForBooking(fullBooking);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.pushReplacement('/booking_confirmation', extra: {
            'booking': widget.booking,
            'trip': widget.trip,
          });
        }
      } else if (!silent && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chưa ghi nhận thanh toán',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Hệ thống chưa nhận được xác nhận giao dịch.\n\nNếu bạn vừa chuyển khoản, vui lòng đợi vài giây rồi kiểm tra lại.',
              style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
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
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final amount = _paymentData?['amount'] ?? widget.booking.ticketPrice ?? widget.trip.price;
    final isMock = _paymentData?['is_mock'] == true;
    final checkoutUrl = _paymentData?['checkout_url'];

    return Scaffold(
      backgroundColor: AppColors.background,
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
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Đang khởi tạo cổng thanh toán an toàn...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
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
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.success, size: 44),
          ),
          const SizedBox(height: 16),
          const Text(
            'Thanh toán thành công!',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(amount),
            style: const TextStyle(color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          const Text(
            'Đang xuất vé điện tử của bạn...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return EmptyStateWidget(
      icon: Icons.error_outline_rounded,
      title: 'Không thể tạo liên kết thanh toán',
      description: _error ?? 'Đã có lỗi xảy ra khi kết nối cổng thanh toán.',
      buttonText: 'Thử lại',
      onButtonPressed: _createPaymentLink,
    );
  }

  Widget _buildPaymentContent(NumberFormat fmt, num amount, bool isMock, String? checkoutUrl) {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppColors.textPrimary),
              ),
              const Expanded(
                child: Text(
                  'Thanh toán vé xe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        const BookingStepIndicator(currentStep: 4),
        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isMock)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Chế độ mô phỏng thanh toán (PayOS Sandbox).',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Amount & Booking Summary Card
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Tổng số tiền thanh toán',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fmt.format(amount),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Ticket Code Pill
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.booking.ticketCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép mã đặt vé'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.confirmation_number_outlined, size: 15, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Mã vé: ${widget.booking.ticketCode}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tuyến đường:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                          Text(
                            '${widget.trip.departureStation} → ${widget.trip.arrivalStation}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Khởi hành & Ghế:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                          Text(
                            '${widget.trip.departureTime} • Ghế ${widget.booking.seatNumber}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Countdown Timer
                      if (!_isExpired) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Thời gian giữ ghế còn lại: $_countdownDisplay',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _countdown / 900,
                            backgroundColor: AppColors.primaryLight,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                            minHeight: 5,
                          ),
                        ),
                      ] else
                        const StatusBadge(
                          label: 'Phiên thanh toán đã hết hạn',
                          type: BadgeType.error,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // QR Payment Card
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PayOS QR',
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Quét mã QR bằng ứng dụng Ngân hàng',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Container(
                        width: 186,
                        height: 186,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: isMock
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, size: 110, color: AppColors.textPrimary),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.booking.ticketCode,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              )
                            : checkoutUrl != null
                                ? QrImageView(
                                    data: checkoutUrl,
                                    version: QrVersions.auto,
                                    size: 186.0,
                                    padding: const EdgeInsets.all(14),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_2_rounded, size: 100, color: AppColors.textSecondary),
                                      Text('Không tải được QR', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'Hỗ trợ VietQR, MoMo, ZaloPay & hơn 40 ngân hàng nội địa',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            children: [
              if (checkoutUrl != null && !isMock && !_isExpired) ...[
                PrimaryButton(
                  text: 'Mở trang thanh toán PayOS',
                  icon: Icons.open_in_new_rounded,
                  onPressed: _openPaymentUrl,
                ),
                const SizedBox(height: 10),
              ],
              SecondaryButton(
                text: _isExpired ? 'Phiên đã hết hạn' : 'Kiểm tra trạng thái thanh toán',
                icon: Icons.refresh_rounded,
                width: double.infinity,
                isTinted: true,
                onPressed: (_isChecking || _isExpired) ? null : () => _checkPaymentStatus(),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/tickets'),
                child: const Text(
                  'Quản lý vé của tôi',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
