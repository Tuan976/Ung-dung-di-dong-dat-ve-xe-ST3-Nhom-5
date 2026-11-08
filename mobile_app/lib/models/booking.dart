class TripInfo {
  final int id;
  final String startPoint;
  final String endPoint;
  final String companyName;
  final String departureTime;
  final String? licensePlate;
  final String? busType;
  final String? status;
  final double? currentLat;
  final double? currentLng;
  final String? driverName;
  final String? driverPhone;

  TripInfo({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.companyName,
    required this.departureTime,
    this.licensePlate,
    this.busType,
    this.status,
    this.currentLat,
    this.currentLng,
    this.driverName,
    this.driverPhone,
  });

  factory TripInfo.fromJson(Map<String, dynamic> json) {
    return TripInfo(
      id: json['id'] ?? 0,
      startPoint: json['start_point'] ?? '',
      endPoint: json['end_point'] ?? '',
      companyName: json['company_name'] ?? '',
      departureTime: json['departure_time'] ?? '',
      licensePlate: json['license_plate'],
      busType: json['bus_type'],
      status: json['status'],
      currentLat: json['current_lat'] != null ? (json['current_lat'] as num).toDouble() : null,
      currentLng: json['current_lng'] != null ? (json['current_lng'] as num).toDouble() : null,
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
    );
  }

  String get routeName => '$startPoint - $endPoint';
}

class Booking {
  final int id;
  final String ticketCode;
  final String seatNumber;
  final String passengerName;
  final String passengerPhone;
  final String status;        // HOLD, CONFIRMED, CANCELLED
  final String paymentStatus; // Unpaid, Paid
  final double ticketPrice;
  final String? bookingTime;
  final String? expiresAt;
  final TripInfo? trip;
  final String boardingStatus; // PENDING, BOARDED
  final bool isSharingLocation;
  final double? liveLat;
  final double? liveLng;
  final String? pickupPoint;
  final String? dropoffPoint;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupLandmark;

  Booking({
    required this.id,
    required this.ticketCode,
    required this.seatNumber,
    required this.passengerName,
    required this.passengerPhone,
    required this.status,
    required this.paymentStatus,
    required this.ticketPrice,
    this.bookingTime,
    this.expiresAt,
    this.trip,
    this.boardingStatus = 'PENDING',
    this.isSharingLocation = false,
    this.liveLat,
    this.liveLng,
    this.pickupPoint,
    this.dropoffPoint,
    this.pickupLat,
    this.pickupLng,
    this.pickupLandmark,
  });

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isHold => status.toUpperCase() == 'HOLD';
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isBoarded => boardingStatus.toUpperCase() == 'BOARDED';

  String get routeName => trip?.routeName ?? 'N/A';
  String get departureTime => trip?.departureTime ?? '';

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? 0,
      ticketCode: json['ticket_code'] ?? '',
      seatNumber: json['seat_number'] ?? '',
      passengerName: json['passenger_name'] ?? '',
      passengerPhone: json['passenger_phone'] ?? '',
      status: json['status'] ?? 'HOLD',
      paymentStatus: json['payment_status'] ?? 'Unpaid',
      ticketPrice: (json['ticket_price'] ?? json['amount'] ?? 0).toDouble(),
      bookingTime: json['booking_time'],
      expiresAt: json['expires_at'],
      trip: json['trip'] != null ? TripInfo.fromJson(json['trip']) : null,
      boardingStatus: json['boarding_status'] ?? 'PENDING',
      isSharingLocation: json['is_sharing_location'] == true,
      liveLat: json['live_lat'] != null ? (json['live_lat'] as num).toDouble() : null,
      liveLng: json['live_lng'] != null ? (json['live_lng'] as num).toDouble() : null,
      pickupPoint: json['pickup_point'],
      dropoffPoint: json['dropoff_point'],
      pickupLat: json['pickup_lat'] != null ? (json['pickup_lat'] as num).toDouble() : null,
      pickupLng: json['pickup_lng'] != null ? (json['pickup_lng'] as num).toDouble() : null,
      pickupLandmark: json['pickup_landmark'],
    );
  }

  /// Used when creating a booking — API response is minimal
  factory Booking.fromCreateResponse(Map<String, dynamic> data, {
    required String seatNumber,
    required String passengerName,
    required String passengerPhone,
  }) {
    return Booking(
      id: data['booking_id'] ?? 0,
      ticketCode: data['ticket_code'] ?? '',
      seatNumber: seatNumber,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      status: data['status'] ?? 'HOLD',
      paymentStatus: 'Unpaid',
      ticketPrice: 0,
      expiresAt: data['expires_at'],
    );
  }
}
