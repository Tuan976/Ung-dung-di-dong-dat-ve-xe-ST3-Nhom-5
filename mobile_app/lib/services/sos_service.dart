import 'package:geolocator/geolocator.dart';
import '../core/network/api_client.dart';

class SosService {
  final ApiClient _apiClient;

  SosService(this._apiClient);

  Future<void> sendSosSignal() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ vị trí (GPS) đang bị tắt. Xin hãy bật lên để gửi SOS!');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Cần cấp quyền truy cập vị trí để gửi định vị SOS.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng mở cài đặt ứng dụng.');
    } 

    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    try {
      final response = await _apiClient.post('/sos', data: {
        'lat': position.latitude,
        'lng': position.longitude,
        'message': 'SOS! Hành khách đang gặp nguy hiểm cần hỗ trợ ngay lập tức.',
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Không thể gửi tín hiệu SOS.');
      }
    } catch (e) {
      throw Exception('Lỗi mạng khi gửi SOS: $e');
    }
  }
}
