class Trip {
  final int id;
  final String routeName;
  final String companyName;
  final String departureDate;
  final String departureTime;
  final String arrivalTime;
  final String departureStation;
  final String arrivalStation;
  final double price;
  final int availableSeats;
  final int totalSeats;
  final List<String> bookedSeats;
  final List<String>? seatMap;
  final String busType;

  Trip({
    required this.id,
    required this.routeName,
    required this.companyName,
    required this.departureDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.departureStation,
    required this.arrivalStation,
    required this.price,
    required this.availableSeats,
    required this.totalSeats,
    required this.bookedSeats,
    this.seatMap,
    required this.busType,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      routeName: json['route_name'] ?? '',
      companyName: json['company_name'] ?? '',
      departureDate: json['departure_date'] ?? '',
      departureTime: json['departure_time'] ?? '',
      arrivalTime: json['arrival_time'] ?? '',
      departureStation: json['departure_station'] ?? '',
      arrivalStation: json['arrival_station'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      availableSeats: json['available_seats'] ?? 0,
      totalSeats: json['total_seats'] ?? 0,
      bookedSeats: List<String>.from(json['booked_seats'] ?? []),
      seatMap: json['seat_map'] != null ? List<String>.from(json['seat_map']) : null,
      busType: json['bus_type'] ?? '',
    );
  }
}
