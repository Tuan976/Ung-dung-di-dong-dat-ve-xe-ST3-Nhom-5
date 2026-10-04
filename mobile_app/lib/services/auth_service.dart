import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorage _storage;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthService(this._apiClient, this._storage);

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final response = await _apiClient.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.data['success']) {
        final token = response.data['data']['access_token'];
        await _storage.saveToken(token);
        _currentUser = User.fromJson(response.data['data']['user']);
        notifyListeners();
        return true;
      } else {
        _error = response.data['message'] ?? 'Login failed';
        return false;
      }
    } catch (e) {
      _error = 'Không thể kết nối đến máy chủ. Vui lòng thử lại.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Used for Google/Social login — receives token + user directly
  Future<void> loginWithToken(String token, Map<String, dynamic> userData) async {
    await _storage.saveToken(token);
    _currentUser = User.fromJson(userData);
    notifyListeners();
  }

  Future<bool> register(String name, String email, String phone, String password) async {
    _setLoading(true);
    try {
      final response = await _apiClient.post('/auth/register', data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      });

      if (response.data['success']) {
        return true;
      } else {
        _error = response.data['message'] ?? 'Registration failed';
        return false;
      }
    } catch (e) {
      _error = 'Connection error. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkAuthStatus() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await _apiClient.get('/auth/me');
      if (response.data['success'] == true) {
        _currentUser = User.fromJson(response.data['data']['user']);
        notifyListeners();
        return true;
      }
      // Token invalid/expired
      await logout();
      return false;
    } catch (e) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteToken();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _error = null;
    notifyListeners();
  }
}
