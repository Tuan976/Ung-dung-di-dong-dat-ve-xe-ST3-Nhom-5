import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  int _selectedMonthIndex = 0;
  List<DateTime> _months = [];
  
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
    
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
          'Lịch sử chuyến đi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
              height: 32,
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
                        color: isSelected ? const Color(0xFF00639B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF00639B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tháng ${monthDate.month}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00639B)))
                : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tổng chuyến đi',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalTrips Chuyến',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Tổng chi tiêu',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormatter.format(totalSpent),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filteredBookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text(
                        'Không có chuyến đi nào trong tháng này',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  ...filteredBookings.map((b) {
                    final trip = b['trip'];
                    final depDate = DateTime.parse(trip['departure_time']).toLocal();
                    final formattedDate = DateFormat('dd/MM/yyyy').format(depDate);
                    
                    String statusText = 'Đã đặt';
                    Color statusColor = const Color(0xFF00639B);
                    Color statusBg = const Color(0xFFE0F2FE);
                    
                    if (b['status'] == 'COMPLETED') {
                      statusText = 'Hoàn thành';
                      statusColor = const Color(0xFF059669);
                      statusBg = const Color(0xFFD1FAE5);
                    } else if (b['status'] == 'CANCELLED') {
                      statusText = 'Đã huỷ';
                      statusColor = const Color(0xFFEF4444);
                      statusBg = const Color(0xFFFEE2E2);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTripCard(
                        route: '${trip['start_point']} → ${trip['end_point']}',
                        company: trip['company_name'] ?? 'Chưa rõ',
                        date: formattedDate,
                        price: currencyFormatter.format(b['ticket_price'] ?? 0),
                        status: statusText,
                        statusColor: statusColor,
                        statusBg: statusBg,
                        hasReviewed: false, // You can extend this logic if API supports reviews
                      ),
                    );
                  }).toList(),
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
    required Color statusColor,
    required Color statusBg,
    required bool hasReviewed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nhà xe: $company',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Khởi hành: $date',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      price,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasReviewed) ...[
                  Row(
                    children: List.generate(5, (index) {
                      return const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(Icons.star_border, color: Color(0xFFF59E0B), size: 16),
                      );
                    }),
                  ),
                  const Text(
                    'Cám ơn bạn đã đánh giá',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ] else ...[
                  const Text(
                    'Chưa có đánh giá',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF00639B)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Đánh giá',
                      style: TextStyle(
                        color: Color(0xFF00639B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
