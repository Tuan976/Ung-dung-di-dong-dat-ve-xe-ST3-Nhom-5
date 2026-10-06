import 'package:flutter/material.dart';
import 'package:shake/shake.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../services/sos_service.dart';
import '../core/network/api_client.dart';

class GlobalShakeListener extends StatefulWidget {
  final Widget child;

  const GlobalShakeListener({super.key, required this.child});

  @override
  State<GlobalShakeListener> createState() => _GlobalShakeListenerState();
}

class _GlobalShakeListenerState extends State<GlobalShakeListener> {
  late ShakeDetector _shakeDetector;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        if (!_isSending) {
          _sendSos();
        }
      },
      shakeThresholdGravity: 2.7,
    );
  }

  Future<void> _sendSos() async {
    setState(() => _isSending = true);
    
    try {
      final sosService = SosService(ApiClient());
      await sosService.sendSosSignal();
      
      if (!mounted) return;
      FlutterRingtonePlayer().playAlarm(looping: true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: const Text(
            'Tín hiệu SOS và định vị GPS của bạn đã được gửi thành công!\n\nHãy cố gắng giữ bình tĩnh và ở yên vị trí an toàn. Cơ quan chức năng và nhà xe đang trên đường đến hỗ trợ bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  FlutterRingtonePlayer().stop();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B192C),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Đã hiểu', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        )
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _shakeDetector.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
