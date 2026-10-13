import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../models/map_station.dart';
import '../../services/map_booking_service.dart';

/// Màn hình đặt vé theo bản đồ tương tác (Tuyến Sài Gòn ↔ Cư Jút)
/// Tham khảo phong cách BusMap, tối ưu cho xe khách liên tỉnh
class MapBookingScreen extends StatefulWidget {
  final String? initialDirection; // 'forward' (SG -> CJ) hoặc 'reverse' (CJ -> SG)

  const MapBookingScreen({super.key, this.initialDirection});

  @override
  State<MapBookingScreen> createState() => _MapBookingScreenState();
}

class _MapBookingScreenState extends State<MapBookingScreen> {
  final MapBookingService _service = MapBookingService();
  final MapController _mapController = MapController();
  final ScrollController _cardsScrollController = ScrollController();

  // Màu thương hiệu cam đặc trưng #FF6B00
  static const Color brandOrange = Color(0xFFFF6B00);
  static const Color darkPrimary = Color(0xFF0B192C);
  static const Color neutralBg = Color(0xFFF8FAFC);

  // Trạng thái bước: 1: Chọn tuyến, 2: Chọn điểm đón, 3: Chọn điểm đến, 4: Xác nhận
  int _currentStep = 1;

  // Hướng di chuyển: 'forward' = Sài Gòn -> Cư Jút, 'reverse' = Cư Jút -> Sài Gòn
  String _direction = 'forward';

  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  int _passengerCount = 1;

  final bool _isLoading = false;
  String? _errorMessage;

  // Dữ liệu trạm khởi tạo trực tiếp từ bộ dữ liệu thực tế (Hiển thị tức thì)
  late List<MapStation> _pickupStops = MapBookingService.fallbackStations
      .where((s) => s.area == 'Sài Gòn')
      .toList();
  late List<MapStation> _dropoffStops = MapBookingService.fallbackStations
      .where((s) => s.area == 'Cư Jút')
      .toList();
  late List<LatLng> _routePolyline = MapBookingService.fallbackPolyline;
  String _departureArea = 'Sài Gòn';
  String _destinationArea = 'Cư Jút (Đắk Nông)';
  String _dbOrigin = 'TP. Hồ Chí Minh';
  String _dbDestination = 'Cư Jut';

  // Điểm đã chọn (Mặc định chọn Bến xe Miền Đông Cũ cho điểm đón Sài Gòn)
  MapStation? _selectedPickup;
  MapStation? _selectedDropoff;

  // Vị trí người dùng
  Position? _userPosition;

  // Bộ lọc tìm kiếm trạm
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  // Các mốc hành lang giao thông thực tế QL13 & QL14
  static final List<Map<String, dynamic>> _corridorMilestones = [
    {
      'title': 'Bến xe Miền Đông (Cũ)',
      'tag': 'Khởi hành',
      'point': const LatLng(10.8142, 106.7118),
      'color': const Color(0xFFEF4444),
      'icon': Icons.flag_rounded,
    },
    {
      'title': 'Trục QL13 (Bình Dương)',
      'tag': 'Quốc lộ 13',
      'point': const LatLng(10.9807, 106.6527),
      'color': const Color(0xFF2563EB),
      'icon': Icons.alt_route_rounded,
    },
    {
      'title': 'Ngã 4 Chơn Thành',
      'tag': 'QL13 ➔ QL14',
      'point': const LatLng(11.4543, 106.6867),
      'color': const Color(0xFF7C3AED),
      'icon': Icons.navigation_rounded,
    },
    {
      'title': 'QL14 (Bù Đăng)',
      'tag': 'Bình Phước',
      'point': const LatLng(11.7674, 107.2387),
      'color': const Color(0xFFD97706),
      'icon': Icons.route_rounded,
    },
    {
      'title': 'Địa phận Tỉnh Đắk Nông',
      'tag': 'Quốc lộ 14',
      'point': const LatLng(11.9799, 107.5013),
      'color': const Color(0xFF059669),
      'icon': Icons.terrain_rounded,
    },
    {
      'title': 'TP. Gia Nghĩa (Đắk Nông)',
      'tag': 'QL14',
      'point': const LatLng(12.0038, 107.6902),
      'color': const Color(0xFF0D9488),
      'icon': Icons.location_city_rounded,
    },
    {
      'title': 'Bến xe Cư Jút',
      'tag': 'Đích đến (Đắk Nông)',
      'point': const LatLng(12.5932, 107.8924),
      'color': const Color(0xFF10B981),
      'icon': Icons.check_circle_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDirection == 'reverse') {
      _direction = 'reverse';
      _departureArea = 'Cư Jút (Đắk Nông)';
      _destinationArea = 'Sài Gòn';
      _dbOrigin = 'Cư Jut';
      _dbDestination = 'TP. Hồ Chí Minh';
      _pickupStops = MapBookingService.fallbackStations.where((s) => s.area == 'Cư Jút').toList();
      _dropoffStops = MapBookingService.fallbackStations.where((s) => s.area == 'Sài Gòn').toList();
    }
    _selectedPickup = _pickupStops.isNotEmpty ? _pickupStops.first : null;
    _selectedDropoff = _dropoffStops.isNotEmpty ? _dropoffStops.first : null;

    _loadStopsData();
    _requestLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cardsScrollController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (mounted) {
          setState(() {
            _userPosition = pos;
          });
          _service.getRouteStops(
            direction: _direction,
            userPosition: _userPosition,
          ).then((res) {
            if (mounted) {
              setState(() {
                if ((res['pickups'] as List).isNotEmpty) _pickupStops = res['pickups'];
                if ((res['dropoffs'] as List).isNotEmpty) _dropoffStops = res['dropoffs'];
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('MapBooking: Lỗi lấy GPS: $e');
    }
  }

  Future<void> _loadStopsData() async {
    try {
      final res = await _service.getRouteStops(
        direction: _direction,
        userPosition: _userPosition,
      );

      if (!mounted) return;
      setState(() {
        if ((res['pickups'] as List).isNotEmpty) {
          _pickupStops = res['pickups'];
          if (_selectedPickup == null && _pickupStops.isNotEmpty) {
            _selectedPickup = _pickupStops.first;
          }
        }
        if ((res['dropoffs'] as List).isNotEmpty) {
          _dropoffStops = res['dropoffs'];
          if (_selectedDropoff == null && _dropoffStops.isNotEmpty) {
            _selectedDropoff = _dropoffStops.first;
          }
        }
        if ((res['polyline'] as List).isNotEmpty) {
          _routePolyline = res['polyline'];
        }
        _dbOrigin = res['db_origin'];
        _dbDestination = res['db_destination'];
      });
    } catch (e) {
      debugPrint('MapBooking: Sử dụng dữ liệu xác thực nội bộ do: $e');
    }
  }

  void _swapDirection() {
    setState(() {
      _direction = _direction == 'forward' ? 'reverse' : 'forward';
      if (_direction == 'forward') {
        _departureArea = 'Sài Gòn';
        _destinationArea = 'Cư Jút (Đắk Nông)';
        _dbOrigin = 'TP. Hồ Chí Minh';
        _dbDestination = 'Cư Jut';
        _pickupStops = MapBookingService.fallbackStations.where((s) => s.area == 'Sài Gòn').toList();
        _dropoffStops = MapBookingService.fallbackStations.where((s) => s.area == 'Cư Jút').toList();
      } else {
        _departureArea = 'Cư Jút (Đắk Nông)';
        _destinationArea = 'Sài Gòn';
        _dbOrigin = 'Cư Jut';
        _dbDestination = 'TP. Hồ Chí Minh';
        _pickupStops = MapBookingService.fallbackStations.where((s) => s.area == 'Cư Jút').toList();
        _dropoffStops = MapBookingService.fallbackStations.where((s) => s.area == 'Sài Gòn').toList();
      }
      _selectedPickup = _pickupStops.isNotEmpty ? _pickupStops.first : null;
      _selectedDropoff = _dropoffStops.isNotEmpty ? _dropoffStops.first : null;
    });
    _loadStopsData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zoomToCurrentCluster();
    });
  }

  void _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: brandOrange,
              onPrimary: Colors.white,
              onSurface: darkPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _departureDate = picked);
    }
  }

  List<MapStation> get _currentStationList {
    final baseList = _currentStep == 2 ? _pickupStops : _dropoffStops;
    if (_searchKeyword.isEmpty) return baseList;
    final q = _searchKeyword.toLowerCase().trim();
    return baseList.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q);
    }).toList();
  }

  MapStation? get _currentSelectedStation {
    return _currentStep == 2 ? _selectedPickup : _selectedDropoff;
  }

  void _onStationSelected(MapStation station) {
    setState(() {
      if (_currentStep == 2) {
        _selectedPickup = station;
      } else if (_currentStep == 3) {
        if (_selectedPickup != null && _selectedPickup!.id == station.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Điểm đến không được trùng với điểm đón!'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        _selectedDropoff = station;
      }
    });

    // Căn giữa bản đồ đến điểm đã chọn
    try {
      _mapController.move(station.coordinates, 15.0);
    } catch (_) {}

    // Tự động cuộn Carousel thẻ trạm đến đúng thẻ này
    final index = _currentStationList.indexWhere((s) => s.id == station.id);
    if (index >= 0 && _cardsScrollController.hasClients) {
      _cardsScrollController.animateTo(
        index * 260.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _zoomToRouteOverview() {
    try {
      _mapController.move(const LatLng(11.70, 107.30), 7.8);
    } catch (_) {}
  }

  void _zoomToCurrentCluster() {
    try {
      final isPickup = _currentStep == 2;
      final target = isPickup
          ? (_direction == 'forward'
              ? const LatLng(10.8142, 106.7118) // Bến xe Miền Đông Cũ
              : const LatLng(12.5932, 107.8924)) // Cư Jút Đắk Nông
          : (_direction == 'forward'
              ? const LatLng(12.5932, 107.8924) // Cư Jút Đắk Nông
              : const LatLng(10.8142, 106.7118)); // Bến xe Miền Đông Cũ
      _mapController.move(target, 13.5);
    } catch (_) {}
  }

  void _centerToUserLocation() {
    if (_userPosition != null) {
      _mapController.move(LatLng(_userPosition!.latitude, _userPosition!.longitude), 14.5);
    } else {
      _requestLocation().then((_) {
        if (!mounted) return;
        if (_userPosition != null) {
          _mapController.move(LatLng(_userPosition!.latitude, _userPosition!.longitude), 14.5);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa lấy được vị trí GPS. Vui lòng bật định vị trên thiết bị.')),
          );
        }
      });
    }
  }

  LatLng get _initialMapCenter {
    final currentList = _currentStationList;
    if (currentList.isNotEmpty) {
      return currentList.first.coordinates;
    }
    if (_currentStep == 2) {
      return _direction == 'forward'
          ? const LatLng(10.8142, 106.7118) // Bến xe Miền Đông Cũ
          : const LatLng(12.5932, 107.8924); // Cư Jút Đắk Nông
    } else {
      return _direction == 'forward'
          ? const LatLng(12.5932, 107.8924) // Cư Jút Đắk Nông
          : const LatLng(10.8142, 106.7118); // Bến xe Miền Đông Cũ
    }
  }

  void _proceedToExistingBookingFlow() {
    if (_selectedPickup == null || _selectedDropoff == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_departureDate);

    // Chuyển sang màn hình tìm chuyến xe hiện có của app, truyền chính xác điểm đón & trả
    context.push(
      '/search_results?from=$_dbOrigin&to=$_dbDestination&date=$dateStr',
      extra: {
        'pickupPoint': '${_selectedPickup!.name} (${_selectedPickup!.address})',
        'dropoffPoint': '${_selectedDropoff!.name} (${_selectedDropoff!.address})',
        'passengerCount': _passengerCount,
      },
    );
  }

  String _formatDepartureDate(DateTime date) {
    const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final weekdayStr = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$weekdayStr, $day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neutralBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            Expanded(child: _buildCurrentStepContent()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR & STEPPER HEADER
  // ---------------------------------------------------------------------------
  Widget _buildTopAppBar() {
    String stepTitle = 'Đặt vé xe theo bản đồ';
    if (_currentStep == 1) stepTitle = 'Chọn tuyến xe liên tỉnh';
    if (_currentStep == 2) stepTitle = 'Chọn điểm đón • $_departureArea';
    if (_currentStep == 3) stepTitle = 'Chọn điểm đến • $_destinationArea';
    if (_currentStep == 4) stepTitle = 'Xác nhận hành trình';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: darkPrimary),
                onPressed: () {
                  if (_currentStep > 1) {
                    setState(() => _currentStep--);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _zoomToCurrentCluster();
                    });
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
                      stepTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: darkPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tuyến: Bến xe Miền Đông Cũ ➔ QL13 ➔ QL14 ➔ Cư Jút (Đắk Nông)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_currentStep == 2 || _currentStep == 3)
                IconButton(
                  tooltip: 'Xem toàn tuyến QL13 & QL14 (310km)',
                  icon: const Icon(
                    Icons.alt_route_rounded,
                    color: brandOrange,
                  ),
                  onPressed: _zoomToRouteOverview,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Stepper indicator
          Row(
            children: [
              _buildStepIndicator(1, 'Tuyến', _currentStep >= 1),
              _buildStepLine(_currentStep >= 2),
              _buildStepIndicator(2, 'Điểm đón', _currentStep >= 2),
              _buildStepLine(_currentStep >= 3),
              _buildStepIndicator(3, 'Điểm đến', _currentStep >= 3),
              _buildStepLine(_currentStep >= 4),
              _buildStepIndicator(4, 'Xác nhận', _currentStep >= 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isCompleted) {
    final isActive = _currentStep == step;
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isActive
                ? brandOrange
                : (isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: (isActive || isCompleted) ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? brandOrange : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
        color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN STEP SWITCHER
  // ---------------------------------------------------------------------------
  Widget _buildCurrentStepContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: brandOrange),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadStopsData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(backgroundColor: brandOrange, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    switch (_currentStep) {
      case 1:
        return _buildStep1RouteSelection();
      case 2:
      case 3:
        return _buildMapSelectionStep();
      case 4:
        return _buildStep4Summary();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // BƯỚC 1: CHỌN TUYẾN XE
  // ---------------------------------------------------------------------------
  Widget _buildStep1RouteSelection() {
    final startCity = _direction == 'forward' ? 'Sài Gòn (BX Miền Đông Cũ)' : 'Cư Jút (Tỉnh Đắk Nông)';
    final endCity = _direction == 'forward' ? 'Cư Jút (Tỉnh Đắk Nông)' : 'Sài Gòn (BX Miền Đông Cũ)';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner giới thiệu tính năng BusMap
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8C38), brandOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x33FF6B00), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.map_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đặt vé theo trạm dừng',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Xem vị trí trạm trên bản đồ, tính khoảng cách GPS và chọn điểm đón/trả gần bạn nhất.',
                        style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Thẻ chọn tuyến đường chính
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin hành trình',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkPrimary),
                ),
                const SizedBox(height: 16),

                // Box Điểm đi & Điểm đến có nút đảo chiều
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Column(
                      children: [
                        // Điểm khởi hành
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location_rounded, color: brandOrange, size: 20),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Điểm khởi hành', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    startCity,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Điểm đến
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Điểm đến', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    endCity,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Nút đảo chiều Sài Gòn <-> Cư Jút
                    Positioned(
                      right: 16,
                      child: GestureDetector(
                        onTap: _swapDirection,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: brandOrange, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.swap_vert_rounded, color: brandOrange, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ngày khởi hành
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ngày khởi hành', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              _formatDepartureDate(_departureDate),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkPrimary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_outlined, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Số lượng hành khách
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.people_outline_rounded, color: Color(0xFF64748B), size: 20),
                          SizedBox(width: 12),
                          Text('Số hành khách', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkPrimary)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                            onPressed: _passengerCount > 1
                                ? () => setState(() => _passengerCount--)
                                : null,
                          ),
                          Text(
                            '$_passengerCount',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkPrimary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: brandOrange),
                            onPressed: _passengerCount < 5
                                ? () => setState(() => _passengerCount++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Thông tin tổng quan tuyến đường
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: brandOrange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cự ly: ~310 km • Hành trình QL13 & QL14: Bến xe Miền Đông (Cũ) ➔ Bình Dương ➔ Chơn Thành ➔ Tỉnh Đắk Nông (Gia Nghĩa, Đắk Mil) ➔ Bến xe Cư Jút.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFC2410C), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Nút Tiếp tục chọn điểm đón
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep = 2; // Sang bước chọn điểm đón
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _zoomToCurrentCluster();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Chọn điểm đón trên bản đồ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

  // ---------------------------------------------------------------------------
  // BƯỚC 2 & 3: BẢN ĐỒ TRỰC TIẾP CHỌN ĐIỂM ĐÓN / ĐIỂM ĐẾN (LIVE DIRECT MAP)
  // ---------------------------------------------------------------------------
  Widget _buildMapSelectionStep() {
    final isPickupStep = _currentStep == 2;
    final currentArea = isPickupStep ? _departureArea : _destinationArea;
    final stations = _currentStationList;
    final selectedStation = _currentSelectedStation;

    return Stack(
      children: [
        // 1. Bản đồ OpenStreetMap trực tiếp toàn màn hình (FlutterMap)
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: selectedStation?.coordinates ?? _initialMapCenter,
            initialZoom: 13.5,
            minZoom: 6.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.webdatvexe.app',
              maxZoom: 19,
            ),
            // Tuyến đường xe chạy qua QL13 & QL14: Dual-layer polyline nổi bật
            if (_routePolyline.isNotEmpty)
              PolylineLayer(
                polylines: [
                  // Lớp viền glow mờ bên ngoài
                  Polyline(
                    points: _routePolyline,
                    strokeWidth: 7.0,
                    color: const Color(0x55FF6B00),
                  ),
                  // Lớp chính màu cam thương hiệu
                  Polyline(
                    points: _routePolyline,
                    strokeWidth: 4.5,
                    color: brandOrange,
                  ),
                ],
              ),
            // Lớp mốc chỉ dẫn hành lang tuyến QL13 & QL14
            MarkerLayer(
              markers: _corridorMilestones.map((m) {
                final point = m['point'] as LatLng;
                final title = m['title'] as String;
                final tag = m['tag'] as String;
                final color = m['color'] as Color;
                final icon = m['icon'] as IconData;

                return Marker(
                  point: point,
                  width: 170,
                  height: 30,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 13, color: color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$title ($tag)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            // Lớp trạm dừng tương tác trực tiếp trên bản đồ
            MarkerLayer(
              markers: stations.map((s) {
                final isSelected = selectedStation?.id == s.id;
                return Marker(
                  point: s.coordinates,
                  width: isSelected ? 160 : 42,
                  height: isSelected ? 76 : 42,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () => _onStationSelected(s),
                    child: isSelected
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nhãn tên trạm nổi phía trên marker
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: darkPrimary,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Pin xe bus đang chọn
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: brandOrange,
                                  border: Border.all(color: Colors.white, width: 3.0),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66FF6B00),
                                      blurRadius: 12,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.directions_bus_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: brandOrange, width: 2.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_bus_rounded,
                                size: 18,
                                color: brandOrange,
                              ),
                            ),
                          ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // 2. Thanh tìm kiếm và huy hiệu thông tin lộ trình phía trên bản đồ
        Positioned(
          top: 12,
          left: 14,
          right: 14,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchKeyword = val);
                    final filtered = _currentStationList;
                    if (filtered.isNotEmpty) {
                      try {
                        _mapController.move(filtered.first.coordinates, 14.5);
                      } catch (_) {}
                    }
                  },
                  decoration: InputDecoration(
                    hintText: isPickupStep
                        ? 'Tìm điểm đón tại $currentArea...'
                        : 'Tìm điểm trả tại $currentArea...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: brandOrange, size: 22),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchKeyword = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Huy hiệu lộ trình Quốc lộ 13 - Quốc lộ 14
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alt_route_rounded, size: 14, color: brandOrange),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Hành lang: BX Miền Đông Cũ ➔ QL13 ➔ QL14 ➔ Cư Jút (Đắk Nông)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC2410C)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Cụm nút điều khiển camera bản đồ nổi bên phải
        Positioned(
          right: 14,
          top: 115,
          child: Column(
            children: [
              // Nút xem toàn tuyến 310km
              FloatingActionButton.small(
                heroTag: 'overview_btn_${isPickupStep ? "pickup" : "dropoff"}',
                onPressed: _zoomToRouteOverview,
                backgroundColor: Colors.white,
                foregroundColor: brandOrange,
                elevation: 3,
                tooltip: 'Toàn tuyến (310km QL13-QL14)',
                child: const Icon(Icons.route_rounded, size: 20),
              ),
              const SizedBox(height: 8),
              // Nút về cụm trạm hiện tại
              FloatingActionButton.small(
                heroTag: 'cluster_btn_${isPickupStep ? "pickup" : "dropoff"}',
                onPressed: _zoomToCurrentCluster,
                backgroundColor: Colors.white,
                foregroundColor: darkPrimary,
                elevation: 3,
                tooltip: 'Về khu vực trạm',
                child: const Icon(Icons.filter_center_focus_rounded, size: 20),
              ),
              const SizedBox(height: 8),
              // Nút GPS vị trí của tôi
              FloatingActionButton.small(
                heroTag: 'gps_btn_${isPickupStep ? "pickup" : "dropoff"}',
                onPressed: _centerToUserLocation,
                backgroundColor: Colors.white,
                foregroundColor: brandOrange,
                elevation: 3,
                tooltip: 'Vị trí của bạn',
                child: const Icon(Icons.my_location_rounded, size: 20),
              ),
            ],
          ),
        ),

        // 4. Khung Carousel lướt thẻ trạm trực tiếp phía dưới bản đồ & Nút xác nhận
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thanh kéo nhẹ
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tiêu đề gợi ý số lượng trạm
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPickupStep
                          ? 'Trạm đón khách tại $currentArea (${stations.length})'
                          : 'Trạm trả khách tại $currentArea (${stations.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkPrimary),
                    ),
                    Text(
                      'Vuốt ngang để xem trạm ➔',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Carousel thẻ trạm nằm ngang lướt trực tiếp trên bản đồ
                SizedBox(
                  height: 104,
                  child: stations.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy trạm phù hợp', style: TextStyle(color: Color(0xFF64748B))),
                        )
                      : ListView.separated(
                          controller: _cardsScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: stations.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (ctx, idx) {
                            final s = stations[idx];
                            final isSel = selectedStation?.id == s.id;
                            return _buildStationCarouselCard(s, isSel, idx);
                          },
                        ),
                ),
                const SizedBox(height: 12),

                // Nút xác nhận trạm hoặc chỉ dẫn
                if (selectedStation != null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isPickupStep) {
                            _currentStep = 3; // Sang chọn điểm đến
                            _searchController.clear();
                            _searchKeyword = '';
                          } else {
                            _currentStep = 4; // Sang xác nhận hành trình
                          }
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _zoomToCurrentCluster();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isPickupStep ? Icons.directions_bus_rounded : Icons.location_on_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPickupStep
                                  ? 'Xác nhận đón tại: ${selectedStation.name}'
                                  : 'Xác nhận trả tại: ${selectedStation.name}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app_outlined, color: brandOrange, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          isPickupStep
                              ? 'Chạm vào trạm trên bản đồ hoặc chọn thẻ phía trên'
                              : 'Chọn trạm trả khách tại Cư Jút (Đắk Nông)',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationCarouselCard(MapStation station, bool isSelected, int index) {
    return GestureDetector(
      onTap: () => _onStationSelected(station),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? brandOrange : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0x26FF6B00) : const Color(0x0A000000),
              blurRadius: isSelected ? 10 : 4,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? brandOrange : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? brandOrange : darkPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: brandOrange, size: 16),
              ],
            ),
            Text(
              station.address,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (station.distanceFromUser != null)
                  Row(
                    children: [
                      const Icon(Icons.near_me_outlined, size: 11, color: brandOrange),
                      const SizedBox(width: 3),
                      Text(
                        'Cách bạn: ${MapBookingService.formatDistance(station.distanceFromUser)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: brandOrange),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Trạm đón hợp lệ',
                    style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                  ),
                Text(
                  isSelected ? 'Đang chọn' : 'Chạm để chọn',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? brandOrange : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BƯỚC 4: TÓM TẮT & XÁC NHẬN HÀNH TRÌNH
  // ---------------------------------------------------------------------------
  Widget _buildStep4Summary() {
    final routeTitle = _direction == 'forward' ? 'Sài Gòn → Cư Jút' : 'Cư Jút → Sài Gòn';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thẻ tóm tắt thành công
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tóm tắt hành trình', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkPrimary)),
                        Text('Tuyến xe: $routeTitle', style: const TextStyle(fontSize: 13, color: brandOrange, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Điểm đón
                _buildSummaryStopItem(
                  title: 'ĐIỂM ĐÓN KHÁCH',
                  stationName: _selectedPickup?.name ?? '',
                  address: _selectedPickup?.address ?? '',
                  isPickup: true,
                  onChange: () => setState(() => _currentStep = 2),
                ),
                const SizedBox(height: 16),
                // Đường kết nối
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Container(
                    height: 20,
                    width: 2,
                    color: brandOrange.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                // Điểm trả
                _buildSummaryStopItem(
                  title: 'ĐIỂM TRẢ KHÁCH',
                  stationName: _selectedDropoff?.name ?? '',
                  address: _selectedDropoff?.address ?? '',
                  isPickup: false,
                  onChange: () => setState(() => _currentStep = 3),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Thông tin bổ sung
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ngày khởi hành:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_departureDate),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: darkPrimary, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Số hành khách:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    Text(
                      '$_passengerCount người',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: darkPrimary, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lộ trình di chuyển:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    Text(
                      'QL13 & QL14 (~310 km) • Tỉnh Đắk Nông',
                      style: TextStyle(fontWeight: FontWeight.w700, color: darkPrimary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Nút Tiếp tục đặt vé vào luồng chính
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _proceedToExistingBookingFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Tiếp tục đặt vé & Chọn ghế', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
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

  Widget _buildSummaryStopItem({
    required String title,
    required String stationName,
    required String address,
    required bool isPickup,
    required VoidCallback onChange,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isPickup ? const Color(0xFFFFF7ED) : const Color(0xFFFEF2F2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPickup ? brandOrange : const Color(0xFFEF4444),
              width: 2,
            ),
          ),
          child: Icon(
            isPickup ? Icons.directions_bus_rounded : Icons.location_on_rounded,
            size: 16,
            color: isPickup ? brandOrange : const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isPickup ? brandOrange : const Color(0xFFEF4444),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stationName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: darkPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(foregroundColor: brandOrange, padding: EdgeInsets.zero),
          child: const Text('Đổi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
