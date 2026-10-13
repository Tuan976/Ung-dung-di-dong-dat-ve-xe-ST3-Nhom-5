import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/services/notification_service.dart';
import '../models/sos_models.dart';
import 'sos_service.dart';

enum NearbyStatus { stopped, disabled, active, noLocation, offline }

/// Kênh realtime cho người dùng đang mở ứng dụng.
///
/// Mỗi [heartbeatSeconds] (do SERVER cấu hình) gửi heartbeat kèm vị trí (nếu người dùng đã đồng ý
/// và hệ điều hành đã cấp quyền) tới POST /location và nhận về các cảnh báo mà SERVER xác định là
/// nhắm vào thiết bị này. Mất mạng: lùi theo cấp số nhân, tối đa 60 giây giữa các lần thử,
/// khi kết nối lại sẽ lấy đúng trạng thái hiện tại (không nhận bản sao).
class NearbyAlertService {
  NearbyAlertService._();
  static final NearbyAlertService instance = NearbyAlertService._();

  static const String _prefConsent = 'sos_nearby_consent'; // 'on' | 'off'
  static const int _maxBackoffSeconds = 60;

  ApiClient? _api;
  Timer? _timer;
  bool _running = false;
  bool _paused = false;
  bool _inFlight = false;
  bool _consent = false;
  int _failures = 0;
  int _heartbeatSeconds = 10;

  final ValueNotifier<Map<String, SosAlert>> alerts = ValueNotifier({});
  final ValueNotifier<NearbyStatus> status = ValueNotifier(NearbyStatus.stopped);
  final StreamController<SosAlert> _newAlerts = StreamController<SosAlert>.broadcast();

  /// Phát ra đúng MỘT lần cho mỗi event_id (chống trùng khi kết nối lại / nhận lặp).
  Stream<SosAlert> get onNewAlert => _newAlerts.stream;
  final Set<String> _seen = {};

  bool get hasConsent => _consent;

  /// null nếu người dùng chưa quyết định.
  static Future<bool?> readConsent() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_prefConsent);
    if (v == null) return null;
    return v == 'on';
  }

  Future<void> setConsent(bool on, ApiClient api) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefConsent, on ? 'on' : 'off');
    _consent = on;
    if (on) {
      _api = api;
      await start(api);
    } else {
      await stopSharing(api, keepRunningInbox: false);
    }
  }

  Future<void> start(ApiClient api) async {
    _api = api;
    final c = await readConsent();
    _consent = c == true;
    if (!_consent) {
      status.value = NearbyStatus.disabled;
      return;
    }
    if (_running) return;
    _running = true;
    _paused = false;
    _failures = 0;
    // Xin quyền vị trí đúng một lần, sau khi người dùng đã đồng ý chia sẻ
    await SosService.locateOnce(requestPermission: true, timeout: const Duration(seconds: 3));
    _schedule(Duration.zero);
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
  }

  void resume() {
    if (!_running) return;
    _paused = false;
    _schedule(Duration.zero);
  }

  /// Đăng xuất / tắt chia sẻ: dừng timer, xóa vị trí đã lưu ở server và xóa trạng thái cục bộ.
  Future<void> stopSharing(ApiClient api, {bool keepRunningInbox = false}) async {
    _running = false;
    _timer?.cancel();
    status.value = _consent ? NearbyStatus.stopped : NearbyStatus.disabled;
    try {
      await api.post('/location/stop', data: {'clear_token': true});
    } catch (_) {}
    alerts.value = {};
    _seen.clear();
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    if (!_running || _paused) return;
    _timer = Timer(d, _tick);
  }

  Future<void> _tick() async {
    if (!_running || _paused || _inFlight || _api == null) return;
    _inFlight = true;
    try {
      final fix = await SosService.locateOnce(requestPermission: false, timeout: const Duration(seconds: 6));
      final body = <String, dynamic>{
        'permission_status': fix.permission,
        'sharing': true,
        'device_id': await DeviceIdentity.id(),
        if (fix.hasFix) 'lat': fix.latitude,
        if (fix.hasFix) 'lng': fix.longitude,
        if (fix.hasFix && fix.accuracy != null) 'accuracy': fix.accuracy,
      };
      final token = NotificationService().fcmToken;
      if (token != null) body['fcm_token'] = token;

      final r = await _api!.post('/location', data: body);
      final data = (r.data is Map && r.data['success'] == true) ? Map<String, dynamic>.from(r.data['data'] as Map) : null;
      if (data == null) throw Exception('bad response');

      _heartbeatSeconds = ((data['heartbeat_seconds'] as num?)?.toInt() ?? 10).clamp(3, 120);
      _failures = 0;
      status.value = fix.hasFix ? NearbyStatus.active : NearbyStatus.noLocation;
      _applyAlerts((data['alerts'] as List? ?? const []).map((e) => SosAlert.fromJson(Map<String, dynamic>.from(e as Map))).toList());
    } catch (_) {
      _failures++;
      if (_failures >= 2) status.value = NearbyStatus.offline;
    } finally {
      _inFlight = false;
      final delay = _failures == 0
          ? _heartbeatSeconds
          : min(_maxBackoffSeconds, _heartbeatSeconds * pow(2, _failures).toInt());
      _schedule(Duration(seconds: delay));
    }
  }

  void _applyAlerts(List<SosAlert> incoming) {
    final next = Map<String, SosAlert>.from(alerts.value);
    for (final a in incoming) {
      next[a.eventId] = a;
      if (_seen.add(a.eventId) && a.isActive) {
        _newAlerts.add(a);
      }
    }
    alerts.value = next;
  }

  /// Cập nhật cục bộ sau khi người dùng xác nhận / phản hồi (server đã trả về trạng thái mới).
  void updateAlert(SosAlert a) {
    final next = Map<String, SosAlert>.from(alerts.value);
    next[a.eventId] = a;
    alerts.value = next;
  }
}
