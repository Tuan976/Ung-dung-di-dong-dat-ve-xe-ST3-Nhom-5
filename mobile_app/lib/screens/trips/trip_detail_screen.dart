import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../core/constants/app_colors.dart';
import '../../services/trip_service.dart';
import '../../services/map_booking_service.dart';
import '../../models/trip.dart';
import '../../models/map_station.dart';
import '../../widgets/shared_components.dart';

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
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Chi tiết chuyến xe',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: FutureBuilder<Trip>(
        future: _futureTrip,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Không tìm thấy thông tin chuyến xe',
              description: 'Chuyến xe này có thể đã ngừng nhận khách hoặc không tồn tại.',
              buttonText: 'Quay lại',
              onButtonPressed: () => context.pop(),
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
                      AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                trip.companyName.isNotEmpty
                                    ? trip.companyName.substring(0, math.min(2, trip.companyName.length)).toUpperCase()
                                    : 'TR',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.companyName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '4.8',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${trip.busType}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: 'Còn ${trip.availableSeats} chỗ',
                              type: trip.availableSeats <= 5 ? BadgeType.warning : BadgeType.success,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Map Preview
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        height: 185,
                        child: _buildMap(trip),
                      ),
                      const SizedBox(height: 14),

                      // Map stops selector
                      _buildMapStopsPickerCard(trip),
                      const SizedBox(height: 14),

                      // Itinerary Card
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lộ trình di chuyển',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTimelineStep(
                              time: trip.departureTime,
                              station: _pickupStop?.name ?? trip.departureStation,
                              address: _pickupStop?.address ?? 'Bến xe ${trip.departureStation}',
                              isFirst: true,
                              isLast: false,
                              color: AppColors.primary,
                            ),
                            _buildTimelineStep(
                              time: trip.arrivalTime.isNotEmpty ? trip.arrivalTime : 'Dự kiến',
                              station: _dropoffStop?.name ?? trip.arrivalStation,
                              address: _dropoffStop?.address ?? 'Bến xe ${trip.arrivalStation}',
                              isFirst: false,
                              isLast: true,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Amenities Card
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tiện ích trên xe',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildAmenity(Icons.wifi_rounded, 'WiFi tốc độ cao'),
                                _buildAmenity(Icons.ac_unit_rounded, 'Điều hòa'),
                                _buildAmenity(Icons.water_drop_outlined, 'Khăn & Nước'),
                                _buildAmenity(Icons.usb_rounded, 'Cổng sạc USB'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Policies Card
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chính sách chuyến xe',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildPolicy(
                              Icons.verified_user_outlined,
                              'Hỗ trợ đổi / hủy vé linh hoạt trước giờ khởi hành',
                              AppColors.success,
                            ),
                            const SizedBox(height: 10),
                            _buildPolicy(
                              Icons.luggage_outlined,
                              'Miễn phí hành lý xách tay & ký gửi tối đa 20kg/khách',
                              AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky Bottom Bar
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
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Giá vé (1 hành khách)',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fmt.format(trip.price),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      PrimaryButton(
                        text: 'Chọn ghế',
                        icon: Icons.event_seat_rounded,
                        width: 160,
                        height: 48,
                        onPressed: () => context.push('/seat_selection', extra: {
                          'trip': trip,
                          'pickup': _pickupStop != null ? '${_pickupStop!.name} (${_pickupStop!.address})' : null,
                          'dropoff': _dropoffStop != null ? '${_dropoffStop!.name} (${_dropoffStop!.address})' : null,
                          'pickup_station_id': _pickupStop?.id,
                          'dropoff_station_id': _dropoffStop?.id,
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
    return const LatLng(16.0, 106.0);
  }

  Widget _buildMap(Trip trip) {
    final depCoords = _pickupStop?.coordinates ?? _getCoords(trip.departureStation);
    final arrCoords = _dropoffStop?.coordinates ?? _getCoords(trip.arrivalStation);

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
              urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              subdomains: const ['0', '1', '2', '3'],
              userAgentPackageName: 'com.nhom5.vexemobile',
              maxZoom: 20,
            ),
            PolylineLayer(
              polylines: [
                if (polylinePoints.length > 2)
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 5.0,
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                Polyline(
                  points: polylinePoints,
                  strokeWidth: 3.5,
                  color: AppColors.primary,
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
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 17),
                  ),
                ),
                Marker(
                  point: arrCoords,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fullscreen_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Xem bản đồ lớn',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.map_rounded, size: 19, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Điểm đón / trả trên bản đồ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () => _openFullMapBooking(trip),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 14),
                  label: Text(
                    hasStops ? 'Đổi trạm' : 'Chọn trạm',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Điểm đón khách:',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _pickupStop != null ? _pickupStop!.name : 'Bến xe ${trip.departureStation} (Mặc định)',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (_pickupStop != null && _pickupStop!.address.isNotEmpty)
                      Text(_pickupStop!.address, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: SizedBox(
              height: 12,
              child: VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Điểm trả khách:',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _dropoffStop != null ? _dropoffStop!.name : 'Bến xe ${trip.arrivalStation} (Mặc định)',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (_dropoffStop != null && _dropoffStop!.address.isNotEmpty)
                      Text(_dropoffStop!.address, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
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
                  Container(width: 1.5, height: 14, color: AppColors.border),
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
                    child: Container(width: 1.5, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$time • $station',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
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
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicy(IconData icon, String label, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
