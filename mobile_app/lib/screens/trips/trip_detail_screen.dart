import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../services/trip_service.dart';
import '../../services/map_booking_service.dart';
import '../../models/booking_strategy.dart';
import '../../models/trip.dart';
import '../../models/map_station.dart';

class TripDetailScreen extends StatefulWidget {
  final int tripId;
  final MapStation? pickupStop;
  final MapStation? dropoffStop;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.pickupStop,
    this.dropoffStop,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<Trip> _futureTrip;
  MapStation? _pickupStop;
  MapStation? _dropoffStop;
  RouteMapData? _routeMapData;

  @override
  void initState() {
    super.initState();
    _pickupStop = widget.pickupStop;
    _dropoffStop = widget.dropoffStop;
    _futureTrip = context.read<TripService>().getTripDetails(widget.tripId);
    _loadRouteMap();
  }

  Future<void> _loadRouteMap() async {
    try {
      final trip = await _futureTrip;
      final strategy = await MapBookingService().getRouteStrategy(
        from: trip.departureStation,
        to: trip.arrivalStation,
      );
      if (strategy.hasMapConfig && strategy.routeId != null) {
        final data = await MapBookingService().getRouteStops(
          routeId: strategy.routeId!,
          direction: strategy.direction,
        );
        if (mounted && data != null) {
          setState(() {
            _routeMapData = data;
            _pickupStop ??= (data.pickupStops.isNotEmpty ? data.pickupStops.first : null);
            _dropoffStop ??= (data.dropoffStops.isNotEmpty ? data.dropoffStops.first : null);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openFullMapBooking(Trip trip) async {
    final strategy = await MapBookingService().getRouteStrategy(
      from: trip.departureStation,
      to: trip.arrivalStation,
    );
    final routeId = strategy.routeId ?? 'sg_cj';
    final direction = strategy.direction;

    final result = await context.push<Map<String, dynamic>>(
      '/map_booking?route_id=$routeId&direction=$direction&from=${Uri.encodeComponent(trip.departureStation)}&to=${Uri.encodeComponent(trip.arrivalStation)}&date=${trip.departureDate}&passengers=1&caller=trip_detail',
    );

    if (result != null && mounted) {
      setState(() {
        if (result['pickup_stop'] is MapStation) {
          _pickupStop = result['pickup_stop'] as MapStation;
        }
        if (result['dropoff_stop'] is MapStation) {
          _dropoffStop = result['dropoff_stop'] as MapStation;
        }
      });
    }
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
                      
                      // Real Map (OpenStreetMap with real road polyline)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 190,
                          child: _buildMap(trip),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card Chọn điểm đón & trả khách trên bản đồ
                      _buildMapStopsPickerCard(trip),
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
                              station: _pickupStop?.name ?? trip.departureStation,
                              address: _pickupStop?.address ?? 'Bến xe ${trip.departureStation}',
                              isFirst: true,
                              isLast: false,
                              color: const Color(0xFF0F172A),
                            ),
                            _buildTimelineStep(
                              time: trip.arrivalTime.isNotEmpty ? trip.arrivalTime : 'Dự kiến',
                              station: _dropoffStop?.name ?? trip.arrivalStation,
                              address: _dropoffStop?.address ?? 'Bến xe ${trip.arrivalStation}',
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
                      onPressed: () => context.push('/seat_selection', extra: {
                        'trip': trip,
                        'pickup': _pickupStop != null ? '${_pickupStop!.name} (${_pickupStop!.address})' : null,
                        'dropoff': _dropoffStop != null ? '${_dropoffStop!.name} (${_dropoffStop!.address})' : null,
                        'pickup_station_id': _pickupStop?.id,
                        'dropoff_station_id': _dropoffStop?.id,
                      }),
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
    final depCoords = _pickupStop?.coordinates ?? _getCoords(trip.departureStation);
    final arrCoords = _dropoffStop?.coordinates ?? _getCoords(trip.arrivalStation);

    // Dùng polyline thực tế từ _routeMapData nếu có, ngược lại dùng tọa độ trạm
    final polylinePoints = _routeMapData != null && _routeMapData!.polyline.isNotEmpty
        ? _routeMapData!.polyline
        : <LatLng>[depCoords, arrCoords];

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in polylinePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = math.max(latDiff, lngDiff);
    double zoom = 7.0;
    if (maxDiff > 8.0) {
      zoom = 5.5;
    } else if (maxDiff > 4.0) {
      zoom = 6.4;
    } else if (maxDiff > 2.0) {
      zoom = 7.5;
    } else if (maxDiff > 1.0) {
      zoom = 8.5;
    } else {
      zoom = 10.0;
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            minZoom: 4.5,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nhom5.vexemobile',
              maxZoom: 19,
            ),
            if (polylinePoints.length > 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 5.0,
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                  ),
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 3.5,
                    color: const Color(0xFFFF6B00),
                  ),
                ],
              )
            else
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 3.0,
                    color: const Color(0xFFFF6B00),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: depCoords,
                  width: 38,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18),
                  ),
                ),
                Marker(
                  point: arrCoords,
                  width: 38,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 10,
          right: 10,
          child: InkWell(
            onTap: () => _openFullMapBooking(trip),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFFFF6B00)),
                  SizedBox(width: 4),
                  Text(
                    'Xem bản đồ lớn',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapStopsPickerCard(Trip trip) {
    final hasStops = _pickupStop != null || _dropoffStop != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withValues(alpha: 0.05),
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
              Row(
                children: const [
                  Icon(Icons.map_rounded, size: 20, color: Color(0xFFFF6B00)),
                  SizedBox(width: 8),
                  Text(
                    'Điểm đón / trả trên bản đồ',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openFullMapBooking(trip),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 14),
                label: Text(hasStops ? 'Đổi trạm' : 'Chọn trạm', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Điểm đón
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Điểm đón khách:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(
                      _pickupStop != null ? _pickupStop!.name : 'Bến xe ${trip.departureStation} (Mặc định)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    if (_pickupStop != null && _pickupStop!.address.isNotEmpty)
                      Text(_pickupStop!.address, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: SizedBox(
              height: 12,
              child: VerticalDivider(width: 1, thickness: 1, color: Color(0xFFCBD5E1)),
            ),
          ),
          // Điểm trả
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B00),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Điểm trả khách:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(
                      _dropoffStop != null ? _dropoffStop!.name : 'Bến xe ${trip.arrivalStation} (Mặc định)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    if (_dropoffStop != null && _dropoffStop!.address.isNotEmpty)
                      Text(_dropoffStop!.address, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
