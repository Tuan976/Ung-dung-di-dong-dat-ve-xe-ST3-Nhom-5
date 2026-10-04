import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/trip_service.dart';
import '../../models/trip.dart';

class TripDetailScreen extends StatefulWidget {
  final int tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<Trip> _futureTrip;

  @override
  void initState() {
    super.initState();
    _futureTrip = context.read<TripService>().getTripDetails(widget.tripId);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Chi tiết chuyến đi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder<Trip>(
        future: _futureTrip,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0B192C)));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                  const SizedBox(height: 16),
                  const Text('Không tìm thấy chuyến xe',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B192C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            );
          }

          final trip = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Company Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                trip.companyName.isNotEmpty ? trip.companyName.substring(0, 2).toUpperCase() : 'HA',
                                style: const TextStyle(
                                  color: Color(0xFF00639B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.companyName,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: const [
                                      Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        '4.8',
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '(320 đánh giá)',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Real Map (OpenStreetMap via flutter_map)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 180,
                          child: _buildMap(trip),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Itinerary Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hành trình',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTimelineStep(
                              time: trip.departureTime,
                              station: trip.departureStation,
                              address: 'Bến xe trung tâm, ${trip.departureStation}', // Mock address
                              isFirst: true,
                              isLast: false,
                              color: const Color(0xFF0F172A),
                            ),
                            _buildTimelineStep(
                              time: trip.arrivalTime.isNotEmpty ? trip.arrivalTime : 'Dự kiến 2h',
                              station: trip.arrivalStation,
                              address: 'Bến xe trung tâm, ${trip.arrivalStation}', // Mock address
                              isFirst: false,
                              isLast: true,
                              color: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amenities Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tiện ích chuyến xe',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildAmenity(Icons.wifi, 'WiFi miễn phí'),
                                _buildAmenity(Icons.ac_unit, 'Điều hòa'),
                                _buildAmenity(Icons.water_drop_outlined, 'Nước uống'),
                                _buildAmenity(Icons.cancel_presentation, 'Chăn gối'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Policies Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chính sách & Quy định',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPolicy(Icons.verified_user_outlined, 'Chính sách hủy vé: Miễn phí trước 24 giờ', const Color(0xFF10B981)),
                            const SizedBox(height: 12),
                            _buildPolicy(Icons.luggage_outlined, 'Hành lý tối đa: 20kg/khách', const Color(0xFF0F172A)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Bottom CTA
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFF3B82F6),
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng cộng (1 vé)',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fmt.format(trip.price),
                          style: const TextStyle(
                            color: Color(0xFF00639B),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/seat_selection', extra: trip),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B192C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: const Text('Chọn ghế',
                          style: TextStyle(fontSize: 15, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Map coordinates for major Vietnamese cities
  static const Map<String, LatLng> _cityCoords = {
    'Hà Nội': LatLng(21.0285, 105.8542),
    'Hà nội': LatLng(21.0285, 105.8542),
    'Hải Phòng': LatLng(20.8449, 106.6881),
    'TP. Hồ Chí Minh': LatLng(10.8231, 106.6297),
    'Hồ Chí Minh': LatLng(10.8231, 106.6297),
    'Đà Nẵng': LatLng(16.0544, 108.2022),
    'Đà Lạt': LatLng(11.9404, 108.4583),
    'Nha Trang': LatLng(12.2388, 109.1967),
    'Huế': LatLng(16.4637, 107.5909),
    'Cần Thơ': LatLng(10.0452, 105.7469),
    'Vũng Tàu': LatLng(10.3460, 107.0843),
    'Đồng Nai': LatLng(10.9457, 106.8243),
    'Bình Dương': LatLng(11.3254, 106.4772),
    'Quảng Ninh': LatLng(21.0064, 107.2925),
    'Hạ Long': LatLng(20.9517, 107.0770),
    'Cư Jut': LatLng(12.6718, 107.8428),
  };

  LatLng _getCoords(String city) {
    for (final entry in _cityCoords.entries) {
      if (city.toLowerCase().contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(city.toLowerCase())) {
        return entry.value;
      }
    }
    return const LatLng(16.0, 106.0); // Default: center of Vietnam
  }

  Widget _buildMap(Trip trip) {
    final depCoords = _getCoords(trip.departureStation);
    final arrCoords = _getCoords(trip.arrivalStation);

    final centerLat = (depCoords.latitude + arrCoords.latitude) / 2;
    final centerLng = (depCoords.longitude + arrCoords.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 6.5,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.mobile_app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [depCoords, arrCoords],
              strokeWidth: 3.0,
              color: const Color(0xFF00639B),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: depCoords,
              width: 36,
              height: 36,
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle),
                child: const Icon(Icons.circle, color: Colors.white, size: 12),
              ),
            ),
            Marker(
              point: arrCoords,
              width: 36,
              height: 36,
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String time,
    required String station,
    required String address,
    required bool isFirst,
    required bool isLast,
    required Color color,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: const Color(0xFFE2E8F0)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$time • $station',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenity(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0F172A), size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicy(IconData icon, String label, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
