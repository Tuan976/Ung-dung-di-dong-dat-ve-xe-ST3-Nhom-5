import 'dart:math';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../models/sos_models.dart';

class SosException implements Exception {
  final String message;
  final int? statusCode;
  const SosException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Một lần định vị. Không bao giờ bịa tọa độ: nếu không lấy được thì [hasFix] = false.
class LocationFix {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String permission; // granted | whileInUse | always | denied | deniedForever | serviceDisabled | unknown
  final String? error;

  const LocationFix({this.latitude, this.longitude, this.accuracy, required this.permission, this.error});

  bool get hasFix => latitude != null && longitude != null;
  bool get permissionGranted => permission == 'whileInUse' || permission == 'always' || permission == 'granted';
}

class DeviceIdentity {
  static String? _cached;

  static Future<String> id() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var v = prefs.getString('sos_device_id');
    if (v == null || v.isEmpty) {
      final r = Random.secure();
      v = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString('sos_device_id', v);
    }
    _cached = v;
    return v;
  }
}

class SosService {
  final ApiClient _api;
  SosService(this._api);

  // ---------------------------------------------------------------- location
  static Future<LocationFix> locateOnce({bool requestPermission = true, Duration timeout = const Duration(seconds: 8)}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFix(permission: 'serviceDisabled', error: 'Dịch vụ vị trí (GPS) đang tắt');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && requestPermission) {
        perm = await Geolocator.requestPermission();
      }
      final name = _permName(perm);
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return LocationFix(permission: name, error: 'Chưa được cấp quyền vị trí');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
      return LocationFix(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        permission: name,
      );
    } catch (e) {
      LocationPermission? perm;
      try {
        perm = await Geolocator.checkPermission();
      } catch (_) {}
      return LocationFix(permission: perm == null ? 'unknown' : _permName(perm), error: 'Không lấy được vị trí GPS');
    }
  }

  static String _permName(LocationPermission p) {
    switch (p) {
      case LocationPermission.whileInUse:
        return 'whileInUse';
      case LocationPermission.always:
        return 'always';
      case LocationPermission.deniedForever:
        return 'deniedForever';
      case LocationPermission.denied:
        return 'denied';
      default:
        return 'unknown';
    }
  }

  // --------------------------------------------------------------------- API
  SosException _toException(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return SosException(data['message'] as String, statusCode: e.response?.statusCode);
      }
      return SosException('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.', statusCode: e.response?.statusCode);
    }
    return SosException(e.toString());
  }

  Map<String, dynamic> _data(Response r) {
    if (r.data is Map && r.data['success'] == true) {
      return Map<String, dynamic>.from(r.data['data'] as Map);
    }
    throw SosException((r.data is Map ? r.data['message'] : null) ?? 'Máy chủ từ chối yêu cầu', statusCode: r.statusCode);
  }

  /// Chỉ trả về thành công khi backend ĐÃ xác nhận lưu sự kiện.
  Future<SosIncident> createSos({
    LocationFix? fix,
    String incidentType = 'general',
    required String idempotencyKey,
  }) async {
    try {
      final deviceId = await DeviceIdentity.id();
      final r = await _api.post(
        '/sos',
        data: {
          if (fix != null && fix.hasFix) 'lat': fix.latitude,
          if (fix != null && fix.hasFix) 'lng': fix.longitude,
          if (fix != null && fix.hasFix && fix.accuracy != null) 'accuracy': fix.accuracy,
          'incident_type': incidentType,
          'idempotency_key': idempotencyKey,
          'device_id': deviceId,
        },
      );
      return SosIncident.fromJson(_data(r));
    } catch (e) {
      throw e is SosException ? e : _toException(e);
    }
  }

  Future<SosIncident?> getActive() async {
    try {
      final d = _data(await _api.get('/sos/active'));
      final inc = d['incident'];
      return inc == null ? null : SosIncident.fromJson(Map<String, dynamic>.from(inc as Map));
    } catch (e) {
      throw e is SosException ? e : _toException(e);
    }
  }

  Future<SosIncident> getIncident(String eventId) async {
    try {
      return SosIncident.fromJson(_data(await _api.get('/sos/$eventId')));
    } catch (e) {
      throw e is SosException ? e : _toException(e);
    }
  }

  Future<SosIncident> updateLocation(String eventId, LocationFix fix) async {
    if (!fix.hasFix) throw const SosException('Chưa xác định được vị trí GPS');
    try {
      final r = await _api.post('/sos/$eventId/location', data: {
        'lat': fix.latitude,
        'lng': fix.longitude,
        if (fix.accuracy != null) 'accuracy': fix.accuracy,
      });
      return SosIncident.fromJson(_data(r));
    } catch (e) {
      throw e is SosException ? e : _toException(e);
    }
  }

  /// resolution: 'resolved' (đã an toàn) hoặc 'cancelled' (báo nhầm). Lịch sử không bị xóa.
  Future<SosIncident> resolve(String eventId, {String resolution = 'resolved'}) async {
    try {
      final r = await _api.post('/sos/$eventId/resolve', data: {'resolution': resolution});
      return SosIncident.fromJson(_data(r));
    } catch (e) {
      throw e is SosException ? e : _toException(e);
    }
  }

  Future<SosAlert> acknowledge(String eventId) async {
    try {
      return SosAlert.fromJson(_data(await _api.post('/sos/$eventId/acknowledge', data: {})));
    } catch (e) {
      throw e is SosException ? e : _toException(e);
    }
  }

  /// response: 'helping' hoặc 'cannot_help'.
  Future<SosAlert> respond(String eventId, String response) async {
    try {
      return SosAlert.fromJson(_data(await _api.post('/sos/$eventId/respond', data: {'response': response})));
    } catch (e) {
      throw e is SosException ? e : _toException(e);
    }
  }
}
