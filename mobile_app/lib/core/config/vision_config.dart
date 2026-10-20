import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VisionEnvironment {
  local,
  androidEmulator,
  lanDevice,
  production,
}

class VisionConfig {
  static const String _keyCustomLanUrl = 'vision_custom_lan_url';
  static const String _keyEnvironment = 'vision_active_environment';

  // Current active environment:
  // - Default to lanDevice so exported IPA connects to local PC immediately
  static VisionEnvironment currentEnvironment =
      kIsWeb ? VisionEnvironment.local : VisionEnvironment.lanDevice;

  // Environment-specific base URLs:
  static const String _localUrl = 'http://127.0.0.1:5050';
  static const String _emulatorUrl = 'http://10.0.2.2:5050';
  static String _lanUrl = 'http://10.12.20.125:5050';
  static const String _productionUrl = 'https://hall-allocated-graphic-screensaver.trycloudflare.com';

  // API Token for Bearer authorization
  static const String apiToken = 'vexekhach_ai_vision_sec_2026_tok';

  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 90);

  /// Initializes saved config from SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_keyCustomLanUrl);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _lanUrl = savedUrl.trim();
      }
      final savedEnv = prefs.getString(_keyEnvironment);
      if (savedEnv != null) {
        currentEnvironment = VisionEnvironment.values.firstWhere(
          (e) => e.name == savedEnv,
          orElse: () => currentEnvironment,
        );
      }
      debugPrint('VisionConfig initialized: env=$currentEnvironment, lanUrl=$_lanUrl');
    } catch (e) {
      debugPrint('VisionConfig.init error: $e');
    }
  }

  /// Get current LAN URL (e.g. for display or editing in UI)
  static String get lanUrl => _lanUrl;

  /// Update LAN URL and persist to SharedPreferences
  static Future<void> setCustomLanUrl(String url) async {
    var cleaned = url.trim();
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    // Remove trailing slash if present
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    _lanUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomLanUrl, _lanUrl);
    debugPrint('VisionConfig: Updated LAN URL to $_lanUrl');
  }

  /// Resolves the active base URL according to current environment setting
  static String get baseUrl {
    switch (currentEnvironment) {
      case VisionEnvironment.local:
        return _localUrl;
      case VisionEnvironment.androidEmulator:
        return _emulatorUrl;
      case VisionEnvironment.lanDevice:
        return _lanUrl;
      case VisionEnvironment.production:
        return _productionUrl;
    }
  }

  static Future<void> setEnvironment(VisionEnvironment env) async {
    currentEnvironment = env;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEnvironment, env.name);
    debugPrint('VisionConfig: Switched environment to $env -> $baseUrl');
  }
}
