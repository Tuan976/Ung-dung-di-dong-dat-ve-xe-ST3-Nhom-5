import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../core/config/api_config.dart';
import '../../widgets/app_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _from = 'Hà Nội';
  String _to = 'Hải Phòng';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int _selectedTab = 0;

  final List<Map<String, String>> _popularRoutes = [
    {'from': 'Hà Nội', 'to': 'Hải Phòng', 'price': '180.000đ', 'image': 'assets/images/route_hanoi_haiphong.jpg'},
    {'from': 'TP. Hồ Chí Minh', 'to': 'Đà Lạt', 'price': '250.000đ', 'image': 'assets/images/route_hcm_dalat.jpg'},
    {'from': 'Hà Nội', 'to': 'Đà Nẵng', 'price': '350.000đ', 'image': 'assets/images/route_hanoi_danang.jpg'},
    {'from': 'TP. Hồ Chí Minh', 'to': 'Nha Trang', 'price': '200.000đ', 'image': 'assets/images/route_hcm_nhatrang.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
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
      } catch (e) {
        debugPrint('Lỗi lấy vị trí: $e');
      }
    }
  }

  Future<void> _guessCityFromLocation(double lat, double lon) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'WebDatVeXeApp/1.0',
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
            // Find closest match in available cities
            final match = availableCities.cast<String?>().firstWhere(
              (c) => c!.toLowerCase().contains(city!.toLowerCase()) || city!.toLowerCase().contains(c.toLowerCase()),
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
    // Fallback nếu không kết nối được
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
      'Cam Ranh', 'Sa Pa', 'Hạ Long', 'Điện Biên Phủ',
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF0B192C)),
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

  void _searchTrips() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    context.push('/search_results?from=$_from&to=$_to&date=$dateStr');
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final greeting = user?.name != null ? user!.name.split(' ').last : 'bạn';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/sos'),
        backgroundColor: Colors.red,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.sos, color: Colors.white, size: 30),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header greeting
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              const Text(
                                'Xin chào 👋',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                '$greeting!',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 20,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B192C),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  greeting.isNotEmpty ? greeting[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search card
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x0D0F172A),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 16,
                          children: [
                            const Text(
                              'Tìm chuyến xe liên tỉnh',
                              style: TextStyle(
                                color: Color(0xFF0B192C),
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            // From / To
                            Column(
                              spacing: 8,
                              children: [
                                // From
                                GestureDetector(
                                  onTap: () async {
                                    final result = await _showCityPicker(context, 'Điểm đi', _from);
                                    if (result != null) setState(() => _from = result);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: ShapeDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      shape: RoundedRectangleBorder(
                                        side: const BorderSide(width: 1, color: Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      spacing: 12,
                                      children: [
                                        const Icon(Icons.my_location, size: 20, color: Color(0xFF00639B)),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Điểm đi', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                                              Text(_from, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Swap button
                                Center(
                                  child: GestureDetector(
                                    onTap: _swapLocations,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: ShapeDecoration(
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          side: const BorderSide(width: 1, color: Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Icon(Icons.swap_vert, size: 18, color: Color(0xFF0B192C)),
                                    ),
                                  ),
                                ),

                                // To
                                GestureDetector(
                                  onTap: () async {
                                    final result = await _showCityPicker(context, 'Điểm đến', _to);
                                    if (result != null) setState(() => _to = result);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: ShapeDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      shape: RoundedRectangleBorder(
                                        side: const BorderSide(width: 1, color: Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      spacing: 12,
                                      children: [
                                        const Icon(Icons.location_on, size: 20, color: Color(0xFFEF4444)),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Điểm đến', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                                              Text(_to, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Date picker
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: Container(
                                width: double.infinity,
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(width: 1, color: Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  spacing: 12,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 20, color: Color(0xFF94A3B8)),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Ngày khởi hành', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                                          Text(_formatDate(_selectedDate), style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Search button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _searchTrips,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0B192C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Tìm chuyến',
                                  style: TextStyle(fontSize: 15, fontFamily: 'Inter', fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Popular routes
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tuyến phổ biến',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: const Text(
                                  'Xem tất cả',
                                  style: TextStyle(color: Color(0xFF00639B), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 180,
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
                                    width: 160,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: ShapeDecoration(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      shadows: [BoxShadow(color: const Color(0x0D0F172A), blurRadius: 12, offset: const Offset(0, 4))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 90,
                                          width: double.infinity,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: const BoxDecoration(),
                                          child: route['image'] != null
                                            ? Image.asset(
                                                route['image']!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 90,
                                              )
                                            : Container(
                                                color: const Color(0xFFE0F2FE),
                                                child: Center(
                                                  child: Icon(Icons.directions_bus, size: 40, color: const Color(0xFF0B192C).withValues(alpha: 0.4)),
                                                ),
                                              ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            spacing: 4,
                                            children: [
                                              Text(
                                                '${route['from']} → ${route['to']}',
                                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Từ ${route['price']}',
                                                style: const TextStyle(color: Color(0xFF00639B), fontSize: 12, fontWeight: FontWeight.w700),
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
                        ],
                      ),
                    ),

                    // Promo banner
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          const Text(
                            'Ưu đãi độc quyền',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(width: 1, color: Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              spacing: 12,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: ShapeDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.local_offer, color: Color(0xFF0B192C), size: 24),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    spacing: 2,
                                    children: const [
                                      Text(
                                        'Giảm ngay 15% cho bạn mới',
                                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        'Nhập mã: VEXEMOI • Hạn dùng 31/12',
                                        style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w400),
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
    final searchController = TextEditingController();
    List<String> filtered = List.from(cities);

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (context, scrollController) => Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm tỉnh/thành phố...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0B192C)),
                      ),
                    ),
                    onChanged: (q) => setModalState(() {
                      filtered = cities.where((c) =>
                        c.toLowerCase().contains(q.toLowerCase())).toList();
                    }),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final city = filtered[index];
                      final isSelected = city == current;
                      return ListTile(
                        leading: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0B192C) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            size: 16,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        title: Text(
                          city,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF00639B), size: 20)
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
