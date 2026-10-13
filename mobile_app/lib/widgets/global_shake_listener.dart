import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shake/shake.dart';
import 'sos_alert_host.dart';

/// Lắc điện thoại mở màn hình SOS với bước xác nhận có đếm ngược 5 giây (tránh gửi nhầm khi vô tình lắc).
/// Đồng thời bao toàn bộ app bằng [SosAlertHost] để hiện cảnh báo SOS ở gần trên mọi màn hình.
class GlobalShakeListener extends StatefulWidget {
  final Widget child;

  const GlobalShakeListener({super.key, required this.child});

  @override
  State<GlobalShakeListener> createState() => _GlobalShakeListenerState();
}

class _GlobalShakeListenerState extends State<GlobalShakeListener> {
  ShakeDetector? _shakeDetector;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    try {
      _shakeDetector = ShakeDetector.autoStart(
        onPhoneShake: (_) => _onShake(),
        shakeThresholdGravity: 2.7,
      );
    } catch (e) {
      debugPrint("Shake detector initialization error: $e");
    }
  }

  void _onShake() {
    final now = DateTime.now();
    if (now.difference(_lastShake) < const Duration(seconds: 10)) return;
    _lastShake = now;
    if (!mounted) return;
    final router = GoRouter.of(context);
    final path = router.routeInformationProvider.value.uri.path;
    if (path == '/sos' || path == '/splash' || path == '/login' || path == '/register') return;
    router.push('/sos?auto=1');
  }

  @override
  void dispose() {
    try {
      _shakeDetector?.stopListening();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SosAlertHost(child: widget.child);
}
