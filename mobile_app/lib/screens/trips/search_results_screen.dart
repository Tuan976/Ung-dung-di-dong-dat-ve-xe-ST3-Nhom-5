import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/trip_service.dart';
import '../../models/trip.dart';

class SearchResultsScreen extends StatefulWidget {
  final String from;
  final String to;
  final String date;

  const SearchResultsScreen({
    super.key,
    required this.from,
    required this.to,
    required this.date,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Future<List<Trip>> _futureTrips;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  void _loadTrips() {
    _futureTrips = context.read<TripService>().searchTrips(
          from: widget.from,
          to: widget.to,
          date: widget.date,
        );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.my_location, size: 14, color: Color(0xFF00639B)),
                                const SizedBox(width: 4),
                                Text(widget.from,
                                    style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.arrow_forward, size: 14, color: Color(0xFF94A3B8)),
                                ),
                                const Icon(Icons.location_on, size: 14, color: Color(0xFFEF4444)),
                                const SizedBox(width: 4),
                                Text(widget.to,
                                    style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatDate(widget.date)} • Một chiều',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: FutureBuilder<List<Trip>>(
                future: _futureTrips,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF0B192C)));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(36)),
                              child: const Icon(Icons.wifi_off, size: 36, color: Color(0xFFDC2626)),
                            ),
                            const SizedBox(height: 16),
                            const Text('Không thể tải dữ liệu',
                                style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => setState(_loadTrips),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Thử lại'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B192C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(44)),
                            child: const Icon(Icons.directions_bus_outlined, size: 44, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 16),
                          const Text('Không tìm thấy chuyến xe',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          const Text('Thử chọn ngày hoặc tuyến khác',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B192C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: const Text('Quay lại'),
                          ),
                        ],
                      ),
                    );
                  }

                  final trips = snapshot.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final isLowSeat = trip.availableSeats <= 5;
                      return GestureDetector(
                        onTap: () => context.push('/trip/${trip.id}'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: const Color(0x0A0F172A), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Company + price
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(trip.companyName,
                                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w800)),
                                    ),
                                    Text(
                                      fmt.format(trip.price),
                                      style: const TextStyle(color: Color(0xFF00639B), fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Time row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(trip.departureTime,
                                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 2),
                                        Text(trip.departureStation,
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      ],
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 8),
                                            height: 1,
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                          const SizedBox(height: 2),
                                          const Icon(Icons.directions_bus, size: 16, color: Color(0xFF94A3B8)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(trip.arrivalTime.isNotEmpty ? trip.arrivalTime : '--:--',
                                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 2),
                                        Text(trip.arrivalStation,
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 10),
                                // Bus type + available seats
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(trip.busType,
                                          style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isLowSeat ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Còn ${trip.availableSeats} chỗ',
                                        style: TextStyle(
                                          color: isLowSeat ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
