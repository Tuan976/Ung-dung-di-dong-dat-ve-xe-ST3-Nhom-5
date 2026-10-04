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
  }) async {
    try {
      final response = await _apiClient.post('/bookings', data: {
        'trip_id': tripId,
        'seat_number': seatNumber,
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        if (pickupPoint != null) 'pickup_point': pickupPoint,
        if (dropoffPoint != null) 'dropoff_point': dropoffPoint,
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
}
