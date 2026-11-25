import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../services/map_booking_service.dart';
import '../../models/booking_strategy.dart';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../services/nearby_alert_service.dart';
import '../../services/booking_service.dart';
import '../../services/smart_boarding_service.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/shared_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapBookingService _mapBookingService = MapBookingService();
  bool _isSearching = false;
  String _from = 'TP. Hồ Chí Minh';
  String _to = 'Đà Lạt';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  final int _selectedTab = 0;

  final List<Map<String, String>> _popularRoutes = [
    {
      'from': 'TP. Hồ Chí Minh',
      'to': 'Cư Jut',
      'price': '280.000đ',
      'image': 'assets/images/route_hcm_cujut.jpg',
      'badge': 'BUSMAP',
      'duration': '6h 30p',
    },
    {
      'from': 'TP. Hồ Chí Minh',
      'to': 'Đà Lạt',
      'price': '250.000đ',
      'image': 'assets/images/route_hcm_dalat.jpg',
      'badge': 'PHỔ BIẾN',
      'duration': '6h 00p',
    },
    {
      'from': 'Hà Nội',
      'to': 'Hải Phòng',
      'price': '180.000đ',
      'image': 'assets/images/route_hanoi_haiphong.jpg',
      'badge': 'CAO TỐC',
      'duration': '1h 45p',
    },
    {
      'from': 'TP. Hồ Chí Minh',
      'to': 'Cần Thơ',
      'price': '165.000đ',
      'image': 'assets/images/route_hcm_cujut.jpg',
      'badge': 'LIMOUSINE',
      'duration': '3h 15p',
    },
    {
      'from': 'Hà Nội',
      'to': 'Đà Nẵng',
      'price': '350.000đ',
      'image': 'assets/images/route_hanoi_danang.jpg',
      'badge': 'GIƯỜNG NẰM',
      'duration': '12h 00p',
    },
    {
      'from': 'TP. Hồ Chí Minh',
      'to': 'Nha Trang',
      'price': '220.000đ',
      'image': 'assets/images/route_hcm_nhatrang.jpg',
      'badge': 'CAO TỐC',
      'duration': '7h 00p',
    },
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    final bookingService = context.read<BookingService>();
    SmartBoardingService.instance.startWatching(() => bookingService.getMyBookings());
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
        _guessCityFromLocation(position.latitude, position.longitude);
        NearbyAlertService.instance.updateCurrentPosition(
          position.latitude,
          position.longitude,
          accuracy: position.accuracy,
        );
      } catch (e) {
        debugPrint('Lỗi lấy vị trí: $e');
      }
    }
  }

  Future<void> _guessCityFromLocation(double lat, double lon) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'TriplyMobilityApp/1.0',
        'Accept-Language': 'vi-VN,vi;q=0.9'
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['address'] != null) {
          final address = data['address'];
          String? city = address['city'] ?? address['state'] ?? address['province'];
          if (city != null) {
            city = city.replaceAll('Thành phố ', '').replaceAll('Tỉnh ', '').trim();
            final availableCities = await _fetchLocations();
            final targetCity = city.toLowerCase();
            final match = availableCities.cast<String?>().firstWhere(
              (c) => c != null && (c.toLowerCase().contains(targetCity) || targetCity.contains(c.toLowerCase())),
              orElse: () => null,
            );
            if (match != null && mounted) {
              setState(() {
                _from = match;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi reverse geocoding: $e');
    }
  }

  List<String> _locations = [];

  Future<List<String>> _fetchLocations() async {
    if (_locations.isNotEmpty) return _locations;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/locations'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<String>.from(data['data']['locations']);
        _locations = list;
        return list;
      }
    } catch (_) {}
    return [
      'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Ninh',
      'Bến Tre', 'Bình Dương', 'Bình Định', 'Bình Thuận',
      'Cà Mau', 'Cần Thơ', 'Cao Bằng', 'Đà Nẵng', 'Đắk Lắk',
      'Đắk Nông', 'Điện Biên', 'Đồng Nai', 'Đồng Tháp',
      'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Nội', 'Hà Tĩnh',
      'Hải Dương', 'Hải Phòng', 'Hậu Giang', 'Hòa Bình',
      'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 'Kon Tum',
      'Lai Châu', 'Lâm Đồng', 'Lạng Sơn', 'Lào Cai',
      'Long An', 'Nam Định', 'Nghệ An', 'Ninh Bình',
      'Ninh Thuận', 'Phú Thọ', 'Phú Yên', 'Quảng Bình',
      'Quảng Nam', 'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị',
      'Sóc Trăng', 'Sơn La', 'Tây Ninh', 'Thái Bình',
      'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang',
      'TP. Hồ Chí Minh', 'Trà Vinh', 'Tuyên Quang',
      'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái',
      'Đà Lạt', 'Nha Trang', 'Huế', 'Vũng Tàu',
      'Buôn Ma Thuột', 'Mỹ Tho', 'Rạch Giá', 'Phan Thiết',
      'Cam Ranh', 'Sa Pa', 'Hạ Long', 'Điện Biên Phủ', 'Cư Jut',
    ];
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _swapLocations() {
    setState(() {
      final temp = _from;
      _from = _to;
      _to = temp;
    });
  }

  Future<void> _searchTrips() async {
    if (_isSearching) return;
    setState(() => _isSearching = true);

    try {
      final strategy = await _mapBookingService.getRouteStrategy(from: _from, to: _to);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (!mounted) return;

      if (strategy.mode == BookingMode.mapStops && strategy.hasMapConfig) {
        context.push(
          '/map_booking?route_id=${strategy.routeId ?? "sg_cj"}&direction=${strategy.direction}&from=${Uri.encodeComponent(_from)}&to=${Uri.encodeComponent(_to)}&date=$dateStr&passengers=1',
        );
      } else {
        context.push(
          '/search_results?from=${Uri.encodeComponent(_from)}&to=${Uri.encodeComponent(_to)}&date=$dateStr',
        );
      }
    } catch (e) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      if (mounted) {
        context.push(
          '/search_results?from=${Uri.encodeComponent(_from)}&to=${Uri.encodeComponent(_to)}&date=$dateStr',
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (dateStr == DateFormat('yyyy-MM-dd').format(now)) {
      return 'Hôm nay, ${DateFormat('dd/MM/yyyy').format(date)}';
    } else if (dateStr == DateFormat('yyyy-MM-dd').format(tomorrow)) {
      return 'Ngày mai, ${DateFormat('dd/MM/yyyy').format(date)}';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final greeting = user?.name != null && user!.name.trim().isNotEmpty
        ? user.name.trim().split(' ').last
        : 'bạn';
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Brand Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const TriplyLogo(iconSize: 36, fontSize: 20),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Chào $greeting',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => context.push('/sos'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.errorBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.sos_rounded, color: AppColors.error, size: 16),
                              SizedBox(width: 3),
                              Text(
                                'SOS',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              greeting.isNotEmpty ? greeting[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Journey Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tìm chuyến xe khách',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.successBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Đảm bảo có chỗ',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Origin & Destination Box with Floating Swap Button
                          Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              Column(
                                children: [
                                  // Origin
                                  InkWell(
                                    onTap: () async {
                                      final result = await _showCityPicker(context, 'Chọn điểm khởi hành', _from);
                                      if (result != null) setState(() => _from = result);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(14, 11, 52, 11),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSecondary,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.trip_origin_rounded,
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Điểm đi',
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _from,
                                                  style: const TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Destination
                                  InkWell(
                                    onTap: () async {
                                      final result = await _showCityPicker(context, 'Chọn điểm đến', _to);
                                      if (result != null) setState(() => _to = result);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(14, 11, 52, 11),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSecondary,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: AppColors.successBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              size: 17,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Điểm đến',
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _to,
                                                  style: const TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Swap Button
                              Positioned(
                                right: 12,
                                child: Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: _swapLocations,
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                                      ),
                                      child: const Icon(
                                        Icons.swap_vert_rounded,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Date Picker with Quick Today / Tomorrow toggles
                          InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Ngày khởi hành',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(_selectedDate),
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _DateQuickChip(
                                        label: 'Hôm nay',
                                        selected: _isSameDay(_selectedDate, today),
                                        onTap: () => setState(() => _selectedDate = today),
                                      ),
                                      const SizedBox(width: 6),
                                      _DateQuickChip(
                                        label: 'Ngày mai',
                                        selected: _isSameDay(_selectedDate, tomorrow),
                                        onTap: () => setState(() => _selectedDate = tomorrow),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Primary Search CTA
                          PrimaryButton(
                            text: 'Tìm chuyến xe',
                            icon: Icons.search_rounded,
                            isLoading: _isSearching,
                            onPressed: _searchTrips,
                            height: 50,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Triply Smart Assistant Banner Card
                    InkWell(
                      onTap: () => context.push('/assistant'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Trợ lý đặt vé Triply',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      StatusBadge(
                                        label: '24/7',
                                        type: BadgeType.primary,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Tìm chuyến, chọn ghế và tra vé tức thì bằng hội thoại',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick Services Row
                    Row(
                      children: [
                        Expanded(
                          child: _QuickServiceTile(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Vé của tôi',
                            onTap: () => context.go('/tickets'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickServiceTile(
                            icon: Icons.auto_awesome_outlined,
                            label: 'AI Vision',
                            onTap: () => context.push('/vision'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickServiceTile(
                            icon: Icons.history_rounded,
                            label: 'Lịch sử',
                            onTap: () => context.push('/trip-history'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickServiceTile(
                            icon: Icons.support_agent_rounded,
                            label: 'Hỗ trợ',
                            onTap: () => context.push('/assistant'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Popular Routes Section
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tuyến đường phổ biến',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Chạm để tìm nhanh',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 186,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _popularRoutes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final route = _popularRoutes[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _from = route['from']!;
                                _to = route['to']!;
                              });
                              _searchTrips();
                            },
                            child: Container(
                              width: 175,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppColors.cardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 96,
                                    width: double.infinity,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: route['image'] != null
                                              ? Image.asset(
                                                  route['image']!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: AppColors.primaryLight,
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.directions_bus_rounded,
                                                        size: 36,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: AppColors.primaryLight,
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.directions_bus_rounded,
                                                      size: 36,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        if (route['badge'] != null)
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                route['badge']!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(11),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${route['from']} → ${route['to']}',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Từ ${route['price']}',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (route['duration'] != null)
                                              Text(
                                                route['duration']!,
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
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
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Promo Section
                    const Text(
                      'Ưu đãi hành trình',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Giảm ngay 15% cho khách hàng mới',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Nhập mã: TRIPLY15 • Áp dụng mọi tuyến liên tỉnh',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AppNavBar(currentIndex: _selectedTab),
          ],
        ),
      ),
    );
  }

  Future<String?> _showCityPicker(BuildContext context, String title, String current) async {
    final cities = await _fetchLocations();
    if (!mounted) return null;
    final searchController = TextEditingController();
    List<String> filtered = List.from(cities);

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (context, scrollController) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm tỉnh / thành phố...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (q) => setModalState(() {
                      filtered = cities
                          .where((c) => c.toLowerCase().contains(q.toLowerCase()))
                          .toList();
                    }),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 60,
                      color: AppColors.borderLight,
                    ),
                    itemBuilder: (context, index) {
                      final city = filtered[index];
                      final isSelected = city == current;
                      return ListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 17,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          city,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontSize: 14.5,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                            : null,
                        onTap: () => Navigator.pop(context, city),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateQuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateQuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuickServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickServiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
