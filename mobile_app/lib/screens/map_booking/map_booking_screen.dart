import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../models/map_station.dart';
import '../../models/booking_strategy.dart';
import '../../services/map_booking_service.dart';

/// Màn hình đặt vé theo bản đồ tương tác dùng chung cho TẤT CẢ các tuyến xe
/// Hỗ trợ: Chọn trạm đón/trả, tối ưu định tuyến (Dijkstra/OSRM), GPS định vị, Fit Bounds, Search
class MapBookingScreen extends StatefulWidget {
  final String? routeId;
  final String? initialDirection; // 'forward' hoặc 'reverse'
  final String? initialFrom;
  final String? initialTo;
  final String? initialDate;
  final int? initialPassengerCount;
  final String? caller;

  const MapBookingScreen({
    super.key,
    this.routeId,
    this.initialDirection,
    this.initialFrom,
    this.initialTo,
    this.initialDate,
    this.initialPassengerCount,
    this.caller,
  });

  @override
  State<MapBookingScreen> createState() => _MapBookingScreenState();
}

class _MapBookingScreenState extends State<MapBookingScreen> with TickerProviderStateMixin {
  final MapBookingService _service = MapBookingService();
  final MapController _mapController = MapController();
  final ScrollController _cardsScrollController = ScrollController();

  // Màu thương hiệu cam đặc trưng #FF6B00
  static const Color brandOrange = Color(0xFFFF6B00);
  static const Color darkPrimary = Color(0xFF0B192C);
  static const Color neutralBg = Color(0xFFF8FAFC);

  // Trạng thái bước: 1: Xem lộ trình, 2: Chọn điểm đón, 3: Chọn điểm đến, 4: Xác nhận
  int _currentStep = 1;

  // Hướng di chuyển: 'forward' hoặc 'reverse'
  String _direction = 'forward';
  String _routeId = 'sg_cj';
  String _routeName = 'Sài Gòn ↔ Cư Jút';
  String _highway = 'Quốc lộ Việt Nam';
  double _distanceKm = 300.0;
  String _estimatedDuration = '6 giờ 00 phút';

  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  int _passengerCount = 1;

  bool _isLoading = true;

  // Trạng thái xác thực Route Guard
  bool _isCheckingRouteGuard = true;
  bool _isRouteValidForMap = true;
  String? _routeGuardErrorMessage;

  // Chế độ tối ưu định tuyến: 'transit_route', 'fastest', 'shortest'
  String _optimizationMode = 'transit_route';
  bool _isCalculatingRoute = false;

  // Dữ liệu trạm và lộ trình động
  List<MapStation> _pickupStops = [];
  List<MapStation> _dropoffStops = [];
  List<MapStation> _restStops = [];
  List<LatLng> _routePolyline = [];

  String _departureArea = 'Điểm đi';
  String _destinationArea = 'Điểm đến';
  String _dbOrigin = 'TP. Hồ Chí Minh';
  String _dbDestination = 'Cư Jut';

  // Điểm đã chọn
  MapStation? _selectedPickup;
  MapStation? _selectedDropoff;

  // Vị trí người dùng
  Position? _userPosition;
  bool _isLocatingUser = false;

  // Bộ lọc tìm kiếm trạm
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();

    if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
      try {
        _departureDate = DateTime.parse(widget.initialDate!);
      } catch (_) {}
    }
    if (widget.initialPassengerCount != null && widget.initialPassengerCount! > 0) {
      _passengerCount = widget.initialPassengerCount!;
    }
    if (widget.initialDirection != null && widget.initialDirection!.isNotEmpty) {
      _direction = widget.initialDirection!;
    }

    _checkRouteGuardAndInit();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cardsScrollController.dispose();
    super.dispose();
  }

  /// Khởi tạo và kiểm tra Route Guard với Backend
  Future<void> _checkRouteGuardAndInit() async {
    setState(() => _isCheckingRouteGuard = true);

    try {
      final strategy = await _service.getRouteStrategy(
        from: widget.initialFrom,
        to: widget.initialTo,
        routeId: widget.routeId,
      );

      if (!mounted) return;

      if (strategy.mode == BookingMode.standard || !strategy.hasMapConfig) {
        setState(() {
          _isCheckingRouteGuard = false;
          _isRouteValidForMap = false;
          _routeGuardErrorMessage = strategy.message ??
              'Tuyến đường này chưa được cấu hình đặt vé qua bản đồ. Bạn có thể sử dụng phương thức tìm chuyến phổ thông.';
        });
        return;
      }

      _routeId = strategy.routeId ?? widget.routeId ?? 'sg_cj';
      _direction = (widget.initialDirection != null && widget.initialDirection!.isNotEmpty)
          ? widget.initialDirection!
          : strategy.direction;

      await _loadRouteStopsAndPolyline();
    } catch (e) {
      debugPrint('Lỗi khởi tạo Route Guard: $e');
      if (mounted) {
        setState(() {
          _isCheckingRouteGuard = false;
          _isRouteValidForMap = true;
        });
        await _loadRouteStopsAndPolyline();
      }
    }
  }

  /// Tải dữ liệu trạm dừng và đường đi thực tế từ API Backend
  Future<void> _loadRouteStopsAndPolyline() async {
    setState(() => _isLoading = true);

    try {
      final data = await _service.getRouteStops(
        routeId: _routeId,
        direction: _direction,
      );

      if (!mounted) return;

      if (data != null) {
        setState(() {
          _routeName = data.routeName;
          _departureArea = data.departureArea;
          _destinationArea = data.destinationArea;
          _dbOrigin = data.dbOrigin;
          _dbDestination = data.dbDestination;
          _pickupStops = data.pickupStops;
          _dropoffStops = data.dropoffStops;
          _restStops = data.restStops;
          _routePolyline = data.polyline;
          _highway = data.highway ?? 'Quốc lộ Việt Nam';
          _distanceKm = data.distanceKm;
          _estimatedDuration = data.estimatedDuration;

          // Mặc định chọn trạm đầu tiên nếu chưa chọn
          if (_pickupStops.isNotEmpty && _selectedPickup == null) {
            _selectedPickup = _pickupStops.first;
          }
          if (_dropoffStops.isNotEmpty && _selectedDropoff == null) {
            _selectedDropoff = _dropoffStops.first;
          }

          _isLoading = false;
          _isCheckingRouteGuard = false;
          _isRouteValidForMap = true;
        });

        // Tự động căn khung bản đồ bao quát toàn bộ lộ trình
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapBounds();
        });

        // Định vị GPS ngầm
        _locateUser(silent: true);
      } else {
        setState(() {
          _isLoading = false;
          _isCheckingRouteGuard = false;
          _isRouteValidForMap = true;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu trạm: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCheckingRouteGuard = false;
        });
      }
    }
  }

  /// Tự động căn chỉnh Camera bản đồ để bao quát toàn bộ hành trình
  void _fitMapBounds() {
    if (_routePolyline.isEmpty) return;

    try {
      double minLat = _routePolyline.first.latitude;
      double maxLat = _routePolyline.first.latitude;
      double minLng = _routePolyline.first.longitude;
      double maxLng = _routePolyline.first.longitude;

      for (final p in _routePolyline) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      // Thêm các trạm đón/trả vào bounds
      for (final s in [..._pickupStops, ..._dropoffStops]) {
        if (s.latitude < minLat) minLat = s.latitude;
        if (s.latitude > maxLat) maxLat = s.latitude;
        if (s.longitude < minLng) minLng = s.longitude;
        if (s.longitude > maxLng) maxLng = s.longitude;
      }

      final centerLat = (minLat + maxLat) / 2.0;
      final centerLng = (minLng + maxLng) / 2.0;

      // Tính zoom ước tính
      final latDiff = (maxLat - minLat).abs();
      final lngDiff = (maxLng - minLng).abs();
      final maxDiff = math.max(latDiff, lngDiff);

      double zoom = 9.0;
      if (maxDiff > 5.0) {
        zoom = 6.8;
      } else if (maxDiff > 3.0) {
        zoom = 7.5;
      } else if (maxDiff > 1.5) {
        zoom = 8.3;
      } else if (maxDiff > 0.8) {
        zoom = 9.2;
      } else {
        zoom = 10.5;
      }

      _mapController.move(LatLng(centerLat, centerLng), zoom);
    } catch (e) {
      debugPrint('Lỗi fit bounds: $e');
    }
  }

  /// Di chuyển bản đồ mượt mà đến toạ độ chỉ định
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    try {
      _mapController.move(destLocation, destZoom);
    } catch (_) {}
  }

  /// Định vị GPS người dùng và tính khoảng cách đến từng trạm
  Future<void> _locateUser({bool silent = false}) async {
    if (_isLocatingUser) return;
    setState(() => _isLocatingUser = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && !silent) {
          _showSnackBar('Cần cấp quyền vị trí để tìm trạm xe gần bạn nhất.');
          setState(() => _isLocatingUser = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever && !silent) {
        _showSnackBar('Quyền vị trí đã bị tắt vĩnh viễn. Vui lòng mở cài đặt.');
        setState(() => _isLocatingUser = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (!mounted) return;

      setState(() {
        _userPosition = pos;
        _isLocatingUser = false;

        // Cập nhật khoảng cách từ người dùng đến từng trạm
        for (final s in _pickupStops) {
          s.distanceFromUser = MapBookingService.calculateDistanceInKm(
            pos.latitude,
            pos.longitude,
            s.latitude,
            s.longitude,
          );
        }
        for (final s in _dropoffStops) {
          s.distanceFromUser = MapBookingService.calculateDistanceInKm(
            pos.latitude,
            pos.longitude,
            s.latitude,
            s.longitude,
          );
        }

        // Sắp xếp gợi ý trạm gần nhất lên đầu
        _pickupStops.sort((a, b) => (a.distanceFromUser ?? 999).compareTo(b.distanceFromUser ?? 999));
      });

      if (!silent) {
        _animatedMapMove(LatLng(pos.latitude, pos.longitude), 14.0);
        _showSnackBar('Đã định vị thành công. Đã sắp xếp trạm đón gần bạn nhất.');
      }
    } catch (e) {
      debugPrint('Lỗi GPS: $e');
      if (mounted) setState(() => _isLocatingUser = false);
      if (!silent) _showSnackBar('Không thể lấy vị trí GPS hiện tại.');
    }
  }

  /// Chuyển đổi chế độ tối ưu định tuyến (Transit / Fastest / Shortest)
  Future<void> _changeOptimizationMode(String mode) async {
    if (_optimizationMode == mode || _isCalculatingRoute) return;
    setState(() {
      _optimizationMode = mode;
      _isCalculatingRoute = true;
    });

    try {
      final origin = _selectedPickup?.coordinates ?? _routePolyline.first;
      final dest = _selectedDropoff?.coordinates ?? _routePolyline.last;

      final res = await _service.getRouteDirections(
        origin: origin,
        destination: dest,
        optimization: mode,
        routeId: _routeId,
      );

      if (!mounted) return;

      if (res != null) {
        setState(() {
          _routePolyline = res.polyline;
          _distanceKm = res.distanceKm;
          _estimatedDuration = res.durationText;
          _isCalculatingRoute = false;
        });
        _showSnackBar('Đã tối ưu theo: ${res.optimizationName} (${res.distanceKm} km)');
      } else {
        setState(() => _isCalculatingRoute = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  /// Đảo chiều tuyến đường trực tiếp trên bản đồ
  void _swapDirection() {
    setState(() {
      _direction = _direction == 'forward' ? 'reverse' : 'forward';
      final tempPickup = _selectedPickup;
      _selectedPickup = _selectedDropoff;
      _selectedDropoff = tempPickup;
    });

    _loadRouteStopsAndPolyline();
  }

  /// Kiểm tra thứ tự hợp lệ của điểm dừng (Sequence Validation)
  bool _isSequenceValid() {
    if (_selectedPickup == null || _selectedDropoff == null) return true;

    // Chiều thuận: thứ tự điểm trả phải >= thứ tự điểm đón
    if (_direction == 'forward') {
      return _selectedDropoff!.sequence >= _selectedPickup!.sequence;
    }
    // Chiều nghịch: thứ tự điểm trả phải <= thứ tự điểm đón
    return _selectedDropoff!.sequence <= _selectedPickup!.sequence;
  }

  /// Chuyển tiếp sang luồng chọn chuyến và đặt vé
  Future<void> _proceedToExistingBookingFlow() async {
    if (_selectedPickup == null) {
      _showSnackBar('Vui lòng chọn trạm đón khách trên bản đồ.');
      setState(() => _currentStep = 2);
      return;
    }
    if (_selectedDropoff == null) {
      _showSnackBar('Vui lòng chọn trạm trả khách trên bản đồ.');
      setState(() => _currentStep = 3);
      return;
    }

    if (!_isSequenceValid()) {
      _showSnackBar('Điểm trả khách phải nằm sau điểm đón trên lộ trình chuyến xe.');
      return;
    }

    // Xác thực cuối cùng với Backend
    final validation = await _service.validateSelection(
      pickupId: _selectedPickup!.id,
      dropoffId: _selectedDropoff!.id,
      direction: _direction,
      routeId: _routeId,
    );

    if (!validation.isValid) {
      _showSnackBar(validation.message ?? 'Hành trình chưa hợp lệ.');
      return;
    }

    if (!mounted) return;

    // Nếu được gọi từ màn hình chi tiết chuyến đi, trả dữ liệu trạm về trực tiếp
    if (widget.caller == 'trip_detail' && Navigator.of(context).canPop()) {
      context.pop({
        'pickup_stop': _selectedPickup,
        'dropoff_stop': _selectedDropoff,
      });
      return;
    }

    // Chuyển hướng sang danh sách chuyến xe với thông tin trạm thực tế
    final dateStr = DateFormat('yyyy-MM-dd').format(_departureDate);
    context.push(
      '/search_results?from=${Uri.encodeComponent(_dbOrigin)}&to=${Uri.encodeComponent(_dbDestination)}&date=$dateStr',
      extra: {
        'from': _dbOrigin,
        'to': _dbDestination,
        'date': dateStr,
        'passenger_count': _passengerCount,
        'pickup_stop': _selectedPickup,
        'dropoff_stop': _selectedDropoff,
        'booking_mode': 'map_stops',
        'route_id': _routeId,
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: darkPrimary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRouteGuard) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: brandOrange),
              SizedBox(height: 16),
              Text(
                'Đang kiểm tra cấu hình bản đồ tuyến...',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isRouteValidForMap) {
      return _buildRouteGuardErrorView();
    }

    return Scaffold(
      backgroundColor: neutralBg,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Bản đồ tương tác chính
            Positioned.fill(
              child: _buildInteractiveMap(),
            ),

            // 2. Thanh tiêu đề & điều hướng trên cùng
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopHeader(),
            ),

            // 3. Nút điều khiển tiện ích bản đồ (GPS, Tối ưu hành trình, Toàn cảnh)
            Positioned(
              right: 16,
              top: 150,
              child: _buildMapFloatingControls(),
            ),

            // 4. Panel trạm dừng & thao tác ở dưới cùng
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomInteractivePanel(),
            ),

            // 5. Trạng thái tải đường đi OSRM
            if (_isCalculatingRoute || _isLoading)
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: darkPrimary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Đang tính toán tuyến đường tối ưu...', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Giao diện bản đồ tương tác với OpenStreetMap
  Widget _buildInteractiveMap() {
    final markers = <Marker>[];

    // Marker các trạm đón (Xanh dương)
    for (final s in _pickupStops) {
      final isSelected = _selectedPickup?.id == s.id;
      markers.add(
        Marker(
          point: s.coordinates,
          width: isSelected ? 50 : 38,
          height: isSelected ? 50 : 38,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPickup = s;
                _currentStep = 2;
              });
              _animatedMapMove(s.coordinates, 15.0);
            },
            child: _buildMarkerIcon(
              isSelected: isSelected,
              icon: Icons.directions_bus_rounded,
              color: const Color(0xFF2563EB),
              label: s.name,
            ),
          ),
        ),
      );
    }

    // Marker các trạm trả (Cam #FF6B00 / Đỏ)
    for (final s in _dropoffStops) {
      final isSelected = _selectedDropoff?.id == s.id;
      markers.add(
        Marker(
          point: s.coordinates,
          width: isSelected ? 50 : 38,
          height: isSelected ? 50 : 38,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedDropoff = s;
                _currentStep = 3;
              });
              _animatedMapMove(s.coordinates, 15.0);
            },
            child: _buildMarkerIcon(
              isSelected: isSelected,
              icon: Icons.location_on_rounded,
              color: brandOrange,
              label: s.name,
            ),
          ),
        ),
      );
    }

    // Marker các trạm nghỉ trung gian (Tím)
    for (final s in _restStops) {
      markers.add(
        Marker(
          point: s.coordinates,
          width: 32,
          height: 32,
          child: GestureDetector(
            onTap: () {
              _animatedMapMove(s.coordinates, 15.0);
              _showSnackBar('Trạm dừng chân: ${s.name}');
            },
            child: _buildMarkerIcon(
              isSelected: false,
              icon: Icons.local_cafe_rounded,
              color: const Color(0xFF7C3AED),
              label: s.name,
            ),
          ),
        ),
      );
    }

    // Marker vị trí người dùng (Xanh lá)
    if (_userPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.my_location_rounded, color: Color(0xFF059669), size: 24),
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _routePolyline.isNotEmpty ? _routePolyline.first : const LatLng(10.8145, 106.7123),
        initialZoom: 8.5,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        // Bản đồ chuẩn quốc tế OpenStreetMap Carto CDN tốc độ cao không cần API Key
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nhom5.vexemobile',
          maxZoom: 19,
        ),

        // Đường dẫn tuyến xe khách thực tế
        if (_routePolyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              // Viền ngoài phát sáng
              Polyline(
                points: _routePolyline,
                strokeWidth: 6.0,
                color: brandOrange.withOpacity(0.4),
              ),
              // Trục chính
              Polyline(
                points: _routePolyline,
                strokeWidth: 3.5,
                color: brandOrange,
              ),
            ],
          ),

        // Danh sách Marker
        MarkerLayer(markers: markers),
      ],
    );
  }

  /// Widget biểu tượng Marker hiển thị trên bản đồ
  Widget _buildMarkerIcon({
    required bool isSelected,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(isSelected ? 6 : 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isSelected ? 2.5 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: isSelected ? 20 : 16,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ],
    );
  }

  /// Thanh tiêu đề & điều hướng trên cùng
  Widget _buildTopHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: darkPrimary),
                  onPressed: () {
                    if (_currentStep > 1) {
                      setState(() => _currentStep--);
                    } else {
                      context.pop();
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _routeName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: darkPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$_highway • ${_distanceKm.toStringAsFixed(1)} km • $_estimatedDuration',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đảo chiều di chuyển',
                  icon: const Icon(Icons.swap_horiz_rounded, color: brandOrange),
                  onPressed: _swapDirection,
                ),
              ],
            ),
          ),

          // Bộ chọn chế độ tối ưu hành trình (Hành trình nhà xe / Nhanh nhất / Ngắn nhất)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _buildOptimizationTab(
                  mode: 'transit_route',
                  icon: Icons.directions_bus_rounded,
                  label: 'Nhà xe',
                ),
                const SizedBox(width: 6),
                _buildOptimizationTab(
                  mode: 'fastest',
                  icon: Icons.bolt_rounded,
                  label: 'Nhanh nhất',
                ),
                const SizedBox(width: 6),
                _buildOptimizationTab(
                  mode: 'shortest',
                  icon: Icons.straighten_rounded,
                  label: 'Ngắn nhất',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nút chọn chế độ tối ưu
  Widget _buildOptimizationTab({required String mode, required IconData icon, required String label}) {
    final isSelected = _optimizationMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeOptimizationMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? brandOrange : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? darkPrimary : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Các nút điều khiển tiện ích bản đồ
  Widget _buildMapFloatingControls() {
    return Column(
      children: [
        // 1. Nút toàn cảnh hành trình
        FloatingActionButton.small(
          heroTag: 'fab_fit_bounds',
          backgroundColor: Colors.white,
          foregroundColor: darkPrimary,
          onPressed: _fitMapBounds,
          tooltip: 'Xem toàn cảnh hành trình',
          child: const Icon(Icons.crop_free_rounded, size: 18),
        ),
        const SizedBox(height: 8),

        // 2. Nút định vị vị trí người dùng
        FloatingActionButton.small(
          heroTag: 'fab_locate_user',
          backgroundColor: Colors.white,
          foregroundColor: _isLocatingUser ? brandOrange : darkPrimary,
          onPressed: () => _locateUser(silent: false),
          tooltip: 'Vị trí của tôi',
          child: _isLocatingUser
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: brandOrange))
              : const Icon(Icons.my_location_rounded, size: 18),
        ),
      ],
    );
  }

  /// Panel điều khiển & chọn trạm dừng dưới cùng
  Widget _buildBottomInteractivePanel() {
    final activeStops = _currentStep == 2 ? _pickupStops : _dropoffStops;
    final filteredStops = _searchKeyword.isEmpty
        ? activeStops
        : activeStops.where((s) => s.name.toLowerCase().contains(_searchKeyword.toLowerCase()) || s.address.toLowerCase().contains(_searchKeyword.toLowerCase())).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tay kéo modal
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Thanh tiến trình chọn trạm: 1: Điểm đón -> 2: Điểm đến
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildStepSelector(
                    stepNumber: 2,
                    title: '1. Điểm đón',
                    stationName: _selectedPickup?.name ?? 'Chưa chọn trạm',
                    isSelected: _currentStep == 2,
                    color: const Color(0xFF2563EB),
                    onTap: () => setState(() => _currentStep = 2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStepSelector(
                    stepNumber: 3,
                    title: '2. Điểm đến',
                    stationName: _selectedDropoff?.name ?? 'Chưa chọn trạm',
                    isSelected: _currentStep == 3,
                    color: brandOrange,
                    onTap: () => setState(() => _currentStep = 3),
                  ),
                ),
              ],
            ),
          ),

          // Thanh tìm kiếm trạm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: _currentStep == 2 ? 'Tìm trạm đón tại $_departureArea...' : 'Tìm trạm trả tại $_destinationArea...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchKeyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchKeyword = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchKeyword = val.trim()),
              ),
            ),
          ),

          // Cảnh báo nếu thứ tự điểm dừng chưa hợp lệ
          if (!_isSequenceValid())
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Điểm trả phải nằm sau điểm đón trên lộ trình chuyến xe.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Danh sách thẻ trạm ngang
          SizedBox(
            height: 105,
            child: filteredStops.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy trạm dừng nào phù hợp',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    controller: _cardsScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filteredStops.length,
                    itemBuilder: (context, index) {
                      final station = filteredStops[index];
                      final isSelected = (_currentStep == 2 && _selectedPickup?.id == station.id) ||
                          (_currentStep == 3 && _selectedDropoff?.id == station.id);

                      return _buildStationHorizontalCard(station, isSelected);
                    },
                  ),
          ),

          // Nút xác nhận hành trình & tiếp tục
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSequenceValid() ? brandOrange : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSequenceValid() ? _proceedToExistingBookingFlow : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Xác nhận & Tìm chuyến', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ chọn bước điểm đón / điểm trả
  Widget _buildStepSelector({
    required int stepNumber,
    required String title,
    required String stationName,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              stationName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: darkPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Thẻ trạm ngang
  Widget _buildStationHorizontalCard(MapStation station, bool isSelected) {
    final color = _currentStep == 2 ? const Color(0xFF2563EB) : brandOrange;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_currentStep == 2) {
            _selectedPickup = station;
          } else {
            _selectedDropoff = station;
          }
        });
        _animatedMapMove(station.coordinates, 15.0);
      },
      child: Container(
        width: 210,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : darkPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (station.distanceFromUser != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      MapBookingService.formatDistance(station.distanceFromUser),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            Text(
              station.address,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thứ tự: #${station.sequence}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isSelected ? color : Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Giao diện lỗi Route Guard khi tuyến không hỗ trợ bản đồ
  Widget _buildRouteGuardErrorView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bản đồ tuyến xe', style: TextStyle(color: darkPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: darkPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map_outlined, size: 54, color: brandOrange),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tuyến chưa hỗ trợ chọn trạm trên bản đồ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                _routeGuardErrorMessage ??
                    'Tuyến đường này hiện chưa có dữ liệu điểm dừng bản đồ. Quý khách vui lòng sử dụng phương thức tìm chuyến xe phổ thông.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final dateStr = DateFormat('yyyy-MM-dd').format(_departureDate);
                  context.push('/search_results?from=${Uri.encodeComponent(_dbOrigin)}&to=${Uri.encodeComponent(_dbDestination)}&date=$dateStr');
                },
                child: const Text('Chuyển sang tìm chuyến phổ thông', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
