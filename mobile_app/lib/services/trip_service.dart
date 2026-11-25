import '../core/network/api_client.dart';
import '../models/trip.dart';

class TripService {
  final ApiClient _apiClient;

  TripService(this._apiClient);

  /// Chuẩn hóa chuỗi tiếng Việt (chuyển chữ thường Unicode + bỏ dấu + chuẩn hóa tên viết tắt)
  /// để so khớp chính xác mọi tỉnh/thành phố bất kể lỗi SQLite ASCII LOWER() trên server.
  static String _normalizeVn(String input) {
    var s = input.trim().toLowerCase();
    const vietnameseMap = {
      'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'đ': 'd',
      'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    };
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      buffer.write(vietnameseMap[ch] ?? ch);
    }
    s = buffer.toString()
        .replaceAll(RegExp(r'\b(thanh pho|tp\.?|tinh)\b'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s == 'sai gon' || s == 'hcm' || s == 'tphcm') {
      return 'ho chi minh';
    }
    return s;
  }

  static bool _matchesLocation(String actual, String? query) {
    if (query == null || query.trim().isEmpty) return true;
    final normActual = _normalizeVn(actual);
    final normQuery = _normalizeVn(query);
    if (normQuery.isEmpty) return true;
    return normActual.contains(normQuery) || normQuery.contains(normActual);
  }

  Future<List<Trip>> searchTrips({
    String? from,
    String? to,
    String? date,
    int page = 1,
  }) async {
    try {
      // Lấy danh sách chuyến theo ngày (limit lớn để không bị lỗi SQLite ASCII LOWER()
      // khi lọc tên tỉnh có ký tự Unicode in hoa như Đ, Ấ, Ố, Ư trên server SQLite),
      // sau đó lọc chuẩn xác bằng bộ chuẩn hóa tiếng Việt ở tầng client.
      final queryParams = <String, dynamic>{
        if (date != null && date.isNotEmpty) 'date': date,
        'page': page,
        'limit': 500,
      };

      final response = await _apiClient.get('/trips', queryParameters: queryParams);

      if (response.data['success'] == true) {
        final List<dynamic> items = response.data['data']['items'] ?? const [];
        final allTrips = items.map((json) => Trip.fromJson(json)).toList();
        return allTrips.where((trip) {
          final matchFrom = _matchesLocation(trip.departureStation, from);
          final matchTo = _matchesLocation(trip.arrivalStation, to);
          return matchFrom && matchTo;
        }).toList();
      }
      throw Exception(response.data['message'] ?? 'Không thể tải danh sách chuyến xe');
    } catch (e) {
      throw Exception('Không thể tải danh sách chuyến xe: $e');
    }
  }

  Future<Trip> getTripDetails(int id) async {
    try {
      final response = await _apiClient.get('/trips/$id');

      if (response.data['success'] == true) {
        return Trip.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Không thể tải chi tiết chuyến xe');
    } catch (e) {
      throw Exception('Không thể tải chi tiết chuyến xe: $e');
    }
  }
}
