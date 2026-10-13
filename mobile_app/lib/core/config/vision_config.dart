import 'package:flutter/foundation.dart';

enum VisionEnvironment {
  local,
  androidEmulator,
  lanDevice,
  production,
}

class VisionConfig {
  // Current active environment:
  // - On Web (Chrome desktop): default to local (127.0.0.1:5050) for direct, instant access
  // - On Mobile / real devices / emulators: default to production (Cloudflare HTTPS tunnel)
  static VisionEnvironment currentEnvironment =
      kIsWeb ? VisionEnvironment.local : VisionEnvironment.production;

  // Environment-specific base URLs:
  static const String _localUrl = 'http://127.0.0.1:5050';
  static const String _emulatorUrl = 'http://10.0.2.2:5050';
  static const String _lanUrl = 'http://192.168.123.41:5050';
  static const String _productionUrl = 'https://hall-allocated-graphic-screensaver.trycloudflare.com';

  // API Token for Bearer authorization
  static const String apiToken = 'vexekhach_ai_vision_sec_2026_tok';

  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 90);

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

  static void setEnvironment(VisionEnvironment env) {
    currentEnvironment = env;
    debugPrint('VisionConfig: Switched environment to $env -> $baseUrl');
  }
}
