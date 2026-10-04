import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';

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

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: valueColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết vé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetail,
          ),
        ],
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
    final statusColor = booking.isCancelled ? Colors.red : booking.isPaid ? Colors.green : Colors.orange;
    final statusLabel = booking.isCancelled ? 'Đã hủy' : booking.isPaid ? 'Đã thanh toán' : 'Chờ thanh toán';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withAlpha(80)),
            ),
            child: Row(
              children: [
                Icon(booking.isPaid ? Icons.check_circle : Icons.pending, color: statusColor),
                const SizedBox(width: 10),
                Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ticket Code Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mã vé', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(booking.ticketCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.blue),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: booking.ticketCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép mã vé')),
                          );
                        },
                      ),
                    ],
                  ),
                  // Simple QR representation using ticket code
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2, size: 120, color: Colors.black87),
                        const SizedBox(height: 4),
                        Text(booking.ticketCode, style: const TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Trip Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin chuyến', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(height: 20),
                  if (booking.trip != null) ...[
                    _infoRow(Icons.directions_bus, 'Nhà xe', booking.trip!.companyName),
                    _infoRow(Icons.location_on, 'Điểm đi', booking.trip!.startPoint),
                    _infoRow(Icons.flag, 'Điểm đến', booking.trip!.endPoint),
                    _infoRow(Icons.access_time, 'Khởi hành', booking.departureTime),
                  ] else
                    const Text('Thông tin chuyến không có sẵn', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Passenger + Payment Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin hành khách & thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(height: 20),
                  _infoRow(Icons.person, 'Hành khách', booking.passengerName),
                  _infoRow(Icons.phone, 'Số điện thoại', booking.passengerPhone),
                  _infoRow(Icons.airline_seat_recline_normal, 'Ghế số', booking.seatNumber),
                  _infoRow(
                    Icons.payment,
                    'Số tiền',
                    currencyFormatter.format(booking.ticketPrice),
                    valueColor: Colors.blue,
                  ),
                  _infoRow(
                    booking.isPaid ? Icons.check_circle : Icons.pending,
                    'Thanh toán',
                    booking.paymentStatus,
                    valueColor: booking.isPaid ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Cancel Button — only show if not cancelled/paid
          if (!booking.isCancelled && !booking.isPaid)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: _isCancelling ? null : _cancelBooking,
              icon: _isCancelling
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cancel_outlined),
              label: Text(_isCancelling ? 'Đang hủy...' : 'Hủy vé này'),
            ),
        ],
      ),
    );
  }
}
