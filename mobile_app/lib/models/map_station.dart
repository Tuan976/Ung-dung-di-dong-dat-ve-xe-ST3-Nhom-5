import 'package:latlong2/latlong.dart';

/// Đại diện cho một điểm dừng/trạm đón trả khách trên bản đồ
class MapStation {
  final String id;
  final String routeId;
  final String area;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String stopType; // 'pickup', 'dropoff', 'both'
  final int sequence;
  final bool isActive;
  final String description;
  double? distanceFromUser; // khoảng cách km tính từ GPS người dùng

  MapStation({
    required this.id,
    required this.routeId,
    required this.area,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.stopType,
    required this.sequence,
    required this.isActive,
    required this.description,
    this.distanceFromUser,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  factory MapStation.fromJson(Map<String, dynamic> json) {
    return MapStation(
      id: json['id']?.toString() ?? '',
      routeId: json['route_id']?.toString() ?? 'sg_cj',
      area: json['area']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      stopType: json['stop_type']?.toString() ?? 'both',
      sequence: (json['sequence'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      description: json['description']?.toString() ?? '',
      distanceFromUser: (json['distance_from_user'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'area': area,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'stop_type': stopType,
      'sequence': sequence,
      'is_active': isActive,
      'description': description,
    };
  }
}

/// Thông tin tuyến đường liên tỉnh hỗ trợ bản đồ
class MapRouteInfo {
  final String id;
  final String routeCode;
  final String name;
  final String origin;
  final String destination;
  final String dbOrigin;
  final String dbDestination;
  final double distanceKm;
  final String estimatedDuration;
  final String highway;
  final String description;
  final List<LatLng> polyline;

  MapRouteInfo({
    required this.id,
    required this.routeCode,
    required this.name,
    required this.origin,
    required this.destination,
    required this.dbOrigin,
    required this.dbDestination,
    required this.distanceKm,
    required this.estimatedDuration,
    required this.highway,
    required this.description,
    required this.polyline,
  });

  factory MapRouteInfo.fromJson(Map<String, dynamic> json) {
    final rawPolyline = json['polyline'] as List<dynamic>? ?? [];
    final List<LatLng> parsedPolyline = [];
    for (final item in rawPolyline) {
      if (item is List && item.length >= 2) {
        parsedPolyline.add(LatLng(
          (item[0] as num).toDouble(),
          (item[1] as num).toDouble(),
        ));
      }
    }

    return MapRouteInfo(
      id: json['id']?.toString() ?? 'sg_cj',
      routeCode: json['route_code']?.toString() ?? 'SG-CJ',
      name: json['name']?.toString() ?? 'Sài Gòn ↔ Cư Jút',
      origin: json['origin']?.toString() ?? 'Sài Gòn',
      destination: json['destination']?.toString() ?? 'Cư Jút',
      dbOrigin: json['db_origin']?.toString() ?? 'TP. Hồ Chí Minh',
      dbDestination: json['db_destination']?.toString() ?? 'Cư Jut',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 310.0,
      estimatedDuration: json['estimated_duration']?.toString() ?? '7 giờ 30 phút',
      highway: json['highway']?.toString() ?? 'Quốc lộ 13 - Quốc lộ 14 (Đường Hồ Chí Minh)',
      description: json['description']?.toString() ?? '',
      polyline: parsedPolyline,
    );
  }
}
