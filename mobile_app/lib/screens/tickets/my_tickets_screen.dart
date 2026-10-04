import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../widgets/app_nav_bar.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen>
    with SingleTickerProviderStateMixin {
  List<Booking>? _bookings;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bookings =
          await context.read<BookingService>().getMyBookings();
      if (mounted) setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _statusBg(Booking b) {
    if (b.isCancelled) return const Color(0xFFFEE2E2);
    if (b.isPaid) return const Color(0xFFDCFCE7);
    return const Color(0xFFFEF3C7);
  }

  Color _statusFg(Booking b) {
    if (b.isCancelled) return const Color(0xFFDC2626);
    if (b.isPaid) return const Color(0xFF16A34A);
    return const Color(0xFFD97706);
  }

  String _statusLabel(Booking b) {
    if (b.isCancelled) return 'Đã hủy';
    if (b.isPaid) return 'Đã thanh toán';
    if (b.isHold) return 'Chờ thanh toán';
    return b.status;
  }

  List<Booking> _filterByTab(int index) {
    if (_bookings == null) return [];
    switch (index) {
      case 0:
        return _bookings!;
      case 1:
        return _bookings!.where((b) => !b.isCancelled && !b.isPaid).toList();
      case 2:
        return _bookings!.where((b) => b.isCancelled).toList();
      default:
        return _bookings!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0F172A), size: 20),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Text(
                      'Vé của tôi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadBookings,
                    child: const Icon(Icons.refresh,
                        size: 22, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF0B192C),
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorColor: const Color(0xFF0B192C),
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'Tất cả'),
                  Tab(text: 'Chờ thanh toán'),
                  Tab(text: 'Đã hủy'),
                ],
                onTap: (_) => setState(() {}),
              ),
            ),

            // Body
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBookings,
                color: const Color(0xFF0B192C),
                child: _buildBody(currencyFormatter),
              ),
            ),

            AppNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(NumberFormat fmt) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0B192C)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(Icons.wifi_off,
                    size: 36, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 16),
              const Text('Không thể tải danh sách vé',
                  style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadBookings,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B192C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered =
        _filterByTab(_tabController.index);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(44),
              ),
              child: const Icon(Icons.confirmation_number_outlined,
                  size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text('Không có vé nào',
                style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Đặt vé ngay để bắt đầu hành trình!',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B192C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Tìm chuyến xe'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = filtered[index];
        return GestureDetector(
          onTap: () => context.push('/tickets/${booking.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0A0F172A),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top row: mã vé + status
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mã vé: ${booking.ticketCode}',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusBg(booking),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(booking),
                          style: TextStyle(
                            color: _statusFg(booking),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Details
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    children: [
                      if (booking.trip != null) ...[
                        _DetailRow(
                          icon: Icons.directions_bus,
                          iconColor: const Color(0xFF00639B),
                          text: booking.routeName,
                          bold: true,
                        ),
                        const SizedBox(height: 6),
                        _DetailRow(
                          icon: Icons.access_time,
                          iconColor: const Color(0xFF94A3B8),
                          text: booking.departureTime,
                        ),
                        const SizedBox(height: 6),
                      ],
                      _DetailRow(
                        icon: Icons.airline_seat_recline_normal,
                        iconColor: const Color(0xFF94A3B8),
                        text: 'Ghế: ${booking.seatNumber}',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fmt.format(booking.ticketPrice),
                            style: const TextStyle(
                              color: Color(0xFF00639B),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: const [
                              Text('Xem chi tiết',
                                  style: TextStyle(
                                      color: Color(0xFF00639B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Icon(Icons.chevron_right,
                                  color: Color(0xFF00639B), size: 18),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final bool bold;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: bold ? const Color(0xFF0F172A) : const Color(0xFF475569),
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}


