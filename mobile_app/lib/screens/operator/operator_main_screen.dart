import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/company_service.dart';
import 'live_passenger_radar_screen.dart';

class OperatorMainScreen extends StatefulWidget {
  const OperatorMainScreen({super.key});

  @override
  State<OperatorMainScreen> createState() => _OperatorMainScreenState();
}

class _OperatorMainScreenState extends State<OperatorMainScreen> {
  int _currentTabIndex = 0;
  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  // Design System — Light Orange & White Transportation App
  static const Color brandOrange = Color(0xFFF26A21); // Cam thương hiệu #F26A21
  static const Color brandOrangeDark = Color(0xFFE65B16); // Cam đậm #E65B16
  static const Color brandOrangeLight = Color(0xFFFFF0E6); // Cam nhạt #FFF0E6
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Trắng #FFFFFF
  static const Color bgOverall = Color(0xFFF8F9FB); // Nền tổng thể #F8F9FB
  static const Color textMain = Color(0xFF263244); // Chữ chính #263244
  static const Color textSub = Color(0xFF778397); // Chữ phụ #778397
  static const Color borderSubtle = Color(0xFFE7EAF0); // Đường viền #E7EAF0
  static const Color successGreen = Color(0xFF16A36A);
  static const Color successGreenLight = Color(0xFFE9F8F0);
  static const Color warningOrange = Color(0xFFE99A22);
  static const Color warningOrangeLight = Color(0xFFFFF5E5);
  static const Color alertSoftRed = Color(0xFFFFF5F3);
  static const Color alertBorderRed = Color(0xFFFCA5A5);
  static const Color alertTextRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: bgOverall,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: borderSubtle, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: brandOrangeLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: brandOrange.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: brandOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.companyName ??
                        (user?.name.isNotEmpty == true
                            ? user!.name
                            : 'Nhà xe HUTECH BUS'),
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: brandOrangeLight,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: brandOrange.withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          user?.roleDisplayName ?? 'NHÂN VIÊN VẬN HÀNH',
                          style: const TextStyle(
                            color: brandOrangeDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Trung tâm Xử lý Sự cố',
            icon: const Icon(Icons.emergency_outlined, color: warningOrange),
            onPressed: () {
              _showIncidentCenterDialog(context);
            },
          ),
          IconButton(
            tooltip: 'Chuyển sang giao diện Khách',
            icon: const Icon(Icons.swap_horiz, color: textSub),
            onPressed: () {
              context.go('/home');
            },
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: textSub),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'Đăng xuất',
                    style: TextStyle(
                      color: textMain,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  content: const Text(
                    'Bạn có chắc muốn đăng xuất khỏi tài khoản nhà xe?',
                    style: TextStyle(color: textSub),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy', style: TextStyle(color: textSub)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alertTextRed,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Đăng xuất',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await context.read<AuthService>().logout();
                if (mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex.clamp(0, (user?.canManageFleet == true ? 5 : 4) - 1),
        children: [
          const _DashboardTab(),
          const _TripsTab(),
          const _ManifestTab(),
          const _CargoTab(),
          if (user?.canManageFleet == true) const _FleetStaffTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: surfaceWhite,
          border: Border(
            top: BorderSide(color: borderSubtle, width: 1),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentTabIndex.clamp(0, (user?.canManageFleet == true ? 5 : 4) - 1),
            onTap: (index) => setState(() => _currentTabIndex = index),
            selectedItemColor: brandOrange,
            unselectedItemColor: textSub,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: surfaceWhite,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_outlined),
                activeIcon: const Icon(Icons.dashboard),
                label: user?.isDriver == true ? 'Ca trực' : 'Tổng quan',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.alt_route_outlined),
                activeIcon: const Icon(Icons.alt_route),
                label: user?.isDriver == true ? 'Lịch chạy' : 'Chuyến xe',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Phơi khách',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Phơi hàng',
              ),
              if (user?.canManageFleet == true)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.directions_bus_outlined),
                  activeIcon: Icon(Icons.directions_bus),
                  label: 'Xe & Tài xế',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 1: TỔNG QUAN (DASHBOARD)
// =============================================================================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _todayTrips = [];
  final NumberFormat _fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final companyService = context.read<CompanyService>();
    final stats = await companyService.getStats();
    final trips = await companyService.getTrips();
    if (mounted) {
      setState(() {
        _stats = stats;
        _todayTrips = trips.take(5).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _OperatorMainScreenState.brandOrange,
        ),
      );
    }

    final user = context.watch<AuthService>().currentUser;
    final revTickets = _stats?['revenue_tickets'] ?? 0;
    final revCargo = _stats?['revenue_cargo'] ?? 0;
    final totalRev = revTickets + revCargo;
    final activeTrips = _stats?['active_trips'] ?? 0;
    final cargoCount = _stats?['cargo_count'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _OperatorMainScreenState.brandOrange,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card: Doanh thu (Admin) HOẶC Ca trực (Tài xế/Phụ xe)
            if (user?.canViewRevenue == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _OperatorMainScreenState.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _OperatorMainScreenState.borderSubtle,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TỔNG DOANH THU NHÀ XE',
                          style: TextStyle(
                            color: _OperatorMainScreenState.textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _OperatorMainScreenState.successGreenLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _OperatorMainScreenState.successGreen.withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Trực tuyến',
                            style: TextStyle(
                              color: _OperatorMainScreenState.successGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _fmt.format(totalRev),
                      style: const TextStyle(
                        color: _OperatorMainScreenState.textMain,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: _OperatorMainScreenState.borderSubtle, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vé hành khách',
                                style: TextStyle(
                                  color: _OperatorMainScreenState.textSub,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fmt.format(revTickets),
                                style: const TextStyle(
                                  color: _OperatorMainScreenState.brandOrange,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: _OperatorMainScreenState.borderSubtle),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ký gửi hàng hóa',
                                style: TextStyle(
                                  color: _OperatorMainScreenState.textSub,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fmt.format(revCargo),
                                style: const TextStyle(
                                  color: Color(0xFF2878D0),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _OperatorMainScreenState.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _OperatorMainScreenState.borderSubtle,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CA TRỰC VẬN HÀNH',
                          style: TextStyle(
                            color: _OperatorMainScreenState.textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _OperatorMainScreenState.successGreenLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _OperatorMainScreenState.successGreen.withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Sẵn sàng làm việc',
                            style: TextStyle(
                              color: _OperatorMainScreenState.successGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.name ?? 'Tài xế',
                      style: const TextStyle(
                        color: _OperatorMainScreenState.textMain,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _OperatorMainScreenState.brandOrangeLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Vai trò: ${user?.roleDisplayName ?? "TÀI XẾ"}',
                            style: const TextStyle(
                              color: _OperatorMainScreenState.brandOrangeDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: _OperatorMainScreenState.borderSubtle, height: 1),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: _OperatorMainScreenState.successGreen, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Quyền hạn ca trực: Xem phơi khách, phơi hàng, soát vé QR & báo sự cố.',
                            style: TextStyle(
                              color: _OperatorMainScreenState.textSub,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 2 Stat Badges
            Row(
              children: [
                Expanded(
                  child: _buildSmallStatCard(
                    title: 'Chuyến đang chạy',
                    value: '$activeTrips chuyến',
                    icon: Icons.directions_bus,
                    color: _OperatorMainScreenState.brandOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSmallStatCard(
                    title: 'Đơn hàng ký gửi',
                    value: '$cargoCount kiện',
                    icon: Icons.local_shipping,
                    color: const Color(0xFF2878D0),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'TÁC VỤ NHANH',
              style: TextStyle(
                color: _OperatorMainScreenState.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (user?.canCreateTrip == true)
                  _buildActionButton(
                    icon: Icons.add_circle_outline,
                    color: _OperatorMainScreenState.brandOrange,
                    label: 'Tạo chuyến',
                    onTap: () => _showCreateTripDialog(context),
                  )
                else
                  _buildActionButton(
                    icon: Icons.alt_route,
                    color: _OperatorMainScreenState.brandOrange,
                    label: 'Lịch chạy',
                    onTap: () {
                      final mainState = context.findAncestorStateOfType<_OperatorMainScreenState>();
                      mainState?.setState(() => mainState._currentTabIndex = 1);
                    },
                  ),
                const SizedBox(width: 10),
                _buildActionButton(
                  icon: Icons.post_add,
                  color: _OperatorMainScreenState.brandOrange,
                  label: user?.isDriver == true ? 'Phơi hàng' : 'Gửi hàng',
                  onTap: () {
                    if (user?.isDriver == true) {
                      final mainState = context.findAncestorStateOfType<_OperatorMainScreenState>();
                      mainState?.setState(() => mainState._currentTabIndex = 3);
                    } else {
                      _showCreateCargoDialog(context);
                    }
                  },
                ),
                const SizedBox(width: 10),
                _buildActionButton(
                  icon: Icons.qr_code_scanner,
                  color: _OperatorMainScreenState.brandOrange,
                  label: 'Soát vé QR',
                  onTap: () => context.push('/operator/qr-scan'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Emergency / Incident Command Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _OperatorMainScreenState.alertSoftRed,
                borderRadius: BorderRadius.circular(16),
                border: const Border(
                  left: BorderSide(
                    color: _OperatorMainScreenState.brandOrange,
                    width: 4,
                  ),
                  top: BorderSide(color: _OperatorMainScreenState.borderSubtle),
                  right: BorderSide(color: _OperatorMainScreenState.borderSubtle),
                  bottom: BorderSide(color: _OperatorMainScreenState.borderSubtle),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                          color: _OperatorMainScreenState.surfaceWhite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: _OperatorMainScreenState.brandOrangeDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'XỬ LÝ SỰ CỐ & CỨU VIỆN',
                              style: TextStyle(
                                color: _OperatorMainScreenState.textMain,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'Hệ thống ổn định • Sẵn sàng điều xe & sang khách',
                              style: TextStyle(
                                color: _OperatorMainScreenState.textSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user?.canDispatchRescue == true)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _OperatorMainScreenState.surfaceWhite,
                            foregroundColor: _OperatorMainScreenState.brandOrangeDark,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: BorderSide(
                              color: _OperatorMainScreenState.brandOrange.withOpacity(0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _showIncidentCenterDialog(context),
                          child: const Text(
                            'TRUNG TÂM',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _showReportIncidentDialog(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _OperatorMainScreenState.surfaceWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _OperatorMainScreenState.borderSubtle,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.report_problem_outlined,
                                  color: _OperatorMainScreenState.alertTextRed,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Báo sự cố',
                                  style: TextStyle(
                                    color: _OperatorMainScreenState.textMain,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showIncidentCenterDialog(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _OperatorMainScreenState.surfaceWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _OperatorMainScreenState.borderSubtle,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.car_crash_outlined,
                                  color: _OperatorMainScreenState.brandOrangeDark,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Cứu viện / Sang xe',
                                  style: TextStyle(
                                    color: _OperatorMainScreenState.textMain,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent Trips Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CHUYẾN XE HÔM NAY',
                  style: TextStyle(
                    color: _OperatorMainScreenState.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Switch to Trips Tab
                    final mainState = context
                        .findAncestorStateOfType<_OperatorMainScreenState>();
                    mainState?.setState(() => mainState._currentTabIndex = 1);
                  },
                  child: const Text(
                    'Xem tất cả',
                    style: TextStyle(
                      color: _OperatorMainScreenState.brandOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_todayTrips.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _OperatorMainScreenState.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _OperatorMainScreenState.borderSubtle),
                ),
                child: const Center(
                  child: Text(
                    'Chưa có chuyến xe nào được tạo.',
                    style: TextStyle(color: _OperatorMainScreenState.textSub),
                  ),
                ),
              )
            else
              ..._todayTrips.map((t) => _buildTripCard(t, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OperatorMainScreenState.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _OperatorMainScreenState.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color == _OperatorMainScreenState.brandOrange
                  ? _OperatorMainScreenState.brandOrangeLight
                  : const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _OperatorMainScreenState.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _OperatorMainScreenState.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _OperatorMainScreenState.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _OperatorMainScreenState.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: _OperatorMainScreenState.brandOrangeLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: _OperatorMainScreenState.brandOrange,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _OperatorMainScreenState.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, BuildContext context) {
    final status = trip['status'] ?? 'Scheduled';
    final depTime = trip['departure_time'] != null
        ? DateTime.tryParse(
            trip['departure_time'].toString().replaceAll('Z', ''),
          )
        : null;
    final timeStr = depTime != null
        ? DateFormat('HH:mm - dd/MM').format(depTime)
        : 'N/A';
    final occupancy = trip['occupancy'] ?? '0/0';

    Color statusBg = const Color(0xFFEAF3FF);
    Color statusText = const Color(0xFF2878D0);
    String statusLabel = 'Đã lên lịch';
    if (status == 'Running') {
      statusBg = _OperatorMainScreenState.successGreenLight;
      statusText = _OperatorMainScreenState.successGreen;
      statusLabel = 'Đang chạy';
    } else if (status == 'Completed') {
      statusBg = const Color(0xFFF1F3F7);
      statusText = _OperatorMainScreenState.textSub;
      statusLabel = 'Hoàn thành';
    } else if (status == 'Cancelled') {
      statusBg = _OperatorMainScreenState.alertSoftRed;
      statusText = _OperatorMainScreenState.alertTextRed;
      statusLabel = 'Đã hủy';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OperatorMainScreenState.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _OperatorMainScreenState.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trip['route'] ?? 'Tuyến xe',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _OperatorMainScreenState.textMain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: _OperatorMainScreenState.textSub,
              ),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: _OperatorMainScreenState.textMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.directions_bus,
                size: 14,
                color: _OperatorMainScreenState.textSub,
              ),
              const SizedBox(width: 4),
              Text(
                trip['bus'] ?? 'N/A',
                style: const TextStyle(
                  fontSize: 12,
                  color: _OperatorMainScreenState.textMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _OperatorMainScreenState.brandOrangeLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _OperatorMainScreenState.brandOrange.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  'Ghế: $occupancy',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _OperatorMainScreenState.brandOrangeDark,
                  ),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _OperatorMainScreenState.brandOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.radar, size: 13),
                    label: const Text('Bản đồ đón', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LivePassengerRadarScreen(
                            tripId: trip['id'],
                            tripRoute: trip['route'],
                            busPlate: trip['bus'],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _OperatorMainScreenState.brandOrangeLight,
                      foregroundColor: _OperatorMainScreenState.brandOrangeDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      side: BorderSide(
                        color: _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.list_alt, size: 13),
                    label: const Text(
                      'Phơi khách',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      // Switch to Manifest tab and load this trip
                      _selectedTripIdForManifest = trip['id'];
                      final mainState = context
                          .findAncestorStateOfType<_OperatorMainScreenState>();
                      mainState?.setState(() => mainState._currentTabIndex = 2);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

int? _selectedTripIdForManifest;

// =============================================================================
// TAB 2: QUẢN LÝ CHUYẾN XE (TRIPS)
// =============================================================================
class _TripsTab extends StatefulWidget {
  const _TripsTab();

  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trips = [];
  String _filterStatus = 'ALL'; // ALL, Scheduled, Running, Completed

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    final companyService = context.read<CompanyService>();
    final trips = await companyService.getTrips();
    if (mounted) {
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final filtered = _filterStatus == 'ALL'
        ? _trips
        : (_filterStatus == 'MY_TRIPS'
            ? _trips
                .where(
                  (t) =>
                      t['driver_id'] == user?.id ||
                      (t['driver_name'] != null &&
                          user?.name != null &&
                          t['driver_name'].toString().toLowerCase().contains(
                                user!.name.toLowerCase(),
                              )),
                )
                .toList()
            : _trips
                .where(
                  (t) =>
                      (t['status'] ?? '').toString().toUpperCase() ==
                      _filterStatus.toUpperCase(),
                )
                .toList());

    return Scaffold(
      backgroundColor: _OperatorMainScreenState.bgOverall,
      floatingActionButton: user?.canCreateTrip == true
          ? FloatingActionButton.extended(
              backgroundColor: _OperatorMainScreenState.brandOrange,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add),
              label: const Text(
                'Tạo chuyến mới',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final created = await _showCreateTripDialog(context);
                if (created == true) _loadTrips();
              },
            )
          : null,
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _OperatorMainScreenState.surfaceWhite,
              border: Border(
                bottom: BorderSide(color: _OperatorMainScreenState.borderSubtle),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', 'ALL'),
                  if (user?.isDriver == true) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip('⭐ Chuyến của tôi', 'MY_TRIPS'),
                  ],
                  const SizedBox(width: 8),
                  _buildFilterChip('Sắp chạy', 'Scheduled'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Đang chạy', 'Running'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hoàn thành', 'Completed'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _OperatorMainScreenState.brandOrange),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTrips,
                    color: _OperatorMainScreenState.brandOrange,
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Không có chuyến xe nào',
                              style: TextStyle(color: _OperatorMainScreenState.textSub),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, idx) =>
                                _buildTripItem(filtered[idx]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterStatus = value),
      selectedColor: _OperatorMainScreenState.brandOrangeLight,
      backgroundColor: _OperatorMainScreenState.bgOverall,
      side: BorderSide(
        color: isSelected
            ? _OperatorMainScreenState.brandOrange
            : _OperatorMainScreenState.borderSubtle,
        width: isSelected ? 1.2 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? _OperatorMainScreenState.brandOrangeDark
            : _OperatorMainScreenState.textSub,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _buildTripItem(Map<String, dynamic> trip) {
    final status = trip['status'] ?? 'Scheduled';
    final depTime = trip['departure_time'] != null
        ? DateTime.tryParse(
            trip['departure_time'].toString().replaceAll('Z', ''),
          )
        : null;
    final timeStr = depTime != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(depTime)
        : 'N/A';
    final occupancy = trip['occupancy'] ?? '0/0';

    Color statusBg = const Color(0xFFEAF3FF);
    Color statusText = const Color(0xFF2878D0);
    String statusLabel = 'Đã lên lịch';
    if (status == 'Running') {
      statusBg = _OperatorMainScreenState.successGreenLight;
      statusText = _OperatorMainScreenState.successGreen;
      statusLabel = 'Đang chạy';
    } else if (status == 'Completed') {
      statusBg = const Color(0xFFF1F3F7);
      statusText = _OperatorMainScreenState.textSub;
      statusLabel = 'Hoàn thành';
    } else if (status == 'Cancelled') {
      statusBg = _OperatorMainScreenState.alertSoftRed;
      statusText = _OperatorMainScreenState.alertTextRed;
      statusLabel = 'Đã hủy';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OperatorMainScreenState.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _OperatorMainScreenState.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trip['route'] ?? 'Tuyến xe',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _OperatorMainScreenState.textMain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: _OperatorMainScreenState.textSub,
              ),
              const SizedBox(width: 6),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 13,
                  color: _OperatorMainScreenState.textMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.directions_bus,
                size: 14,
                color: _OperatorMainScreenState.textSub,
              ),
              const SizedBox(width: 6),
              Text(
                'Biển số: ${trip['bus'] ?? "Chưa gán"}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _OperatorMainScreenState.textMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _OperatorMainScreenState.brandOrangeLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _OperatorMainScreenState.brandOrange.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  'Ghế: $occupancy',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _OperatorMainScreenState.brandOrangeDark,
                  ),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _OperatorMainScreenState.brandOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.radar, size: 14),
                    label: const Text(
                      'Bản đồ đón',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LivePassengerRadarScreen(
                            tripId: trip['id'],
                            tripRoute: trip['route'],
                            busPlate: trip['bus'],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _OperatorMainScreenState.brandOrangeLight,
                      foregroundColor: _OperatorMainScreenState.brandOrangeDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      side: BorderSide(
                        color: _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.groups, size: 16),
                    label: const Text(
                      'Phơi khách',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _selectedTripIdForManifest = trip['id'];
                      final mainState = context
                          .findAncestorStateOfType<_OperatorMainScreenState>();
                      mainState?.setState(() => mainState._currentTabIndex = 2);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 3: QUẢN LÝ HÀNH KHÁCH & PHƠI KHÁCH (MANIFEST)
// =============================================================================
class _ManifestTab extends StatefulWidget {
  const _ManifestTab();

  @override
  State<_ManifestTab> createState() => _ManifestTabState();
}

class _ManifestTabState extends State<_ManifestTab> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _trips = [];
  int? _selectedTripId;
  List<Map<String, dynamic>> _passengers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTripsAndSelect();
  }

  Future<void> _loadTripsAndSelect() async {
    setState(() => _isLoading = true);
    final companyService = context.read<CompanyService>();
    final trips = await companyService.getTrips();
    if (mounted) {
      setState(() {
        _trips = trips;
        _selectedTripId =
            _selectedTripIdForManifest ??
            (trips.isNotEmpty ? trips.first['id'] : null);
      });
      if (_selectedTripId != null) {
        await _loadPassengers(_selectedTripId!);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPassengers(int tripId) async {
    setState(() => _isLoading = true);
    final companyService = context.read<CompanyService>();
    final pax = await companyService.getTripPassengers(tripId);
    if (mounted) {
      setState(() {
        _passengers = pax;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchPassengers(String q) async {
    if (q.trim().isEmpty) {
      if (_selectedTripId != null) _loadPassengers(_selectedTripId!);
      return;
    }
    setState(() => _isLoading = true);
    final companyService = context.read<CompanyService>();
    final results = await companyService.searchPassengers(q);
    if (mounted) {
      setState(() {
        _passengers = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardedCount = _passengers
        .where((p) => p['boarding_status'] == 'BOARDED')
        .length;

    return Column(
      children: [
        // Controls: Trip Picker & Search
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: _OperatorMainScreenState.surfaceWhite,
            border: Border(
              bottom: BorderSide(color: _OperatorMainScreenState.borderSubtle),
            ),
          ),
          child: Column(
            children: [
              // Nút mở Radar đón khách trực diện cho Tài xế
              if (_selectedTripId != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _OperatorMainScreenState.brandOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.radar, size: 20),
                    label: const Text(
                      'MỞ BẢN ĐỒ ĐÓN KHÁCH TRỰC DIỆN (RADAR LIVE)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    onPressed: () {
                      final selTrip = _trips.firstWhere(
                        (t) => t['id'] == _selectedTripId,
                        orElse: () => {'id': _selectedTripId},
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LivePassengerRadarScreen(
                            tripId: _selectedTripId!,
                            tripRoute: selTrip['route'],
                            busPlate: selTrip['bus'],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Trip Selector
              if (_trips.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _OperatorMainScreenState.bgOverall,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _OperatorMainScreenState.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedTripId,
                      isExpanded: true,
                      hint: const Text('Chọn chuyến xe'),
                      items: _trips.map((t) {
                        final time = t['departure_time'] != null
                            ? t['departure_time'].toString().substring(11, 16)
                            : '';
                        return DropdownMenuItem<int>(
                          value: t['id'],
                          child: Text(
                            '#${t['id']} | ${t['route']} ($time - ${t['bus']})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _OperatorMainScreenState.textMain,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          setState(() => _selectedTripId = newId);
                          _selectedTripIdForManifest = newId;
                          _loadPassengers(newId);
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              // Search field with QR scanner button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm khách theo tên, SĐT hoặc ghế...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: _OperatorMainScreenState.textSub,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20, color: _OperatorMainScreenState.textSub),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  if (_selectedTripId != null)
                                    _loadPassengers(_selectedTripId!);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: _OperatorMainScreenState.bgOverall,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _OperatorMainScreenState.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _OperatorMainScreenState.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _OperatorMainScreenState.brandOrange, width: 1.5),
                        ),
                      ),
                      onSubmitted: _searchPassengers,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      await context.push('/operator/qr-scan');
                      if (_selectedTripId != null) {
                        _loadPassengers(_selectedTripId!);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _OperatorMainScreenState.brandOrangeLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: _OperatorMainScreenState.brandOrange,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Boarding stat row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng khách: ${_passengers.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _OperatorMainScreenState.textMain,
                    ),
                  ),
                  Text(
                    'Đã lên xe: $boardedCount / ${_passengers.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _OperatorMainScreenState.successGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Passenger list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _OperatorMainScreenState.brandOrange),
                )
              : _passengers.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có hành khách nào trên chuyến.',
                    style: TextStyle(color: _OperatorMainScreenState.textSub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _passengers.length,
                  itemBuilder: (ctx, idx) =>
                      _buildPassengerCard(_passengers[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildPassengerCard(Map<String, dynamic> pax) {
    final isBoarded = pax['boarding_status'] == 'BOARDED';
    final hasGps = pax['pickup_lat'] != null && pax['pickup_lng'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OperatorMainScreenState.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBoarded ? _OperatorMainScreenState.successGreen.withOpacity(0.4) : _OperatorMainScreenState.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seat Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isBoarded
                      ? _OperatorMainScreenState.successGreenLight
                      : _OperatorMainScreenState.brandOrangeLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBoarded
                        ? _OperatorMainScreenState.successGreen.withOpacity(0.3)
                        : _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    pax['seat'] ?? '?',
                    style: TextStyle(
                      color: isBoarded
                          ? _OperatorMainScreenState.successGreen
                          : _OperatorMainScreenState.brandOrangeDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and Phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pax['name'] ?? 'Khách hàng',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _OperatorMainScreenState.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          size: 14,
                          color: _OperatorMainScreenState.textSub,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pax['phone'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _OperatorMainScreenState.textSub,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Boarded Tag & Live Location Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBoarded
                      ? _OperatorMainScreenState.successGreenLight
                      : (pax['is_sharing_location'] == true
                          ? const Color(0xFFD1FAE5)
                          : _OperatorMainScreenState.warningOrangeLight),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBoarded
                      ? 'ĐÃ LÊN XE'
                      : (pax['is_sharing_location'] == true
                          ? '🟢 LIVE GPS'
                          : 'CHỜ ĐÓN'),
                  style: TextStyle(
                    color: isBoarded
                        ? _OperatorMainScreenState.successGreen
                        : (pax['is_sharing_location'] == true
                            ? const Color(0xFF065F46)
                            : _OperatorMainScreenState.warningOrange),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pickup info
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: _OperatorMainScreenState.brandOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pax['pickup_landmark'] ??
                      pax['pickup'] ??
                      'Điểm đón mặc định',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _OperatorMainScreenState.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (pax['pickup_note'] != null &&
              pax['pickup_note'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Ghi chú: ${pax['pickup_note']}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Action Buttons: Dẫn đường & Check-in
          Row(
            children: [
              if (hasGps)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text(
                      'Dẫn đường',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      final lat = pax['pickup_lat'];
                      final lng = pax['pickup_lng'];
                      final uri = Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ),
              if (hasGps) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBoarded
                        ? _OperatorMainScreenState.successGreen
                        : _OperatorMainScreenState.brandOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    isBoarded ? Icons.check_circle : Icons.qr_code_scanner,
                    size: 16,
                  ),
                  label: Text(
                    isBoarded ? 'Đã Check-in' : 'Check-in đón',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    final bookingId = pax['id'];
                    final success = await context
                        .read<CompanyService>()
                        .checkInPassenger(bookingId);
                    if (success && mounted) {
                      setState(() {
                        pax['boarding_status'] = 'BOARDED';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã check-in cho khách: ${pax['name']}',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 4: QUẢN LÝ PHƠI HÀNG (CARGO LOGISTICS)
// =============================================================================
class _CargoTab extends StatefulWidget {
  const _CargoTab();

  @override
  State<_CargoTab> createState() => _CargoTabState();
}

class _CargoTabState extends State<_CargoTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _cargos = [];
  final NumberFormat _fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _loadCargos();
  }

  Future<void> _loadCargos() async {
    setState(() => _isLoading = true);
    final companyService = context.read<CompanyService>();
    final cargos = await companyService.getCargos();
    if (mounted) {
      setState(() {
        _cargos = cargos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _OperatorMainScreenState.bgOverall,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _OperatorMainScreenState.brandOrange,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_box),
        label: const Text(
          'Gửi hàng mới',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final created = await _showCreateCargoDialog(context);
          if (created == true) _loadCargos();
        },
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _OperatorMainScreenState.brandOrange),
            )
          : RefreshIndicator(
              onRefresh: _loadCargos,
              color: _OperatorMainScreenState.brandOrange,
              child: _cargos.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có kiện hàng ký gửi nào.',
                        style: TextStyle(color: _OperatorMainScreenState.textSub),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cargos.length,
                      itemBuilder: (ctx, idx) => _buildCargoCard(_cargos[idx]),
                    ),
            ),
    );
  }

  Widget _buildCargoCard(Map<String, dynamic> cargo) {
    final status = cargo['status'] ?? 'RECEIVED';
    final cost = cargo['cost'] ?? 0;
    final cod = cargo['cod_amount'] ?? 0;

    Color statusBg = _OperatorMainScreenState.warningOrangeLight;
    Color statusText = _OperatorMainScreenState.warningOrange;
    String statusLabel = 'Đã nhận tại kho';
    if (status == 'LOADED') {
      statusBg = const Color(0xFFEAF3FF);
      statusText = const Color(0xFF2878D0);
      statusLabel = 'Đã xếp lên xe';
    } else if (status == 'IN_TRANSIT') {
      statusBg = _OperatorMainScreenState.brandOrangeLight;
      statusText = _OperatorMainScreenState.brandOrangeDark;
      statusLabel = 'Đang vận chuyển';
    } else if (status == 'DELIVERED') {
      statusBg = _OperatorMainScreenState.successGreenLight;
      statusText = _OperatorMainScreenState.successGreen;
      statusLabel = 'Đã giao cho khách';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OperatorMainScreenState.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _OperatorMainScreenState.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _OperatorMainScreenState.brandOrangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      size: 18,
                      color: _OperatorMainScreenState.brandOrange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cargo['tracking_number'] ?? 'MÃ KIỆN',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _OperatorMainScreenState.textMain,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sender & Receiver
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Người gửi',
                      style: TextStyle(fontSize: 11, color: _OperatorMainScreenState.textSub),
                    ),
                    Text(
                      '${cargo['sender_name']} (${cargo['sender_phone']})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _OperatorMainScreenState.textMain,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16, color: _OperatorMainScreenState.textSub),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Người nhận',
                      style: TextStyle(fontSize: 11, color: _OperatorMainScreenState.textSub),
                    ),
                    Text(
                      '${cargo['receiver_name']} (${cargo['receiver_phone']})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _OperatorMainScreenState.textMain,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Description & Weight
          Text(
            'Hàng: ${cargo['description'] ?? "Hàng hóa"} • ${cargo['weight']} kg',
            style: const TextStyle(fontSize: 12, color: _OperatorMainScreenState.textSub),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _OperatorMainScreenState.borderSubtle),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cước: ${_fmt.format(cost)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _OperatorMainScreenState.brandOrange,
                    ),
                  ),
                  if (cod > 0)
                    Text(
                      'Thu hộ COD: ${_fmt.format(cod)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _OperatorMainScreenState.successGreen,
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: _OperatorMainScreenState.textSub),
                onSelected: (newStatus) async {
                  final cargoId = cargo['id'];
                  final ok = await context
                      .read<CompanyService>()
                      .updateCargoStatus(cargoId, newStatus);
                  if (ok && mounted) {
                    setState(() => cargo['status'] = newStatus);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'LOADED', child: Text('Đã xếp lên xe')),
                  PopupMenuItem(
                    value: 'IN_TRANSIT',
                    child: Text('Đang vận chuyển'),
                  ),
                  PopupMenuItem(
                    value: 'DELIVERED',
                    child: Text('Đã giao thành công'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 5: QUẢN LÝ XE & NHÂN SỰ (FLEET & CREW)
// =============================================================================
class _FleetStaffTab extends StatefulWidget {
  const _FleetStaffTab();

  @override
  State<_FleetStaffTab> createState() => _FleetStaffTabState();
}

class _FleetStaffTabState extends State<_FleetStaffTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _assistants = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFleetData();
  }

  Future<void> _loadFleetData() async {
    setState(() => _isLoading = true);
    final cs = context.read<CompanyService>();
    final buses = await cs.getBuses();
    final drivers = await cs.getStaff('DRIVER');
    final assistants = await cs.getStaff('ASSISTANT');
    if (mounted) {
      setState(() {
        _buses = buses;
        _drivers = drivers;
        _assistants = assistants;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Column(
      children: [
        Container(
          color: _OperatorMainScreenState.surfaceWhite,
          child: TabBar(
            controller: _tabController,
            indicatorColor: _OperatorMainScreenState.brandOrange,
            indicatorWeight: 3,
            labelColor: _OperatorMainScreenState.brandOrangeDark,
            unselectedLabelColor: _OperatorMainScreenState.textSub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.directions_bus, size: 20), text: 'Đội xe'),
              Tab(icon: Icon(Icons.badge, size: 20), text: 'Tài xế & Phụ xe'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _OperatorMainScreenState.brandOrange),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Sub Tab 1: Buses
                    Scaffold(
                      backgroundColor: _OperatorMainScreenState.bgOverall,
                      floatingActionButton: user?.canManageFleet == true
                          ? FloatingActionButton.extended(
                              backgroundColor: _OperatorMainScreenState.brandOrange,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Thêm xe mới',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final ok = await _showAddBusDialog(context);
                                if (ok == true) _loadFleetData();
                              },
                            )
                          : null,
                      body: _buses.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có thông tin xe khách nào.',
                                style: TextStyle(color: _OperatorMainScreenState.textSub),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _buses.length,
                              itemBuilder: (ctx, idx) =>
                                  _buildBusCard(_buses[idx]),
                            ),
                    ),
                    // Sub Tab 2: Drivers & Assistants
                    Scaffold(
                      backgroundColor: _OperatorMainScreenState.bgOverall,
                      floatingActionButton: user?.canManageStaff == true
                          ? FloatingActionButton.extended(
                              backgroundColor: _OperatorMainScreenState.brandOrange,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              icon: const Icon(Icons.person_add),
                              label: const Text(
                                'Thêm tài xế',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final ok = await _showAddStaffDialog(context);
                                if (ok == true) _loadFleetData();
                              },
                            )
                          : null,
                      body: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            'DANH SÁCH TÀI XẾ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _OperatorMainScreenState.textMain,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_drivers.isEmpty)
                            const Text(
                              'Chưa có tài xế nào.',
                              style: TextStyle(color: _OperatorMainScreenState.textSub),
                            )
                          else
                            ..._drivers.map(
                              (d) => _buildStaffCard(
                                d,
                                'Tài xế',
                                _OperatorMainScreenState.brandOrange,
                                _OperatorMainScreenState.brandOrangeLight,
                              ),
                            ),
                          const SizedBox(height: 20),
                          const Text(
                            'DANH SÁCH PHỤ XE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _OperatorMainScreenState.textMain,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_assistants.isEmpty)
                            const Text(
                              'Chưa có phụ xe nào.',
                              style: TextStyle(color: _OperatorMainScreenState.textSub),
                            )
                          else
                            ..._assistants.map(
                              (a) => _buildStaffCard(
                                a,
                                'Phụ xe',
                                const Color(0xFF2878D0),
                                const Color(0xFFEAF3FF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBusCard(Map<String, dynamic> bus) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OperatorMainScreenState.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _OperatorMainScreenState.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _OperatorMainScreenState.brandOrangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_bus,
              color: _OperatorMainScreenState.brandOrange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bus['license_plate'] ?? 'Biển số',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _OperatorMainScreenState.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bus['bus_type'] ?? "Xe khách"} • ${bus['total_seats']} chỗ',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _OperatorMainScreenState.textSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(
    Map<String, dynamic> staff,
    String roleLabel,
    Color color,
    Color bgLight,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _OperatorMainScreenState.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _OperatorMainScreenState.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: bgLight,
            child: Icon(Icons.person, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff['name'] ?? 'Nhân sự',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _OperatorMainScreenState.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SĐT: ${staff['phone'] ?? "N/A"}${staff['license_number'] != null ? " • Bằng: ${staff['license_number']}" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _OperatorMainScreenState.textSub,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODALS & DIALOGS
// =============================================================================

// 1. DIALOG TẠO CHUYẾN MỚI
Future<bool?> _showCreateTripDialog(BuildContext context) async {
  final user = context.read<AuthService>().currentUser;
  if (user?.canCreateTrip != true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quyền hạn bị từ chối: Tài xế / Phụ xe không có quyền tạo chuyến xe! Chỉ Quản trị viên hoặc Điều hành bến mới có quyền này.'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
  final companyService = context.read<CompanyService>();
  final routes = await companyService.getRoutes();
  final buses = await companyService.getBuses();
  final drivers = await companyService.getStaff('DRIVER');

  if (!context.mounted) return false;

  int? selectedRouteId = routes.isNotEmpty ? routes.first['id'] : null;
  int? selectedBusId = buses.isNotEmpty ? buses.first['id'] : null;
  int? selectedDriverId = drivers.isNotEmpty ? drivers.first['id'] : null;
  DateTime departureDate = DateTime.now().add(const Duration(hours: 3));
  TimeOfDay departureTime = TimeOfDay.fromDateTime(departureDate);

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tạo Chuyến Xe Mới',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _OperatorMainScreenState.textMain,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Chọn tuyến đường
                  const Text(
                    'Chọn Tuyến Đường',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _OperatorMainScreenState.textSub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedRouteId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _OperatorMainScreenState.bgOverall,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: routes.map((r) {
                      return DropdownMenuItem<int>(
                        value: r['id'],
                        child: Text(
                          '${r['start_point']} → ${r['end_point']}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setModalState(() => selectedRouteId = v),
                  ),
                  const SizedBox(height: 14),
                  // Chọn xe
                  const Text(
                    'Chọn Xe Khách',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _OperatorMainScreenState.textSub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedBusId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _OperatorMainScreenState.bgOverall,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: buses.map((b) {
                      return DropdownMenuItem<int>(
                        value: b['id'],
                        child: Text(
                          '${b['license_plate']} (${b['bus_type']} - ${b['total_seats']} chỗ)',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setModalState(() => selectedBusId = v),
                  ),
                  const SizedBox(height: 14),
                  // Chọn tài xế
                  const Text(
                    'Chọn Tài Xế',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _OperatorMainScreenState.textSub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedDriverId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _OperatorMainScreenState.bgOverall,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Chưa phân công tài xế'),
                      ),
                      ...drivers.map((d) {
                        return DropdownMenuItem<int>(
                          value: d['id'],
                          child: Text(
                            '${d['name']} (${d['phone']})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (v) => setModalState(() => selectedDriverId = v),
                  ),
                  const SizedBox(height: 14),
                  // Giờ xuất bến
                  const Text(
                    'Thời Gian Xuất Bến',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _OperatorMainScreenState.textSub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(departureDate),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: departureDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 60),
                              ),
                            );
                            if (d != null)
                              setModalState(() => departureDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            '${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}',
                          ),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: departureTime,
                            );
                            if (t != null)
                              setModalState(() => departureTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _OperatorMainScreenState.brandOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (selectedRouteId == null || selectedBusId == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vui lòng chọn đầy đủ Tuyến đường và Xe!',
                              ),
                            ),
                          );
                          return;
                        }
                        final combinedDt = DateTime(
                          departureDate.year,
                          departureDate.month,
                          departureDate.day,
                          departureTime.hour,
                          departureTime.minute,
                        );
                        final res = await companyService.createTrip(
                          routeId: selectedRouteId!,
                          busId: selectedBusId!,
                          driverId: selectedDriverId,
                          departureTime: DateFormat('yyyy-MM-dd HH:mm:ss')
                              .format(combinedDt),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx, res['success']);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message']),
                              backgroundColor: res['success']
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'XÁC NHẬN TẠO CHUYẾN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// 2. DIALOG TẠO ĐƠN GỬI HÀNG (CARGO)
Future<bool?> _showCreateCargoDialog(BuildContext context) async {
  final companyService = context.read<CompanyService>();
  final offices = await companyService.getOffices();
  final trips = await companyService.getTrips();

  if (!context.mounted) return false;

  final senderNameCtl = TextEditingController();
  final senderPhoneCtl = TextEditingController();
  final receiverNameCtl = TextEditingController();
  final receiverPhoneCtl = TextEditingController();
  final descCtl = TextEditingController();
  final weightCtl = TextEditingController(text: '5');
  final costCtl = TextEditingController(text: '80000');
  final codCtl = TextEditingController(text: '0');
  int? senderOfficeId = offices.isNotEmpty ? offices.first['id'] : null;
  int? receiverOfficeId = offices.length > 1
      ? offices[1]['id']
      : (offices.isNotEmpty ? offices.first['id'] : null);
  int? tripId = trips.isNotEmpty ? trips.first['id'] : null;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ký Gửi Hàng Hóa Mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _OperatorMainScreenState.textMain,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: senderNameCtl,
                      decoration: const InputDecoration(
                        labelText: 'Tên người gửi',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: senderPhoneCtl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'SĐT người gửi',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: receiverNameCtl,
                      decoration: const InputDecoration(
                        labelText: 'Tên người nhận',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: receiverPhoneCtl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'SĐT người nhận',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(
                  labelText: 'Mô tả hàng hóa (VD: Giấy tờ, Thùng trái cây)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weightCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cân nặng (kg)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: costCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cước phí (VNĐ)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: codCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'COD thu hộ',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _OperatorMainScreenState.brandOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (senderNameCtl.text.isEmpty ||
                        receiverNameCtl.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng nhập tên người gửi và người nhận!',
                          ),
                        ),
                      );
                      return;
                    }
                    final res = await companyService.createCargo({
                      'sender_name': senderNameCtl.text.trim(),
                      'sender_phone': senderPhoneCtl.text.trim(),
                      'receiver_name': receiverNameCtl.text.trim(),
                      'receiver_phone': receiverPhoneCtl.text.trim(),
                      'description': descCtl.text.trim(),
                      'weight_kg': weightCtl.text.trim(),
                      'cost': costCtl.text.trim(),
                      'cod_amount': codCtl.text.trim(),
                      'sender_office_id': senderOfficeId,
                      'receiver_office_id': receiverOfficeId,
                      'trip_id': tripId,
                      'payment_status': 'UNPAID',
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx, res['success']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message']),
                          backgroundColor: res['success']
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'XÁC NHẬN TẠO ĐƠN HÀNG',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// 3. DIALOG THÊM XE
Future<bool?> _showAddBusDialog(BuildContext context) async {
  final user = context.read<AuthService>().currentUser;
  if (user?.canManageFleet != true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quyền hạn bị từ chối: Chỉ Quản trị viên nhà xe mới có quyền thêm phương tiện!'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
  final cs = context.read<CompanyService>();
  final plateCtl = TextEditingController();
  final seatsCtl = TextEditingController(text: '34');
  String busType = 'Limousine 34 Phòng';

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Thêm Xe Mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: plateCtl,
              decoration: const InputDecoration(
                labelText: 'Biển số xe (VD: 51B-123.45)',
              ),
            ),
            TextField(
              controller: seatsCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tổng số ghế'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy', style: TextStyle(color: _OperatorMainScreenState.textSub)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _OperatorMainScreenState.brandOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            if (plateCtl.text.isEmpty) return;
            final res = await cs.createBus({
              'license_plate': plateCtl.text.trim(),
              'bus_type': busType,
              'total_seats': int.tryParse(seatsCtl.text) ?? 34,
            });
            if (ctx.mounted) Navigator.pop(ctx, res['success']);
          },
          child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// =============================================================================
// 4. DIALOG THÊM TÀI XẾ
Future<bool?> _showAddStaffDialog(BuildContext context) async {
  final user = context.read<AuthService>().currentUser;
  if (user?.canManageStaff != true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quyền hạn bị từ chối: Chỉ Quản trị viên nhà xe mới có quyền quản lý nhân sự / tài xế!'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
  final cs = context.read<CompanyService>();
  final nameCtl = TextEditingController();
  final phoneCtl = TextEditingController();
  final licenseCtl = TextEditingController();

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Thêm Tài Xế Mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Họ và tên tài xế'),
            ),
            TextField(
              controller: phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
            ),
            TextField(
              controller: licenseCtl,
              decoration: const InputDecoration(
                labelText: 'Số bằng lái / Hạng bằng',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy', style: TextStyle(color: _OperatorMainScreenState.textSub)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _OperatorMainScreenState.brandOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            if (nameCtl.text.isEmpty) return;
            final res = await cs.createStaff({
              'name': nameCtl.text.trim(),
              'phone': phoneCtl.text.trim(),
              'license_number': licenseCtl.text.trim(),
              'role': 'DRIVER',
              'type': 'driver',
            });
            if (ctx.mounted) Navigator.pop(ctx, res['success']);
          },
          child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// =============================================================================
// 5. TRUNG TÂM XỬ LÝ SỰ CỐ & CỨU VIỆN (INCIDENT & RESCUE COMMAND)
// =============================================================================

// 5.1. BÁO CÁO SỰ CỐ MỚI
Future<void> _showReportIncidentDialog(BuildContext context) async {
  final cs = context.read<CompanyService>();
  final trips = await cs.getTrips();
  if (!context.mounted) return;

  final activeTrips = trips.where((t) => t['status'] == 'Scheduled' || t['status'] == 'Running').toList();
  int? selectedTripId = activeTrips.isNotEmpty ? activeTrips.first['id'] : (trips.isNotEmpty ? trips.first['id'] : null);
  String selectedType = 'BREAKDOWN';
  final descCtl = TextEditingController();
  final locCtl = TextEditingController(text: 'Km 98 - Đèo Bảo Lộc');
  bool notifyPax = true;

  final typeLabels = {
    'BREAKDOWN': '🚗 Hỏng xe / nổ lốp / chết máy',
    'ACCIDENT': '💥 Tai nạn va chạm giao thông',
    'TRAFFIC': '🚦 Tắc đường / Sạt lở đèo nghiêm trọng',
    'DRIVER_UNABLE': '👨‍✈️ Tài xế kiệt sức / Đau ốm đột xuất',
    'OTHER': '⚠️ Sự cố vận hành khác',
  };

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setMState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
                            child: const Icon(Icons.report_problem, color: Colors.red, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Báo Cáo Sự Cố Chuyến Xe',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _OperatorMainScreenState.textMain),
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Chọn chuyến xe gặp sự cố:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _OperatorMainScreenState.textSub)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedTripId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _OperatorMainScreenState.bgOverall,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: trips.map((t) {
                      return DropdownMenuItem<int>(
                        value: t['id'],
                        child: Text(
                          '#${t['id']} | ${t['route']} (${t['bus']})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setMState(() => selectedTripId = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Loại sự cố:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _OperatorMainScreenState.textSub)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _OperatorMainScreenState.bgOverall,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: typeLabels.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (v) => setMState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtl,
                    decoration: const InputDecoration(
                      labelText: 'Vị trí hiện tại của xe',
                      hintText: 'Ví dụ: Đèo Bảo Lộc Km 98',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết tình trạng sự cố',
                      hintText: 'Ví dụ: Xe nổ lốp trước, máy sôi nước, cần xe cứu viện chở khách...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gửi thông báo tự động cho hành khách', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Hệ thống sẽ gửi thông báo khẩn để hành khách yên tâm', style: TextStyle(fontSize: 11)),
                    value: notifyPax,
                    activeColor: _OperatorMainScreenState.brandOrange,
                    onChanged: (v) => setMState(() => notifyPax = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _OperatorMainScreenState.brandOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (selectedTripId == null || descCtl.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Vui lòng chọn chuyến xe và nhập mô tả sự cố!')),
                          );
                          return;
                        }
                        final res = await cs.reportIncident(
                          tripId: selectedTripId!,
                          type: selectedType,
                          description: descCtl.text.trim(),
                          location: locCtl.text.trim(),
                          notifyPassengers: notifyPax,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message']),
                              backgroundColor: res['success'] ? Colors.green : Colors.red,
                            ),
                          );
                          if (res['success'] && context.mounted) {
                            _showResolveIncidentDialog(context, selectedTripId!, res['incident_id']);
                          }
                        }
                      },
                      child: const Text('GỬI BÁO CÁO & KÍCH HOẠT CỨU HỘ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// 5.2. DANH SÁCH TRUNG TÂM SỰ CỐ
Future<void> _showIncidentCenterDialog(BuildContext context) async {
  final cs = context.read<CompanyService>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: cs.getIncidents(),
        builder: (ctx, snapshot) {
          final incidents = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _OperatorMainScreenState.brandOrangeLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: _OperatorMainScreenState.brandOrangeDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trung Tâm Xử Lý Sự Cố',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _OperatorMainScreenState.textMain,
                                ),
                              ),
                              Text(
                                'Điều xe dự phòng & Sang khách khẩn cấp',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _OperatorMainScreenState.textSub,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _OperatorMainScreenState.textSub),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _OperatorMainScreenState.brandOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_alert, size: 16),
                          label: const Text('Báo sự cố mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showReportIncidentDialog(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('SỰ CỐ ĐANG GHI NHẬN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _OperatorMainScreenState.textSub, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: _OperatorMainScreenState.brandOrange))
                        : incidents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: _OperatorMainScreenState.successGreen, size: 56),
                                    const SizedBox(height: 12),
                                    const Text('Tất cả chuyến xe đều đang chạy an toàn!', style: TextStyle(fontWeight: FontWeight.bold, color: _OperatorMainScreenState.textMain)),
                                    const SizedBox(height: 4),
                                    const Text('Chưa có sự cố nào cần xử lý cứu hộ.', style: TextStyle(fontSize: 12, color: _OperatorMainScreenState.textSub)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: incidents.length,
                                itemBuilder: (ctx, idx) {
                                  final inc = incidents[idx];
                                  final isResolved = inc['status'] == 'RESOLVED';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isResolved ? _OperatorMainScreenState.bgOverall : _OperatorMainScreenState.alertSoftRed,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isResolved ? _OperatorMainScreenState.borderSubtle : _OperatorMainScreenState.alertBorderRed,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '#${inc['trip_id']} | ${inc['route']} (${inc['bus']})',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  color: _OperatorMainScreenState.textMain,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isResolved
                                                    ? _OperatorMainScreenState.successGreenLight
                                                    : _OperatorMainScreenState.alertSoftRed,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isResolved ? 'ĐÃ GIẢI QUYẾT' : '🚨 CẦN CỨU HỘ',
                                                style: TextStyle(
                                                  color: isResolved
                                                      ? _OperatorMainScreenState.successGreen
                                                      : _OperatorMainScreenState.alertTextRed,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Sự cố: ${inc['description']}', style: const TextStyle(fontSize: 12, color: _OperatorMainScreenState.textMain, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 14, color: _OperatorMainScreenState.alertTextRed),
                                            const SizedBox(width: 4),
                                            Text(inc['location'] ?? 'Chưa rõ', style: const TextStyle(fontSize: 11, color: _OperatorMainScreenState.textSub)),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.people, size: 14, color: Color(0xFF2878D0)),
                                            const SizedBox(width: 4),
                                            Text('${inc['pax_count']} khách trên xe', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2878D0))),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (!isResolved)
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _OperatorMainScreenState.brandOrange,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.car_crash, size: 15),
                                              label: const Text('Tìm xe dự phòng & Sang xe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _showResolveIncidentDialog(context, inc['trip_id'], inc['id']);
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// 5.3. ĐIỀU XE DỰ PHÒNG / CHUYỂN HÀNH KHÁCH
Future<void> _showResolveIncidentDialog(BuildContext context, int tripId, int? incidentId) async {
  final user = context.read<AuthService>().currentUser;
  if (user?.canDispatchRescue != true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quyền hạn bị từ chối: Chỉ Quản trị viên hoặc Điều hành bến mới có quyền ra quyết định điều xe cứu hộ!'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  final cs = context.read<CompanyService>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: cs.getIncidentReplacements(tripId),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(color: Colors.red)),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Không thể tải dữ liệu xe dự phòng.'),
            );
          }

          final availableBuses = (data['available_buses'] as List?) ?? [];
          final availableDrivers = (data['available_drivers'] as List?) ?? [];
          final candidateTrips = (data['candidate_trips'] as List?) ?? [];
          final tripInfo = data['trip'] ?? {};

          int? selectedBusId = availableBuses.isNotEmpty ? availableBuses.first['id'] : null;
          int? selectedDriverId = availableDrivers.isNotEmpty ? availableDrivers.first['id'] : null;
          int? selectedTargetTripId = candidateTrips.isNotEmpty ? candidateTrips.first['id'] : null;
          int selectedModeTab = 0;

          return StatefulBuilder(
            builder: (ctx, setRState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.8,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cứu Hộ & Điều Xe Khẩn Cấp',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _OperatorMainScreenState.textMain,
                                  ),
                                ),
                                Text(
                                  'Chuyến #${tripInfo['id']}: ${tripInfo['route']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _OperatorMainScreenState.textSub,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: _OperatorMainScreenState.textSub),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _OperatorMainScreenState.bgOverall,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _OperatorMainScreenState.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setRState(() => selectedModeTab = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedModeTab == 0
                                          ? _OperatorMainScreenState.brandOrangeLight
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: selectedModeTab == 0
                                          ? Border.all(
                                              color: _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '1. Điều Xe Dự Phòng',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: selectedModeTab == 0
                                              ? _OperatorMainScreenState.brandOrangeDark
                                              : _OperatorMainScreenState.textSub,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setRState(() => selectedModeTab = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedModeTab == 1
                                          ? _OperatorMainScreenState.brandOrangeLight
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: selectedModeTab == 1
                                          ? Border.all(
                                              color: _OperatorMainScreenState.brandOrange.withOpacity(0.3),
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '2. Sang Chuyến Khác',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: selectedModeTab == 1
                                              ? _OperatorMainScreenState.brandOrangeDark
                                              : _OperatorMainScreenState.textSub,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (selectedModeTab == 0) ...[
                          const Text('CHỌN XE DỰ PHÒNG (ĐANG RẢNH):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _OperatorMainScreenState.textSub)),
                          const SizedBox(height: 6),
                          if (availableBuses.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Hiện không còn xe dự phòng nào rảnh trong bán kính thời gian này. Vui lòng chuyển sang phương án 2 (Sang chuyến khác)!', style: TextStyle(fontSize: 12, color: Colors.brown)),
                            )
                          else
                            DropdownButtonFormField<int>(
                              value: selectedBusId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _OperatorMainScreenState.bgOverall,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: availableBuses.map((b) {
                                final isMatch = b['is_match_capacity'] == true;
                                return DropdownMenuItem<int>(
                                  value: b['id'],
                                  child: Text(
                                    '${b['license_plate']} (${b['bus_type']} - ${b['total_seats']} chỗ) ${isMatch ? "✓ Đủ chỗ" : "⚠️ Nhỏ hơn"}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isMatch ? Colors.green.shade800 : Colors.orange.shade800),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) => setRState(() => selectedBusId = v),
                            ),
                          const SizedBox(height: 14),
                          const Text('CHỌN TÀI XẾ DỰ PHÒNG (NẾU CẦN THAY):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _OperatorMainScreenState.textSub)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: selectedDriverId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: _OperatorMainScreenState.bgOverall,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<int>(value: null, child: Text('Giữ nguyên tài xế hiện tại')),
                              ...availableDrivers.map((d) {
                                return DropdownMenuItem<int>(
                                  value: d['id'],
                                  child: Text('${d['name']} (${d['phone']})', style: const TextStyle(fontSize: 13)),
                                );
                              }),
                            ],
                            onChanged: (v) => setRState(() => selectedDriverId = v),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_active, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hệ thống sẽ gửi thông báo tự động cho ${tripInfo['pax_count']} hành khách trên xe về biển số xe cứu viện mới.',
                                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _OperatorMainScreenState.brandOrange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: selectedBusId == null
                                  ? null
                                  : () async {
                                      final res = await cs.resolveIncidentTransfer(
                                        tripId: tripId,
                                        incidentId: incidentId,
                                        mode: 'REPLACE_VEHICLE',
                                        newBusId: selectedBusId,
                                        newDriverId: selectedDriverId,
                                      );
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res['message']),
                                            backgroundColor: res['success'] ? _OperatorMainScreenState.successGreen : _OperatorMainScreenState.alertTextRed,
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('XÁC NHẬN ĐIỀU XE & THÔNG BÁO CHO KHÁCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ] else ...[
                          const Text('CHỌN CHUYẾN XE CÙNG TUYẾN ĐỂ SANG KHÁCH:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _OperatorMainScreenState.textSub)),
                          const SizedBox(height: 6),
                          if (candidateTrips.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Không tìm thấy chuyến xe nào khác cùng tuyến trong ngày còn ghế trống!', style: TextStyle(fontSize: 12, color: Colors.brown)),
                            )
                          else
                            DropdownButtonFormField<int>(
                              value: selectedTargetTripId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _OperatorMainScreenState.bgOverall,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: candidateTrips.map((ct) {
                                final time = ct['departure_time'].toString().substring(11, 16);
                                return DropdownMenuItem<int>(
                                  value: ct['id'],
                                  child: Text(
                                    '#${ct['id']} ($time) - ${ct['bus']} • Còn ${ct['available_seats']} ghế trống',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) => setRState(() => selectedTargetTripId = v),
                            ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.transfer_within_a_station, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Toàn bộ ${tripInfo['pax_count']} vé của chuyến cũ sẽ được chuyển sang chuyến xe mới và tự động gửi thông báo cập nhật cho từng khách.',
                                    style: const TextStyle(fontSize: 12, color: Colors.brown),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _OperatorMainScreenState.brandOrange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: selectedTargetTripId == null
                                  ? null
                                  : () async {
                                      final res = await cs.resolveIncidentTransfer(
                                        tripId: tripId,
                                        incidentId: incidentId,
                                        mode: 'TRANSFER_PASSENGERS',
                                        targetTripId: selectedTargetTripId,
                                      );
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res['message']),
                                            backgroundColor: res['success'] ? Colors.green : Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('CHUYỂN KHÁCH SANG CHUYẾN MỚI & BÁO KHÁCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
