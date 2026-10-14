DateTime? _parseUtc(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

/// Số liệu phân phối do server xác nhận bằng bằng chứng (không suy đoán ở client).
class SosDelivery {
  final int inZone;
  final int delivered;
  final int acknowledged;
  final int responding;

  const SosDelivery({this.inZone = 0, this.delivered = 0, this.acknowledged = 0, this.responding = 0});

  factory SosDelivery.fromJson(Map<String, dynamic>? j) => SosDelivery(
        inZone: (j?['in_zone_devices'] ?? 0) as int,
        delivered: (j?['delivered'] ?? 0) as int,
        acknowledged: (j?['acknowledged'] ?? 0) as int,
        responding: (j?['responding'] ?? 0) as int,
      );
}

/// Sự kiện SOS nhìn từ phía người gặp nguy hiểm.
class SosIncident {
  final String eventId;
  final String status; // active | resolved | cancelled | expired
  final String incidentType;
  final String locationStatus; // known | unknown
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? address;
  final DateTime? createdAt;
  final DateTime? lastLocationUpdateAt;
  final DateTime? resolvedAt;
  final bool distributionSuppressed;
  final double currentRadiusM;
  final SosDelivery delivery;
  final bool duplicate;

  final bool isLegacyBackend;

  const SosIncident({
    required this.eventId,
    required this.status,
    required this.incidentType,
    required this.locationStatus,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.address,
    this.createdAt,
    this.lastLocationUpdateAt,
    this.resolvedAt,
    this.distributionSuppressed = false,
    this.currentRadiusM = 0,
    this.delivery = const SosDelivery(),
    this.duplicate = false,
    this.isLegacyBackend = false,
  });

  bool get isActive => status == 'active';
  bool get hasLocation => locationStatus == 'known' && latitude != null && longitude != null;

  factory SosIncident.fromJson(Map<String, dynamic> j) {
    final bool isLegacy = j['event_id'] == null;
    return SosIncident(
      eventId: (j['event_id'] ?? 'sos-${DateTime.now().millisecondsSinceEpoch}') as String,
      status: (j['status'] ?? 'active') as String,
      incidentType: (j['incident_type'] ?? 'general') as String,
      locationStatus: (j['location_status'] ?? (j['latitude'] != null || j['lat'] != null ? 'known' : 'unknown')) as String,
      latitude: _toDouble(j['latitude'] ?? j['lat']),
      longitude: _toDouble(j['longitude'] ?? j['lng']),
      accuracyMeters: _toDouble(j['accuracy_meters'] ?? j['accuracy']),
      address: j['address'] as String?,
      createdAt: _parseUtc(j['created_at']) ?? DateTime.now(),
      lastLocationUpdateAt: _parseUtc(j['last_location_update_at']),
      resolvedAt: _parseUtc(j['resolved_at']),
      distributionSuppressed: (j['distribution_suppressed'] ?? false) as bool,
      currentRadiusM: (_toDouble(j['current_radius_m']) ?? 0),
      delivery: SosDelivery.fromJson(j['delivery'] as Map<String, dynamic>?),
      duplicate: (j['duplicate'] ?? false) as bool,
      isLegacyBackend: isLegacy,
    );
  }
}

/// Cảnh báo SOS nhìn từ phía người ở gần. Không chứa thông tin cá nhân của người gửi.
class SosAlert {
  final String eventId;
  final String status;
  final String incidentType;
  final int? distanceM;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? area;
  final DateTime? createdAt;
  final DateTime? locationUpdatedAt;
  final DateTime? resolvedAt;
  final String myStatus; // queued|delivered|acknowledged|responding|declined

  const SosAlert({
    required this.eventId,
    required this.status,
    required this.incidentType,
    this.distanceM,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.area,
    this.createdAt,
    this.locationUpdatedAt,
    this.resolvedAt,
    this.myStatus = 'delivered',
  });

  bool get isActive => status == 'active';

  factory SosAlert.fromJson(Map<String, dynamic> j) => SosAlert(
        eventId: j['event_id'] as String,
        status: (j['status'] ?? 'active') as String,
        incidentType: (j['incident_type'] ?? 'general') as String,
        distanceM: (j['distance_m'] as num?)?.toInt(),
        latitude: _toDouble(j['latitude']),
        longitude: _toDouble(j['longitude']),
        accuracyMeters: _toDouble(j['accuracy_meters']),
        area: j['area'] as String?,
        createdAt: _parseUtc(j['created_at']),
        locationUpdatedAt: _parseUtc(j['location_updated_at']),
        resolvedAt: _parseUtc(j['resolved_at']),
        myStatus: (j['my_status'] ?? 'delivered') as String,
      );
}

const Map<String, String> kSosIncidentTypeLabels = {
  'general': 'Nguy hiểm khác',
  'accident': 'Tai nạn',
  'medical': 'Y tế khẩn cấp',
  'threat': 'Bị đe dọa / tấn công',
};
