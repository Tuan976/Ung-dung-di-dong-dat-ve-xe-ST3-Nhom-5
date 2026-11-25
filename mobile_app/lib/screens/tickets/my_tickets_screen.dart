import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/shared_components.dart';
import '../../services/smart_boarding_service.dart';

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
      final bookings = await context.read<BookingService>().getMyBookings();
      SmartBoardingService.instance.checkBusChanges(bookings);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  BadgeType _badgeType(Booking b) {
    if (b.isCancelled) return BadgeType.error;
    if (b.isPaid) return BadgeType.success;
    return BadgeType.warning;
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
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 19),
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
                        color: AppColors.textPrimary,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _loadBookings,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.refresh_rounded, size: 21, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                dividerColor: AppColors.border,
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
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
                color: AppColors.primary,
                child: _buildBody(currencyFormatter),
              ),
            ),

            const AppNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(NumberFormat fmt) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return EmptyStateWidget(
        icon: Icons.wifi_off_rounded,
        title: 'Không thể tải danh sách vé',
        description: _error!,
        buttonText: 'Thử lại',
        onButtonPressed: _loadBookings,
      );
    }

    final filtered = _filterByTab(_tabController.index);

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.confirmation_number_outlined,
        title: 'Chưa có vé trong mục này',
        description: 'Đặt chuyến xe trên Triply để quản lý vé điện tử và theo dõi lộ trình trực tiếp.',
        buttonText: 'Tìm chuyến xe',
        onButtonPressed: () => context.go('/home'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = filtered[index];
        return AppCard(
          onTap: () => context.push('/tickets/${booking.id}'),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Top row: Ticket code + status badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.confirmation_number_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          booking.ticketCode,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(
                      label: _statusLabel(booking),
                      type: _badgeType(booking),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Middle & Footer details
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    if (booking.trip != null) ...[
                      _DetailRow(
                        icon: Icons.route_rounded,
                        iconColor: AppColors.primary,
                        text: booking.routeName,
                        bold: true,
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.textSecondary,
                        text: booking.departureTime,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _DetailRow(
                      icon: Icons.event_seat_rounded,
                      iconColor: AppColors.textSecondary,
                      text: 'Vị trí ghế: ${booking.seatNumber}',
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fmt.format(booking.ticketPrice),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Chi tiết vé',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
