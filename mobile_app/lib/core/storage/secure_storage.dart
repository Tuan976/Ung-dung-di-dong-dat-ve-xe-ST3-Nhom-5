import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'web_storage_stub.dart' if (dart.library.html) 'web_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _nativeStorage = const FlutterSecureStorage();

  static const String _keyAccessToken = 'access_token';

  Future<void> saveToken(String token) async {
    try {
      if (kIsWeb) {
        saveWebToken(_keyAccessToken, token);
      } else {
        await _nativeStorage.write(key: _keyAccessToken, value: token);
      }
    } catch (e) {
      debugPrint('Lỗi lưu token: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        return getWebToken(_keyAccessToken);
      } else {
        return await _nativeStorage.read(key: _keyAccessToken);
      }
    } catch (e) {
      debugPrint('Lỗi đọc token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      if (kIsWeb) {
        deleteWebToken(_keyAccessToken);
      } else {
        await _nativeStorage.delete(key: _keyAccessToken);
      }
    } catch (e) {
      debugPrint('Lỗi xóa token: $e');
    }
  }
}
