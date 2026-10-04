import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  late final Dio _dio;
  final SecureStorage _secureStorage;

  ApiClient({SecureStorage? secureStorage}) 
      : _secureStorage = secureStorage ?? SecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConfig.connectionTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getToken();
          print('DEBUG API_CLIENT: Sending token: $token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Xử lý các lỗi mất kết nối mạng
          if (e.type == DioExceptionType.connectionTimeout || 
              e.type == DioExceptionType.receiveTimeout || 
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.sendTimeout) {
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: Response(
                  requestOptions: e.requestOptions,
                  statusCode: 503,
                  data: {'success': false, 'message': 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng (WiFi/4G).'}
                ),
                type: e.type,
                error: e.error,
              )
            );
          }
          
          if (e.response?.statusCode == 401) {
            // TODO: Implement Refresh Token logic when backend supports it
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      rethrow;
    }
  }
}
