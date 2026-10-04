import '../core/network/api_client.dart';
import '../models/trip.dart';

class TripService {
  final ApiClient _apiClient;

  TripService(this._apiClient);

  Future<List<Trip>> searchTrips({
    String? from,
    String? to,
    String? date,
    int page = 1,
  }) async {
    try {
      final queryParams = {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (date != null && date.isNotEmpty) 'date': date,
        'page': page,
      };

      final response = await _apiClient.get('/trips', queryParameters: queryParams);
      
      if (response.data['success']) {
        final List<dynamic> items = response.data['data']['items'];
        return items.map((json) => Trip.fromJson(json)).toList();
      }
      throw Exception(response.data['message'] ?? 'Failed to load trips');
    } catch (e) {
      throw Exception('Failed to load trips: $e');
    }
  }

  Future<Trip> getTripDetails(int id) async {
    try {
      final response = await _apiClient.get('/trips/$id');
      
      if (response.data['success']) {
        return Trip.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Failed to load trip details');
    } catch (e) {
      throw Exception('Failed to load trip details: $e');
    }
  }
}
