class TripInfo {
  final int id;
  final String startPoint;
  final String endPoint;
  final String companyName;
  final String departureTime;

  TripInfo({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.companyName,
    required this.departureTime,
  });

  factory TripInfo.fromJson(Map<String, dynamic> json) {
    return TripInfo(
      id: json['id'] ?? 0,
      startPoint: json['start_point'] ?? '',
      endPoint: json['end_point'] ?? '',
      companyName: json['company_name'] ?? '',
      departureTime: json['departure_time'] ?? '',
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
  });

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isHold => status.toUpperCase() == 'HOLD';
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';

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
