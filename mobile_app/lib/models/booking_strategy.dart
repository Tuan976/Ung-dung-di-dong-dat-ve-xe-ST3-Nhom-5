enum BookingMode {
  standard,
  mapStops,
  custom,
}

typedef RouteBookingStrategy = BookingStrategy;

class BookingStrategy {
  final BookingMode mode;
  final String? routeId;
  final String? routeCode;
  final String direction; // 'forward' | 'reverse'
  final bool hasMapConfig;
  final bool fallbackToStandard;
  final String? dbOrigin;
  final String? dbDestination;
  final String? originDisplay;
  final String? destinationDisplay;
  final String? highway;
  final double? distanceKm;
  final String? estimatedDuration;
  final String? message;

  const BookingStrategy({
    required this.mode,
    this.routeId,
    this.routeCode,
    this.direction = 'forward',
    this.hasMapConfig = false,
    this.fallbackToStandard = true,
    this.dbOrigin,
    this.dbDestination,
    this.originDisplay,
    this.destinationDisplay,
    this.highway,
    this.distanceKm,
    this.estimatedDuration,
    this.message,
  });

  factory BookingStrategy.standard({String? from, String? to, String? message}) {
    return BookingStrategy(
      mode: BookingMode.standard,
      hasMapConfig: false,
      fallbackToStandard: true,
      dbOrigin: from,
      dbDestination: to,
      originDisplay: from,
      destinationDisplay: to,
      message: message ?? 'Tuyến sử dụng phương thức đặt vé phổ thông.',
    );
  }

  factory BookingStrategy.fromJson(Map<String, dynamic> json) {
    final modeStr = json['booking_mode'] as String? ?? 'standard';
    BookingMode mode;
    switch (modeStr) {
      case 'map_stops':
        mode = BookingMode.mapStops;
        break;
      case 'custom':
        mode = BookingMode.custom;
        break;
      default:
        mode = BookingMode.standard;
    }

    return BookingStrategy(
      mode: mode,
      routeId: json['route_id'] as String?,
      routeCode: json['route_code'] as String?,
      direction: json['direction'] as String? ?? 'forward',
      hasMapConfig: json['has_map_config'] as bool? ?? false,
      fallbackToStandard: json['fallback_to_standard'] as bool? ?? true,
      dbOrigin: json['db_origin'] as String?,
      dbDestination: json['db_destination'] as String?,
      originDisplay: json['origin_display'] as String?,
      destinationDisplay: json['destination_display'] as String?,
      highway: json['highway'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      estimatedDuration: json['estimated_duration'] as String?,
      message: json['message'] as String?,
    );
  }
}
