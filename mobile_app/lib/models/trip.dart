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

  static List<String>? _parseSeatMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      final result = <String>[];
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          result.add(item.trim());
        } else if (item is Map) {
          if (item['id'] != null) {
            result.add(item['id'].toString());
          } else if (item['rows'] is List) {
            for (final row in item['rows'] as List) {
              if (row is List) {
                for (final seat in row) {
                  if (seat is Map && seat['id'] != null) {
                    result.add(seat['id'].toString());
                  } else if (seat is String) {
                    result.add(seat);
                  }
                }
              }
            }
          }
        }
      }
      return result;
    }
    if (raw is Map && raw['seats'] is List) {
      return (raw['seats'] as List)
          .whereType<Map>()
          .where((s) => s['id'] != null)
          .map((s) => s['id'].toString())
          .toList();
    }
    return null;
  }

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
      bookedSeats: (json['booked_seats'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      seatMap: _parseSeatMap(json['seat_map']),
      busType: json['bus_type'] ?? '',
    );
  }
}
