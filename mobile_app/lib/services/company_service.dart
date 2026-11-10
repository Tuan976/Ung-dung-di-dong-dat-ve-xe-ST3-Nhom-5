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
    final cleanCode = ticketCode.trim().toUpperCase();

    // Strategy 1: Thử endpoint chuyên biệt soát vé (/admin/ticket/scan)
    try {
      final res = await _apiClient.post(
        '/admin/ticket/scan',
        data: {'ticket_code': cleanCode},
      );
      if (res.data != null && res.data is Map<String, dynamic>) {
        if (res.data['success'] == true || res.data['ticket'] != null) {
          return Map<String, dynamic>.from(res.data);
        }
      }
    } catch (e) {
      debugPrint('Strategy 1 (/admin/ticket/scan) bypass sang fallback: $e');
    }

    // Strategy 2: Tự động tra cứu và check-in qua danh sách hành khách các chuyến xe đang chạy
    try {
      final trips = await getTrips();
      for (final trip in trips) {
        final tripId = trip['id'] as int?;
        if (tripId == null) continue;

        final passengers = await getTripPassengers(tripId);
        for (final pax in passengers) {
          final paxCode = (pax['ticket_code'] ?? '').toString().trim().toUpperCase();
          final paxId = pax['id'] as int?;

          if (paxCode == cleanCode ||
              (cleanCode.length >= 4 && paxCode.endsWith(cleanCode)) ||
              (paxId != null && cleanCode == paxId.toString())) {
            final alreadyBoarded = (pax['boarding_status'] == 'BOARDED');

            // Cập nhật lên xe ngay lập tức qua API boarding
            if (!alreadyBoarded && paxId != null) {
              await markPassengerBoarded(paxId);
            }

            final departureStr = trip['departure_time'] != null
                ? trip['departure_time'].toString().replaceAll('T', ' ')
                : '';

            return {
              'success': true,
              'already_boarded': alreadyBoarded,
              'message': alreadyBoarded
                  ? 'Vé hợp lệ (Khách đã check-in trước đó)'
                  : 'Soát vé thành công - Đã đón khách lên xe!',
              'ticket': {
                'id': paxId,
                'ticket_code': paxCode.isNotEmpty ? paxCode : cleanCode,
                'passenger_name': pax['name'] ?? 'Hành khách',
                'passenger_phone': pax['phone'] ?? 'Chưa có',
                'seat_number': pax['seat'] ?? 'N/A',
                'route': trip['route'] ?? 'Tuyến xe khách',
                'departure_time': departureStr.length >= 16 ? departureStr.substring(0, 16) : departureStr,
                'license_plate': trip['bus'] ?? 'Chưa gán xe',
                'pickup_point': pax['pickup'] ?? 'Tại bến xe',
                'dropoff_point': pax['dropoff'] ?? 'Tại bến xe',
                'ticket_price': pax['price'] ?? 0,
                'payment_status': pax['payment_status'] ?? 'Paid',
                'status': pax['status'] ?? 'CONFIRMED',
                'boarding_status': 'BOARDED',
              }
            };
          }
        }
      }
    } catch (fallbackError) {
      debugPrint('Strategy 2 (Trip passenger scan) fallback error: $fallbackError');
    }

    // Strategy 3: Tra cứu qua API kiểm tra vé công khai
    try {
      final res = await _apiClient.get(
        '/check-ticket',
        queryParameters: {'code': cleanCode},
      );
      if (res.data != null && res.data['success'] == true && res.data['ticket'] != null) {
        final t = Map<String, dynamic>.from(res.data['ticket']);
        return {
          'success': true,
          'already_boarded': false,
          'message': 'Vé hợp lệ - Đã xác thực thành công!',
          'ticket': t,
        };
      }
    } catch (e3) {
      debugPrint('Strategy 3 (/check-ticket) error: $e3');
    }

    return {
      'success': false,
      'message': 'Không tìm thấy vé hợp lệ với mã: $cleanCode',
    };
  }
}

