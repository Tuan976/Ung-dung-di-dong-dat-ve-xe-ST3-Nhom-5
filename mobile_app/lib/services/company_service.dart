import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';

class CompanyService extends ChangeNotifier {
  final ApiClient _apiClient;

  CompanyService(this._apiClient);

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // 1. Thống kê tổng quan (Dashboard Stats)
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final res = await _apiClient.get('/admin/stats');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getStats: $e');
      return null;
    }
  }

  // 2. Chuyến xe (Trips)
  Future<List<Map<String, dynamic>>> getTrips() async {
    try {
      final res = await _apiClient.get('/admin/trips');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      debugPrint('Error getTrips: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createTrip({
    required int routeId,
    required int busId,
    int? driverId,
    required String departureTime,
  }) async {
    try {
      final res = await _apiClient.post('/admin/trips', data: {
        'route_id': routeId,
        'bus_id': busId,
        'driver_id': driverId,
        'departure_time': departureTime,
      });
      return {
        'success': res.statusCode == 201 || res.data['success'] == true,
        'message': res.data['message'] ?? 'Tạo chuyến thành công',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi tạo chuyến: $e'};
    }
  }

  Future<Map<String, dynamic>?> getTripDetail(int tripId) async {
    try {
      final res = await _apiClient.get('/admin/trip/$tripId');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 3. Hành khách & Phơi khách (Passengers / Manifest)
  Future<List<Map<String, dynamic>>> getTripPassengers(int tripId) async {
    try {
      final res = await _apiClient.get('/admin/trip/$tripId/passengers');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      debugPrint('Error getTripPassengers: $e');
      return [];
    }
  }

  Future<bool> checkInPassenger(int bookingId) async {
    try {
      final res = await _apiClient.post('/ops/booking/check-in/$bookingId');
      return res.statusCode == 200 || res.data['success'] == true;
    } catch (_) {
      // Fallback: update booking
      try {
        final res2 = await _apiClient.put('/admin/bookings/$bookingId', data: {
          'boarding_status': 'BOARDED',
        });
        return res2.statusCode == 200;
      } catch (e) {
        return false;
      }
    }
  }

  Future<List<Map<String, dynamic>>> searchPassengers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _apiClient.get('/admin/passengers/search', queryParameters: {'q': query});
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteBooking(int bookingId) async {
    try {
      final res = await _apiClient.delete('/admin/bookings/$bookingId');
      return res.statusCode == 200 || res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // 4. Ký gửi Hàng hóa (Cargo)
  Future<List<Map<String, dynamic>>> getCargos() async {
    try {
      final res = await _apiClient.get('/admin/cargo');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      debugPrint('Error getCargos: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createCargo(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/admin/cargo', data: data);
      return {
        'success': res.statusCode == 200 || res.data['success'] == true,
        'message': res.data['message'] ?? 'Tạo đơn hàng thành công',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi tạo đơn hàng: $e'};
    }
  }

  Future<bool> updateCargoStatus(int cargoId, String status) async {
    try {
      final res = await _apiClient.put('/admin/cargo/$cargoId', data: {'status': status});
      return res.statusCode == 200 || res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCargo(int cargoId) async {
    try {
      final res = await _apiClient.delete('/admin/cargo/$cargoId');
      return res.statusCode == 200 || res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // 5. Quản lý Xe (Buses)
  Future<List<Map<String, dynamic>>> getBuses() async {
    try {
      final res = await _apiClient.get('/admin/buses');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      debugPrint('Error getBuses: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createBus(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/admin/buses', data: data);
      return {
        'success': res.statusCode == 200 || res.data['success'] == true,
        'message': res.data['message'] ?? 'Thêm xe thành công',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi thêm xe: $e'};
    }
  }

  // 6. Quản lý Nhân sự / Tài xế (Staff / Drivers)
  Future<List<Map<String, dynamic>>> getStaff(String role) async {
    try {
      final res = await _apiClient.get('/admin/staff/$role');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      debugPrint('Error getStaff: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/admin/staff', data: data);
      return {
        'success': res.statusCode == 200 || res.data['success'] == true,
        'message': res.data['message'] ?? 'Thêm nhân sự thành công',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi thêm nhân sự: $e'};
    }
  }

  Future<bool> deleteStaff(int staffId) async {
    try {
      final res = await _apiClient.delete('/admin/staff', data: {'id': staffId});
      return res.statusCode == 200 || res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // 7. Tuyến đường & Văn phòng
  Future<List<Map<String, dynamic>>> getRoutes() async {
    try {
      final res = await _apiClient.get('/admin/routes');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOffices() async {
    try {
      final res = await _apiClient.get('/admin/offices');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 8. Trung tâm Xử lý Sự cố & Cứu viện (Incident & Rescue Command Center)
  Future<List<Map<String, dynamic>>> getIncidents() async {
    try {
      final res = await _apiClient.get('/admin/incidents');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      debugPrint('Error getIncidents: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> reportIncident({
    required int tripId,
    required String type, // BREAKDOWN, ACCIDENT, TRAFFIC, DRIVER_UNABLE, OTHER
    required String description,
    String? location,
    bool notifyPassengers = true,
  }) async {
    try {
      final res = await _apiClient.post('/admin/incidents/report', data: {
        'trip_id': tripId,
        'type': type,
        'description': description,
        'location': location,
        'notify_passengers': notifyPassengers,
      });
      return {
        'success': res.statusCode == 201 || res.data['success'] == true,
        'message': res.data['message'] ?? 'Báo cáo sự cố thành công',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi báo cáo sự cố: $e'};
    }
  }

  Future<Map<String, dynamic>?> getIncidentReplacements(int tripId) async {
    try {
      final res = await _apiClient.get('/admin/incidents/replacements/$tripId');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getIncidentReplacements: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> resolveIncidentTransfer({
    required int tripId,
    int? incidentId,
    required String mode, // 'REPLACE_VEHICLE' or 'TRANSFER_PASSENGERS'
    int? newBusId,
    int? newDriverId,
    int? targetTripId,
  }) async {
    try {
      final res = await _apiClient.post('/admin/incidents/resolve-transfer', data: {
        'trip_id': tripId,
        'incident_id': incidentId,
        'mode': mode,
        'new_bus_id': newBusId,
        'new_driver_id': newDriverId,
        'target_trip_id': targetTripId,
      });
      return {
        'success': res.statusCode == 200 || res.data['success'] == true,
        'message': res.data['message'] ?? 'Xử lý sự cố thành công',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi xử lý sự cố: $e'};
    }
  }

  Future<Map<String, dynamic>?> getLiveRadar(int tripId) async {
    try {
      final res = await _apiClient.get('/admin/trip/$tripId/live-radar');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getLiveRadar: $e');
      return null;
    }
  }

  Future<bool> updateDriverLocation({
    required int tripId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await _apiClient.post('/admin/driver/update-location', data: {
        'trip_id': tripId,
        'latitude': latitude,
        'longitude': longitude,
      });
      return res.statusCode == 200 || res.data['success'] == true;
    } catch (e) {
      debugPrint('Error updateDriverLocation: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> markPassengerBoarded(int bookingId) async {
    try {
      final res = await _apiClient.post('/admin/booking/$bookingId/board');
      return {
        'success': res.statusCode == 200 || res.data['success'] == true,
        'message': res.data['message'] ?? 'Đã xác nhận đón khách lên xe!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi đón khách: $e'};
    }
  }

  Future<Map<String, dynamic>> scanTicketCode(String ticketCode) async {
    try {
      final res = await _apiClient.post(
        '/admin/ticket/scan',
        data: {'ticket_code': ticketCode.trim()},
      );
      if (res.data != null && res.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(res.data);
      }
      return {'success': false, 'message': 'Phản hồi từ máy chủ không hợp lệ'};
    } catch (e) {
      if (e is DioException && e.response?.data != null && e.response!.data is Map) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      return {'success': false, 'message': 'Lỗi quét vé: $e'};
    }
  }
}

