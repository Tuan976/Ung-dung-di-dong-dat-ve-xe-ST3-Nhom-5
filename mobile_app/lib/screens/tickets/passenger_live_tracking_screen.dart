import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../services/communication_service.dart';
import '../communication/trip_chat_screen.dart';
import '../communication/in_app_call_screen.dart';

class PassengerLiveTrackingScreen extends StatefulWidget {
  final int bookingId;
  final String? ticketCode;

  const PassengerLiveTrackingScreen({
    super.key,
    required this.bookingId,
    this.ticketCode,
  });

  @override
  State<PassengerLiveTrackingScreen> createState() => _PassengerLiveTrackingScreenState();
}

class _PassengerLiveTrackingScreenState extends State<PassengerLiveTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _pollingTimer;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _trackingData;

  LatLng? _busPos;
  LatLng? _passengerPos;
  bool _isSharingLocation = false;
  bool _isTogglingShare = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTrackingData();
    // Tự động làm mới mỗi 6 giây để cập nhật tọa độ xe di chuyển
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _pollLiveLocation();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadTrackingData() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<BookingService>().getLiveBusTracking(widget.bookingId);
      if (mounted) {
        _applyTrackingData(data);
        setState(() {
          _trackingData = data;
          _isLoading = false;
        });

        // Di chuyển camera về xe hoặc điểm đón
        if (_busPos != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(_busPos!, 14.5);
          });
        } else if (_passengerPos != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(_passengerPos!, 14.5);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pollLiveLocation() async {
    try {
      final data = await context.read<BookingService>().getLiveBusTracking(widget.bookingId);
      if (mounted && data.isNotEmpty) {
        setState(() {
          _trackingData = data;
          _applyTrackingData(data);
        });
      }
    } catch (_) {}
  }

  void _applyTrackingData(Map<String, dynamic> data) {
    final trip = data['trip'] as Map<String, dynamic>?;
    if (trip != null) {
      final bLat = trip['bus_lat'];
      final bLng = trip['bus_lng'];
      if (bLat != null && bLng != null) {
        _busPos = LatLng((bLat as num).toDouble(), (bLng as num).toDouble());
      }
    }

    final pLat = data['passenger_lat'];
    final pLng = data['passenger_lng'];
    if (pLat != null && pLng != null) {
      _passengerPos = LatLng((pLat as num).toDouble(), (pLng as num).toDouble());
    }

    _isSharingLocation = data['is_sharing_location'] == true;
  }

  Future<void> _toggleShareLocation() async {
    if (_isTogglingShare) return;
    setState(() => _isTogglingShare = true);

    try {
      if (_isSharingLocation) {
        await context.read<BookingService>().shareLiveLocation(
          bookingId: widget.bookingId,
          isSharing: false,
        );
        if (mounted) {
          setState(() => _isSharingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã dừng chia sẻ vị trí trực tiếp cho bác tài.')),
          );
        }
      } else {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vui lòng cấp quyền vị trí GPS để bật chia sẻ vị trí đón.'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _passengerPos = LatLng(pos.latitude, pos.longitude);

        await context.read<BookingService>().shareLiveLocation(
          bookingId: widget.bookingId,
          isSharing: true,
          latitude: pos.latitude,
          longitude: pos.longitude,
          landmark: 'Vị trí đón của khách',
        );

        if (mounted) {
          setState(() => _isSharingLocation = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🟢 Đã bật chia sẻ vị trí trực tiếp! Bác tài đã thấy bạn trên bản đồ.'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingShare = false);
    }
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gọi đến: $cleanPhone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trackingData?['trip'] as Map<String, dynamic>?;
    final licensePlate = trip?['license_plate'] ?? 'Chưa xếp xe';
    final driverName = trip?['driver_name'] ?? 'Đang phân công';
    final driverPhone = trip?['driver_phone'] ?? '';
    final busType = trip?['bus_type'] ?? 'Xe khách cao cấp';
    final routeName = trip?['route'] ?? 'Lộ trình chuyến xe';
    final isBoarded = _trackingData?['boarding_status'] == 'BOARDED';
    final distanceMeters = _trackingData?['distance_meters'] as num?;
    final etaMinutes = _trackingData?['eta_minutes'] as num?;

    // Marker list
    final markers = <Marker>[];

    // 1. Marker Xe Khách
    if (_busPos != null) {
      markers.add(
        Marker(
          point: _busPos!,
          width: 120,
          height: 95,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge Biển số xe nổi bật màu vàng trên đầu xe
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15), // Vàng biển số xe kinh doanh
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black87, width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Text(
                  licensePlate,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Icon Xe khách xoay và phát xung
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48), // Đỏ hồng nổi bật
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Marker Hành khách / Điểm đón
    if (_passengerPos != null) {
      markers.add(
        Marker(
          point: _passengerPos!,
          width: 120,
          height: 95,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _isSharingLocation ? const Color(0xFF047857) : const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isSharingLocation ? 'VỊ TRÍ CỦA BẠN' : 'ĐIỂM ĐÓN CỦA BẠN',
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isSharingLocation ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSharingLocation ? Colors.green : Colors.blue).withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  _isSharingLocation ? Icons.person_pin_circle : Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Polyline giữa xe và hành khách
    final polylines = <Polyline>[];
    if (_busPos != null && _passengerPos != null) {
      polylines.add(
        Polyline(
          points: [_busPos!, _passengerPos!],
          strokeWidth: 3.5,
          color: const Color(0xFFE11D48).withOpacity(0.65),
        ),
      );
    }

    final initialCenter = _busPos ?? _passengerPos ?? const LatLng(10.7769, 106.7009);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.near_me, color: Color(0xFF38BDF8), size: 16),
                SizedBox(width: 6),
                Text(
                  'THEO DÕI XE TRỰC TIẾP',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            Text(
              routeName,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _pollLiveLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Stack(
              children: [
                // 1. Bản đồ Google Maps Tiles
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 14.5,
                    minZoom: 5.0,
                    maxZoom: 20.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      subdomains: const ['0', '1', '2', '3'],
                      userAgentPackageName: 'com.nhom5.vexemobile',
                      maxZoom: 20,
                    ),
                    if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                    MarkerLayer(markers: markers),
                  ],
                ),

                // 2. Thẻ Thông Báo Trạng Thái Xe & Biển Số (Trên Cùng)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155), width: 1.2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Biển số xe phong cách biển vàng số đen cực rõ
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFACC15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black87, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.directions_bus, size: 14, color: Colors.black),
                                  const SizedBox(width: 4),
                                  Text(
                                    licensePlate,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    busType,
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _busPos != null ? '🟢 Đang truyền GPS trực tiếp' : '⏳ Chờ xe phát tín hiệu GPS...',
                                    style: TextStyle(
                                      color: _busPos != null ? const Color(0xFF4ADE80) : Colors.amberAccent,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFF334155), height: 1),
                        const SizedBox(height: 10),
                        // Khoảng cách & ETA
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, color: Color(0xFF38BDF8), size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  isBoarded
                                      ? 'Bạn đã lên xe'
                                      : (distanceMeters != null
                                          ? 'Khoảng ${(distanceMeters / 1000).toStringAsFixed(1)} km (~$etaMinutes phút)'
                                          : 'Đang tính toán khoảng cách...'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (driverPhone.isNotEmpty)
                              InkWell(
                                onTap: () => _makeCall(driverPhone),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call, color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bác tài ($driverName)',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Text(
                                'Tài xế: $driverName',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Chat button
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TripChatScreen(
                                        bookingId: widget.bookingId,
                                        counterpartName: driverName.isNotEmpty ? driverName : 'Bác tài',
                                        counterpartRole: 'Tài xế xe $licensePlate',
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0E6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFF26A21).withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFF26A21), size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Nhắn tin',
                                        style: TextStyle(
                                          color: Color(0xFFF26A21),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // In-App Call button
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  final user = context.read<AuthService>().currentUser;
                                  final commService = context.read<CommunicationService>();
                                  commService.initiateCall(
                                    bookingId: widget.bookingId,
                                    callerRole: 'PASSENGER',
                                    callerName: user?.name ?? 'Hành khách',
                                    receiverName: driverName.isNotEmpty ? driverName : 'Bác tài',
                                  );

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InAppCallScreen(
                                        bookingId: widget.bookingId,
                                        counterpartName: driverName.isNotEmpty ? driverName : 'Bác tài',
                                        counterpartRole: 'Tài xế xe $licensePlate',
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF26A21),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Gọi qua app',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Thanh Nút Thao Tác Bên Dưới
                Positioned(
                  bottom: 20,
                  left: 14,
                  right: 14,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating Buttons Căn Giữa
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_busPos != null)
                            FloatingActionButton.small(
                              heroTag: 'btn_center_bus',
                              backgroundColor: const Color(0xFFE11D48),
                              tooltip: 'Xem vị trí xe',
                              onPressed: () => _mapController.move(_busPos!, 15.0),
                              child: const Icon(Icons.directions_bus, color: Colors.white, size: 18),
                            ),
                          const SizedBox(width: 8),
                          if (_passengerPos != null)
                            FloatingActionButton.small(
                              heroTag: 'btn_center_passenger',
                              backgroundColor: const Color(0xFF0284C7),
                              tooltip: 'Xem vị trí của tôi',
                              onPressed: () => _mapController.move(_passengerPos!, 15.0),
                              child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Nút Chia sẻ vị trí đón cho bác tài
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B192C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155), width: 1),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isTogglingShare ? null : _toggleShareLocation,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isSharingLocation ? const Color(0xFF047857) : const Color(0xFF1E293B),
                                      shape: BoxShape.circle,
                                    ),
                                    child: _isTogglingShare
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : Icon(
                                            _isSharingLocation ? Icons.location_on : Icons.share_location,
                                            color: _isSharingLocation ? const Color(0xFF4ADE80) : Colors.white70,
                                            size: 18,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isSharingLocation
                                              ? 'ĐANG CHIA SẺ VỊ TRÍ ĐÓN (LIVE)'
                                              : 'CHIA SẺ VỊ TRÍ ĐÓN CHO TÀI XẾ',
                                          style: TextStyle(
                                            color: _isSharingLocation ? const Color(0xFF4ADE80) : Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          _isSharingLocation
                                              ? 'Tài xế nhìn thấy bạn trên bản đồ lộ trình'
                                              : 'Chạm để tài xế thấy bạn đứng đón bên đường',
                                          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isSharingLocation,
                                    activeColor: const Color(0xFF4ADE80),
                                    onChanged: _isTogglingShare ? null : (_) => _toggleShareLocation(),
                                  ),
                                ],
                              ),
                            ),
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
}
