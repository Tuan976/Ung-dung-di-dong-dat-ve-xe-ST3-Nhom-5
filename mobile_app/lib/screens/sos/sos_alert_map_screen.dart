import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/sos_models.dart';
import '../../services/nearby_alert_service.dart';
import '../../services/sos_service.dart';

/// Hiển thị vị trí sự cố cho người nhận cảnh báo (chỉ người nằm trong danh sách phân phối do server xác định).
class SosAlertMapScreen extends StatefulWidget {
  final String eventId;
  const SosAlertMapScreen({super.key, required this.eventId});

  @override
  State<SosAlertMapScreen> createState() => _SosAlertMapScreenState();
}

class _SosAlertMapScreenState extends State<SosAlertMapScreen> {
  static const _brand = Color(0xFFFF6B00);
  static const _danger = Color(0xFFD32F2F);
  final MapController _map = MapController();
  LocationFix? _me;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  Future<void> _locateMe() async {
    // Chỉ dùng vị trí nếu người dùng đã cấp quyền; không tự xin lại trong màn hình này.
    final fix = await SosService.locateOnce(requestPermission: false);
    if (!mounted) return;
    setState(() {
      _me = fix;
      _locating = false;
    });
  }

  String _fmtTime(DateTime? t) => t == null ? 'chưa có' : DateFormat('HH:mm:ss dd/MM').format(t);

  Future<void> _openExternalMap(SosAlert a) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${a.latitude},${a.longitude}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được ứng dụng bản đồ trên thiết bị này')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, SosAlert>>(
      valueListenable: NearbyAlertService.instance.alerts,
      builder: (context, alerts, _) {
        final a = alerts[widget.eventId];
        if (a == null || a.latitude == null || a.longitude == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vị trí sự cố')),
            body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Không có dữ liệu vị trí cho cảnh báo này.'))),
          );
        }
        final incident = LatLng(a.latitude!, a.longitude!);
        LatLng? me;
        double? meters;
        if (_me != null && _me!.hasFix) {
          me = LatLng(_me!.latitude!, _me!.longitude!);
          meters = Geolocator.distanceBetween(incident.latitude, incident.longitude, me.latitude, me.longitude);
        }
        final distText = meters != null
            ? (meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '${(meters / 10).round() * 10} m')
            : (a.distanceM != null ? '${a.distanceM} m' : 'chưa rõ');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vị trí sự cố'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
          ),
          body: Column(
            children: [
              if (!a.isActive)
                Container(
                  width: double.infinity,
                  color: Colors.green.shade50,
                  padding: const EdgeInsets.all(10),
                  child: const Text('Sự cố này đã được kết thúc.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              Expanded(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(initialCenter: incident, initialZoom: 16, minZoom: 5, maxZoom: 18),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.nhom5.vexemobile',
                      maxZoom: 19,
                    ),
                    if (a.accuracyMeters != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: incident,
                          radius: a.accuracyMeters!,
                          useRadiusInMeter: true,
                          color: _danger.withValues(alpha: 0.12),
                          borderColor: _danger.withValues(alpha: 0.5),
                          borderStrokeWidth: 1.5,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: incident,
                        width: 48,
                        height: 48,
                        child: const Icon(Icons.location_on, color: _danger, size: 44),
                      ),
                      if (me != null)
                        Marker(
                          point: me,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Khoảng cách ước tính: $distText', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        _locating
                            ? 'Đang xác định vị trí của bạn...'
                            : (me == null ? 'Chưa có vị trí của bạn (chưa cấp quyền hoặc không có GPS) - khoảng cách lấy theo thời điểm cảnh báo.' : 'Vị trí của bạn: chấm xanh'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Text('Vị trí sự cố cập nhật lúc: ${_fmtTime(a.locationUpdatedAt)}', style: const TextStyle(fontSize: 13)),
                      if (a.area != null && a.area!.isNotEmpty) Text('Khu vực gần đúng: ${a.area}', style: const TextStyle(fontSize: 13)),
                      if (a.accuracyMeters != null)
                        Text('Vị trí có thể sai lệch khoảng ${a.accuracyMeters!.round()} m (vòng tròn đỏ).',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      const Text(
                        'Đường đi ngắn nhất chưa chắc là đường an toàn nhất. Hãy ưu tiên an toàn của bạn và gọi 113 / 115 khi cần.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openExternalMap(a),
                          icon: const Icon(Icons.directions),
                          label: const Text('Mở ứng dụng bản đồ để xem đường đi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
