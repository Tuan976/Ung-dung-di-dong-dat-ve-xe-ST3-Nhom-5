import 'package:dio/dio.dart';

import '../core/network/api_client.dart';

typedef AssistantData = Map<String, dynamic>;

List<AssistantData> assistantItems(Object? value) =>
    value is List ? value.whereType<AssistantData>().toList() : const [];

class AssistantException implements Exception {
  const AssistantException(this.message, {this.authRequired = false});

  final String message;
  final bool authRequired;
}

class AssistantService {
  AssistantService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  String? _conversation;

  Future<AssistantData> settings() => _read(() => _client.get('/assistant'));

  Future<AssistantData> ask(AssistantData action) async {
    final data = await _read(
      () => _client.post(
        '/assistant',
        data: {...action, 'conversation': _conversation},
        retryOnConnectionFailure: false,
      ),
    );
    _conversation = data['conversation'] as String?;
    return data;
  }

  Future<AssistantData> seats(int tripId) =>
      _read(() => _client.get('/assistant/trips/$tripId'));

  Future<AssistantData> book(AssistantData booking) async {
    final data = await _read(
      () => _client.post(
        '/assistant/book',
        data: booking,
        retryOnConnectionFailure: false,
      ),
    );
    if (data['success'] != true) {
      throw AssistantException(
        data['message'] as String? ?? 'Chưa thể đặt vé.',
      );
    }
    return data;
  }

  Future<AssistantData> _read(Future<Response> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is AssistantData) return data;
      throw const AssistantException('Máy chủ trả về dữ liệu không hợp lệ.');
    } on DioException catch (error) {
      final response = error.response;
      final data = response?.data;
      final authRequired = response?.statusCode == 401;
      if (authRequired) {
        throw const AssistantException(
          'Bạn đăng nhập lại để tiếp tục nhé.',
          authRequired: true,
        );
      }
      final message = data is AssistantData
          ? data['response'] ?? data['message']
          : null;
      throw AssistantException(
        message is String
            ? message
            : response?.statusCode == 404
            ? 'Máy chủ chưa có trợ lý. Hãy chạy lại máy chủ đã cập nhật.'
            : 'Không kết nối được với máy chủ. Bạn thử lại nhé.',
      );
    }
  }
}
