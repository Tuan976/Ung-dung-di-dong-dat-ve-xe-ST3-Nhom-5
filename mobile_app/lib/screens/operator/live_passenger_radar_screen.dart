import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../services/company_service.dart';
import '../../services/auth_service.dart';
import '../../services/communication_service.dart';
import '../communication/trip_chat_screen.dart';
import '../communication/in_app_call_screen.dart';

class LivePassengerRadarScreen extends StatefulWidget {
  final int tripId;
  final String? tripRoute;
  final String? busPlate;

  const LivePassengerRadarScreen({
    super.key,
    required this.tripId,
    this.tripRoute,
    this.busPlate,
  });

  @override
  State<LivePassengerRadarScreen> createState() => _LivePassengerRadarScreenState();
}

class _LivePassengerRadarScreenState extends State<LivePassengerRadarScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _refreshTimer;
  Timer? _gpsTimer;

  bool _isLoading = true;
  Map<String, dynamic>? _radarData;
  List<Map<String, dynamic>> _passengers = [];
  Map<String, dynamic>? _trip;

  LatLng? _driverPos;
  double? _driverAccuracy;
  bool _isSendingGps = false;

  Map<String, dynamic>? _selectedPassenger;
  String _filterMode = 'ALL'; // ALL, SHARING, PENDING, BOARDED

  static const Color brandOrange = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _startDriverGpsTracking();
    _loadRadarData();

    // Tự động làm mới dữ liệu hành khách mỗi 6 giây
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) _loadRadarData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDriverGpsTracking() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }

      // Lấy vị trí ban đầu
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _driverPos = LatLng(pos.latitude, pos.longitude);
          _driverAccuracy = pos.accuracy;
        });
        _sendDriverLocationToBackend(pos.latitude, pos.longitude);
      }

      // Định kỳ gửi tọa độ xe lên máy chủ mỗi 6 giây
      _gpsTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
        if (!mounted) return;
        try {
          final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          if (mounted) {
            setState(() {
              _driverPos = LatLng(p.latitude, p.longitude);
              _driverAccuracy = p.accuracy;
            });
            _sendDriverLocationToBackend(p.latitude, p.longitude);
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Error starting driver GPS: $e');
    }
  }

  Future<void> _sendDriverLocationToBackend(double lat, double lng) async {
    if (_isSendingGps) return;
    _isSendingGps = true;
    try {
      await context.read<CompanyService>().updateDriverLocation(
        tripId: widget.tripId,
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
    } finally {
      _isSendingGps = false;
    }
  }

  Future<void> _loadRadarData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final cs = context.read<CompanyService>();
    final data = await cs.getLiveRadar(widget.tripId);
    if (mounted && data != null) {
      setState(() {
        _radarData = data;
        _trip = data['trip'] as Map<String, dynamic>?;
        _passengers = List<Map<String, dynamic>>.from(data['passengers'] ?? []);
        _isLoading = false;

        // Nếu xe có tọa độ trên backend mà app chưa có GPS, gán tạm
        if (_driverPos == null && _trip?['current_lat'] != null && _trip?['current_lng'] != null) {
          _driverPos = LatLng(
            (_trip!['current_lat'] as num).toDouble(),
            (_trip!['current_lng'] as num).toDouble(),
          );
        }
      });
    } else if (!silent && mounted) {
      setState(() => _isLoading = false);
    }
  }

  double _calcDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // meters
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // Tìm hành khách chưa đón gần xe nhất
  Map<String, dynamic>? _getNearestPendingPassenger() {
    if (_driverPos == null || _passengers.isEmpty) return null;

    Map<String, dynamic>? nearest;
    double minDistance = double.infinity;

    for (final p in _passengers) {
      if (p['boarding_status'] == 'BOARDED') continue;

      final pLat = p['effective_lat'] ?? (p['is_sharing_location'] == true ? p['live_lat'] : p['pickup_lat']);
      final pLng = p['effective_lng'] ?? (p['is_sharing_location'] == true ? p['live_lng'] : p['pickup_lng']);

      if (pLat != null && pLng != null) {
        final dist = _calcDistance(
          _driverPos!.latitude,
          _driverPos!.longitude,
          (pLat as num).toDouble(),
          (pLng as num).toDouble(),
        );

        p['_live_distance_m'] = dist;

        if (dist <= 1000 && dist < minDistance) {
          minDistance = dist;
          nearest = p;
        }
      }
    }

    return nearest;
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở cuộc gọi tới: $cleanPhone')),
        );
      }
    }
  }

  Future<void> _confirmBoarding(Map<String, dynamic> pax) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đón khách'),
        content: Text(
          'Đã đón hành khách ${pax['name']} (Ghế ${pax['seat']}) lên xe an toàn?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đã lên xe', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final res = await context.read<CompanyService>().markPassengerBoarded(pax['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']),
            backgroundColor: res['success'] ? Colors.green : Colors.red,
          ),
        );
        _loadRadarData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    // Phân quyền bảo mật: Chỉ cho phép Tài xế, Phụ xe hoặc Quản trị viên
    final hasPermission = user?.isDriver == true ||
        user?.isAssistant == true ||
        user?.isCompany == true;

    if (!hasPermission) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          title: const Text(
            'Từ chối truy cập',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'QUYỀN HẠN BỊ TỪ CHỐI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chức năng Radar & Bản đồ đón khách trực diện chỉ dành riêng cho Tài xế, Phụ xe và Quản trị viên điều hành!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Quay lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final nearestPax = _getNearestPendingPassenger();

    // Chuẩn bị markers cho bản đồ
    final markers = <Marker>[];

    // Marker vị trí xe của tài xế
    if (_driverPos != null) {
      markers.add(
        Marker(
          point: _driverPos!,
          width: 120,
          height: 95,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.45), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: const Text(
                  'XE CỦA BẠN',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Markers vị trí hành khách
    for (final p in _passengers) {
      final isBoarded = p['boarding_status'] == 'BOARDED';
      final isSharing = p['is_sharing_location'] == true;
      final pLat = p['effective_lat'] ?? (isSharing ? p['live_lat'] : p['pickup_lat']);
      final pLng = p['effective_lng'] ?? (isSharing ? p['live_lng'] : p['pickup_lng']);

      if (pLat != null && pLng != null) {
        final pos = LatLng((pLat as num).toDouble(), (pLng as num).toDouble());

        Color markerColor;
        if (isBoarded) {
          markerColor = AppColors.textMuted;
        } else if (isSharing) {
          markerColor = AppColors.success; // Xanh lá cây nhấp nháy cho Live GPS
        } else {
          markerColor = AppColors.info; // Xanh dương cho điểm đón cố định
        }

        markers.add(
          Marker(
            point: pos,
            width: 120,
            height: 95,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPassenger = p);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: markerColor.withOpacity(0.4), blurRadius: 6),
                      ],
                    ),
                    child: Icon(
                      isBoarded
                          ? Icons.check
                          : (isSharing ? Icons.person_pin_circle : Icons.location_on),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isBoarded ? Colors.grey.shade700 : (isSharing ? const Color(0xFF0F766E) : AppColors.secondary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${p['seat']} | ${p['name'].toString().split(' ').last}',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final initialCenter = _driverPos ?? const LatLng(10.7769, 106.7009); // HCM default

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radar, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RADAR ĐÓN KHÁCH TRỰC DIỆN',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                widget.tripRoute ?? (_trip?['route'] ?? 'Chuyến xe #${widget.tripId}'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới vị trí',
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => _loadRadarData(),
          ),
          IconButton(
            tooltip: 'Định vị về xe của bạn',
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            onPressed: () {
              if (_driverPos != null) {
                _mapController.move(_driverPos!, 15.0);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Bản đồ FlutterMap với CartoDB Voyager tiles (CORS OK)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 13.5,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.hutech.datvexe',
                maxZoom: 20,
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // 2. BOX THÔNG BÁO XE ĐANG Ở RẤT GẦN HÀNH KHÁCH (PROXIMITY ALERT)
          if (nearestPax != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _buildProximityAlertBox(nearestPax),
            ),

          // 3. Card chi tiết hành khách khi tài xế bấm vào một Marker trên bản đồ
          if (_selectedPassenger != null && nearestPax?['id'] != _selectedPassenger?['id'])
            Positioned(
              top: nearestPax != null ? 140 : 12,
              left: 12,
              right: 12,
              child: _buildSelectedPassengerCard(_selectedPassenger!),
            ),

          // 4. Panel danh sách hành khách thu nhỏ ở góc dưới
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPassengerSheet(),
          ),

          // Loading indicator
          if (_isLoading)
            const Positioned(
              top: 60,
              right: 20,
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: brandOrange),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // HỘP THÔNG BÁO XE ĐANG Ở RẤT GẦN HÀNH KHÁCH
  Widget _buildProximityAlertBox(Map<String, dynamic> pax) {
    final dist = pax['_live_distance_m'] != null ? (pax['_live_distance_m'] as num).toInt() : 300;
    final isSharing = pax['is_sharing_location'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'XE ĐANG Ở RẤT GẦN HÀNH KHÁCH!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$dist mét',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khách: ${pax['name']} - Ghế ${pax['seat']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Điểm đón: ${pax['pickup_landmark'] ?? pax['pickup'] ?? "Vị trí khách đứng"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isSharing)
                      const Text(
                        '🟢 Đang chia sẻ vị trí trực tiếp',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // In-App Communication Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF0E6),
                    foregroundColor: const Color(0xFFF26A21),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFFFD8BF)),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text('Nhắn tin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripChatScreen(
                          bookingId: pax['id'],
                          counterpartName: pax['name'] ?? 'Hành khách',
                          counterpartRole: 'Hành khách • Ghế ${pax['seat_number'] ?? pax['seat'] ?? "N/A"}',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF26A21),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                  label: const Text('Gọi qua App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    final user = context.read<AuthService>().currentUser;
                    final commService = context.read<CommunicationService>();
                    commService.initiateCall(
                      bookingId: pax['id'],
                      callerRole: 'OPERATOR',
                      callerName: user?.name ?? 'Tài xế',
                      receiverName: pax['name'] ?? 'Hành khách',
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppCallScreen(
                          bookingId: pax['id'],
                          counterpartName: pax['name'] ?? 'Hành khách',
                          counterpartRole: 'Hành khách • Ghế ${pax['seat_number'] ?? pax['seat'] ?? "N/A"}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Gọi di động', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _makePhoneCall(pax['phone'] ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('ĐÃ ĐÓN LÊN XE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _confirmBoarding(pax),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card chi tiết khách khi bấm vào marker trên map
  Widget _buildSelectedPassengerCard(Map<String, dynamic> pax) {
    final isBoarded = pax['boarding_status'] == 'BOARDED';
    final isSharing = pax['is_sharing_location'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isBoarded ? Colors.green.shade100 : (isSharing ? Colors.green.shade50 : Colors.blue.shade50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBoarded ? Icons.check_circle : (isSharing ? Icons.person_pin_circle : Icons.person),
              color: isBoarded ? Colors.green : (isSharing ? const Color(0xFF10B981) : Colors.blue),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${pax['name']} (Ghế ${pax['seat']})',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary),
                ),
                Text(
                  'SĐT: ${pax['phone'] ?? "N/A"}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                Text(
                  isBoarded ? '🟢 Đã đón lên xe' : (isSharing ? '🟢 Đang chia sẻ Live GPS' : '⚪ Chưa đón'),
                  style: TextStyle(
                    color: isBoarded ? Colors.green : (isSharing ? Colors.green.shade700 : Colors.orange),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.blue),
            onPressed: () => _makePhoneCall(pax['phone'] ?? ''),
          ),
          if (!isBoarded)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _confirmBoarding(pax),
              child: const Text('Đón', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () => setState(() => _selectedPassenger = null),
          ),
        ],
      ),
    );
  }

  // SHEET DANH SÁCH HÀNH KHÁCH Ở ĐÁY MÀN HÌNH
  Widget _buildBottomPassengerSheet() {
    final filtered = _passengers.where((p) {
      if (_filterMode == 'SHARING') return p['is_sharing_location'] == true;
      if (_filterMode == 'PENDING') return p['boarding_status'] != 'BOARDED';
      if (_filterMode == 'BOARDED') return p['boarding_status'] == 'BOARDED';
      return true;
    }).toList();

    final boardedCount = _passengers.where((p) => p['boarding_status'] == 'BOARDED').length;
    final sharingCount = _passengers.where((p) => p['is_sharing_location'] == true).length;

    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        children: [
          // Header summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Khách: ${_passengers.length} (Đã đón: $boardedCount)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                if (sharingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🟢 $sharingCount khách bật GPS',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),

          // Filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('Tất cả (${_passengers.length})', 'ALL'),
                const SizedBox(width: 6),
                _buildFilterChip('Đang chia sẻ Live ($sharingCount)', 'SHARING'),
                const SizedBox(width: 6),
                _buildFilterChip('Chưa đón (${_passengers.length - boardedCount})', 'PENDING'),
                const SizedBox(width: 6),
                _buildFilterChip('Đã lên xe ($boardedCount)', 'BOARDED'),
              ],
            ),
          ),

          // List of passengers
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Không có hành khách nào phù hợp bộ lọc.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final p = filtered[idx];
                      final isBoarded = p['boarding_status'] == 'BOARDED';
                      final isSharing = p['is_sharing_location'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isBoarded ? const Color(0xFFF1F5F9) : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSharing ? AppColors.success : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isBoarded ? AppColors.success : (isSharing ? const Color(0xFF10B981) : AppColors.primary),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  p['seat'] ?? '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          p['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSharing) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.gps_fixed, color: Colors.green, size: 12),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    p['pickup_landmark'] ?? p['pickup'] ?? 'Đón tại điểm hẹn',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFFF26A21)),
                              tooltip: 'Nhắn tin',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TripChatScreen(
                                      bookingId: p['id'],
                                      counterpartName: p['name'] ?? 'Hành khách',
                                      counterpartRole: 'Hành khách • Ghế ${p['seat_number'] ?? p['seat'] ?? "N/A"}',
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: Color(0xFFF26A21)),
                              tooltip: 'Gọi qua App',
                              onPressed: () {
                                final user = context.read<AuthService>().currentUser;
                                final commService = context.read<CommunicationService>();
                                commService.initiateCall(
                                  bookingId: p['id'],
                                  callerRole: 'OPERATOR',
                                  callerName: user?.name ?? 'Tài xế',
                                  receiverName: p['name'] ?? 'Hành khách',
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InAppCallScreen(
                                      bookingId: p['id'],
                                      counterpartName: p['name'] ?? 'Hành khách',
                                      counterpartRole: 'Hành khách • Ghế ${p['seat_number'] ?? p['seat'] ?? "N/A"}',
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, size: 18, color: Colors.blue),
                              tooltip: 'Gọi di động',
                              onPressed: () => _makePhoneCall(p['phone'] ?? ''),
                            ),
                            if (!isBoarded)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _confirmBoarding(p),
                                child: const Text('Đón', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String code) {
    final selected = _filterMode == code;
    return InkWell(
      onTap: () => setState(() => _filterMode = code),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

