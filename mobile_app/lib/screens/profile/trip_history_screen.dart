import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/shared_components.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  int _selectedMonthIndex = 0;
  final List<DateTime> _months = [];

  bool _isLoading = true;
  List<dynamic> _allBookings = [];

  final _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _generateMonths();
    _loadBookings();
  }

  void _generateMonths() {
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      _months.add(DateTime(now.year, now.month - i, 1));
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get('/api/v1/bookings', queryParameters: {
        'limit': 100,
      });
      if (response.statusCode == 200 && response.data['success']) {
        setState(() {
          _allBookings = response.data['data']['items'];
        });
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> _getFilteredBookings() {
    final selectedDate = _months[_selectedMonthIndex];
    return _allBookings.where((b) {
      final tripDate = DateTime.parse(b['trip']['departure_time']).toLocal();
      return tripDate.month == selectedDate.month && tripDate.year == selectedDate.year;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBookings = _getFilteredBookings();

    int totalTrips = filteredBookings.length;
    double totalSpent = 0;
    for (var b in filteredBookings) {
      if (b['status'] != 'CANCELLED' && b['status'] != 'HOLD') {
        totalSpent += (b['ticket_price'] ?? 0).toDouble();
      }
    }

    final currencyFormatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

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
          'Lịch sử chuyến đi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // Month Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _months.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedMonthIndex == index;
                  final monthDate = _months[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMonthIndex = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tháng ${monthDate.month}/${monthDate.year}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary Card (Clean Orange & White Triply style)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 21),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tổng số chuyến',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$totalTrips chuyến đi',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Tổng chi tiêu',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormatter.format(totalSpent),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (filteredBookings.isEmpty)
                        EmptyStateWidget(
                          icon: Icons.history_rounded,
                          title: 'Chưa có chuyến đi nào trong tháng này',
                          description: 'Chọn tháng khác hoặc bắt đầu hành trình mới cùng Triply.',
                          buttonText: 'Đặt vé ngay',
                          onButtonPressed: () => context.go('/home'),
                        )
                      else
                        ...filteredBookings.map((b) {
                          final trip = b['trip'];
                          final depDate = DateTime.parse(trip['departure_time']).toLocal();
                          final formattedDate = DateFormat('HH:mm • dd/MM/yyyy').format(depDate);

                          String statusText = 'Đã đặt';
                          BadgeType badgeType = BadgeType.primary;

                          if (b['status'] == 'COMPLETED') {
                            statusText = 'Hoàn thành';
                            badgeType = BadgeType.success;
                          } else if (b['status'] == 'CANCELLED') {
                            statusText = 'Đã hủy';
                            badgeType = BadgeType.error;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTripCard(
                              route: '${trip['start_point']} → ${trip['end_point']}',
                              company: trip['company_name'] ?? 'Nhà xe Triply',
                              date: formattedDate,
                              price: currencyFormatter.format(b['ticket_price'] ?? 0),
                              status: statusText,
                              badgeType: badgeType,
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard({
    required String route,
    required String company,
    required String date,
    required String price,
    required String status,
    required BadgeType badgeType,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nhà xe: $company',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Khởi hành: $date',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(label: status, type: badgeType),
                  const SizedBox(height: 12),
                  Text(
                    price,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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
