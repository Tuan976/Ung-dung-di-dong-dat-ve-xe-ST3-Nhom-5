import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/booking.dart';

class BookingConflictException implements Exception {
  final String message;
  BookingConflictException(this.message);
  @override
  String toString() => message;
}

class BookingService {
  final ApiClient _apiClient;
  BookingService(this._apiClient);

  Future<List<Booking>> getMyBookings({String? status}) async {
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      final response = await _apiClient.get('/bookings', queryParameters: params);
      if (response.data['success'] == true) {
        final List<dynamic> items = response.data['data']['items'] ?? [];
        return items.map((json) => Booking.fromJson(json)).toList();
      }
      throw Exception(response.data['message'] ?? 'Không thể tải danh sách vé');
    } catch (e) {
      throw Exception('Không thể tải danh sách vé: $e');
    }
  }

  Future<Booking> getBookingById(int bookingId) async {
    try {
      final response = await _apiClient.get('/bookings/$bookingId');
      if (response.data['success'] == true) {
        return Booking.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Không tìm thấy vé');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi kết nối');
    }
  }

  Future<Booking> createBooking({
    required int tripId,
    required String seatNumber,
    required String passengerName,
    required String passengerPhone,
    String? pickupPoint,
    String? dropoffPoint,
    String? pickupStationId,
    String? dropoffStationId,
  }) async {
    try {
      final response = await _apiClient.post('/bookings', data: {
        'trip_id': tripId,
        'seat_number': seatNumber,
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        if (pickupPoint != null) 'pickup_point': pickupPoint,
        if (dropoffPoint != null) 'dropoff_point': dropoffPoint,
        if (pickupStationId != null) 'pickup_station_id': pickupStationId,
        if (dropoffStationId != null) 'dropoff_station_id': dropoffStationId,
      });
      if (response.data['success'] == true) {
        return Booking.fromCreateResponse(
          response.data['data'],
          seatNumber: seatNumber,
          passengerName: passengerName,
          passengerPhone: passengerPhone,
        );
      }
      throw Exception(response.data['message'] ?? 'Đặt vé thất bại');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw BookingConflictException(
          e.response?.data['message'] ?? 'Ghế này vừa được người khác đặt. Vui lòng chọn ghế khác.',
        );
      }
      throw Exception(e.response?.data['message'] ?? 'Lỗi kết nối mạng');
    }
  }

  Future<bool> cancelBooking(int bookingId) async {
    try {
      final response = await _apiClient.post('/bookings/$bookingId/cancel');
      return response.data['success'] == true;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Không thể hủy vé');
    }
  }

  Future<Map<String, dynamic>> createPayment(int bookingId) async {
    try {
      final response = await _apiClient.post('/payments/create', data: {'booking_id': bookingId});
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception(response.data['message'] ?? 'Không thể tạo liên kết thanh toán');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi thanh toán');
    }
  }

  Future<Map<String, dynamic>> getPaymentStatus(int bookingId) async {
    try {
      final response = await _apiClient.get('/payments/$bookingId/status');
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception(response.data['message'] ?? 'Không thể kiểm tra thanh toán');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi kết nối');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveBookings() async {
    try {
      final response = await _apiClient.get('/bookings/active');
      if (response.data['success'] == true) {
        final List<dynamic> items = response.data['data']['items'] ?? [];
        return items.map((i) => Map<String, dynamic>.from(i)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Lỗi tải active bookings: $e');
      return [];
    }
  }

  Future<bool> notifyPickupLocation({
    required int bookingId,
    required String pickupLocation,
    String? landmarkName,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '/bookings/$bookingId/notify-pickup',
        data: {
          'pickup_location': pickupLocation,
          if (landmarkName != null) 'landmark_name': landmarkName,
          if (note != null) 'note': note,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('Lỗi báo điểm đón: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> notifyPickupPublic({
    required String pickupLocation,
    String? ticketCode,
    String? passengerPhone,
    String? passengerName,
    String? routeName,
    String? landmarkName,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '/bookings/notify-pickup-public',
        data: {
          'pickup_location': pickupLocation,
          if (ticketCode != null && ticketCode.isNotEmpty) 'ticket_code': ticketCode,
          if (passengerPhone != null && passengerPhone.isNotEmpty) 'passenger_phone': passengerPhone,
          if (passengerName != null && passengerName.isNotEmpty) 'passenger_name': passengerName,
          if (routeName != null && routeName.isNotEmpty) 'route_name': routeName,
          if (landmarkName != null && landmarkName.isNotEmpty) 'landmark_name': landmarkName,
          if (note != null && note.isNotEmpty) 'note': note,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
      return response.data is Map<String, dynamic> ? response.data : {'success': true};
    } catch (e) {
      debugPrint('Lỗi notifyPickupPublic: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
