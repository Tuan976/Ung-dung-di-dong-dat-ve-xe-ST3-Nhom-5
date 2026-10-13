class ApiConfig {
  /// Mặc định trỏ tới host thật. Khi kiểm thử cục bộ có thể ghi đè:
  /// flutter run --dart-define=API_BASE_URL=http://localhost:5000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://vexekhach.aweb.io.vn/api/v1',
  );
  static const int receiveTimeout = 15000;
  static const int connectionTimeout = 15000;
}
