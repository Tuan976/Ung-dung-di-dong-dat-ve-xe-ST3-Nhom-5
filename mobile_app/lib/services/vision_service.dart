import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/vision_config.dart';
import '../models/vision_result.dart';

class VisionService {
  final http.Client _client;

  VisionService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer ${VisionConfig.apiToken}',
      };

  /// Checks server and model health
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final url = Uri.parse('${VisionConfig.baseUrl}/health');
      final response = await _client.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 || response.statusCode == 503) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      return {
        'status': 'error',
        'message': 'HTTP ${response.statusCode}: ${response.body}'
      };
    } catch (e) {
      return {
        'status': 'unreachable',
        'message': 'Không thể kết nối máy chủ Vision: $e'
      };
    }
  }

  /// Sends image bytes to /v1/vision/analyze
  Future<VisionResult> analyzeImage({
    required Uint8List imageBytes,
    required String filename,
    String type = 'general',
    String? prompt,
  }) async {
    return _sendMultipartRequest(
      endpoint: '/v1/vision/analyze',
      imageBytes: imageBytes,
      filename: filename,
      fields: {
        'type': type,
        if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      },
    );
  }

  /// Sends image bytes to /v1/vision/ocr
  Future<VisionResult> extractText({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    return _sendMultipartRequest(
      endpoint: '/v1/vision/ocr',
      imageBytes: imageBytes,
      filename: filename,
    );
  }

  /// Sends image bytes to /v1/vision/describe
  Future<VisionResult> describeImage({
    required Uint8List imageBytes,
    required String filename,
    String? prompt,
  }) async {
    return _sendMultipartRequest(
      endpoint: '/v1/vision/describe',
      imageBytes: imageBytes,
      filename: filename,
      fields: {
        if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      },
    );
  }

  /// Internal multipart helper with timeout and error mapping
  Future<VisionResult> _sendMultipartRequest({
    required String endpoint,
    required Uint8List imageBytes,
    required String filename,
    Map<String, String>? fields,
  }) async {
    try {
      final uri = Uri.parse('${VisionConfig.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(_authHeaders);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );

      final streamedResponse = await _client
          .send(request)
          .timeout(VisionConfig.requestTimeout);

      final response = await http.Response.fromStream(streamedResponse);
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return VisionResult.fromJson(decodedBody);
      } else {
        final errorMsg = decodedBody['error'] ??
            'Lỗi HTTP ${response.statusCode}: ${response.reasonPhrase}';
        return VisionResult.failure(errorMsg);
      }
    } catch (e) {
      debugPrint('VisionService Error: $e');
      if (e.toString().contains('TimeoutException')) {
        return VisionResult.failure(
          'Quá thời gian chờ phản hồi (${VisionConfig.requestTimeout.inSeconds}s). Mô hình AI đang bận hoặc mạng chậm.',
        );
      }
      return VisionResult.failure('Lỗi kết nối AI Vision: $e');
    }
  }
}
