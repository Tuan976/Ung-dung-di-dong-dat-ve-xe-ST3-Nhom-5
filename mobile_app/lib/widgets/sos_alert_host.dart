import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/network/api_client.dart';
import '../models/sos_models.dart';
import '../screens/sos/sos_alert_map_screen.dart';
import '../services/auth_service.dart';
import '../services/nearby_alert_service.dart';
import '../services/sos_service.dart';

/// Bao quanh toàn bộ ứng dụng (trong ShellRoute): hiển thị cảnh báo SOS gần bạn trên MỌI màn hình,
/// quản lý vòng đời kênh realtime theo đăng nhập và theo trạng thái foreground/background.
class SosAlertHost extends StatefulWidget {
  final Widget child;
  const SosAlertHost({super.key, required this.child});

  @override
  State<SosAlertHost> createState() => _SosAlertHostState();
}

class _SosAlertHostState extends State<SosAlertHost> with WidgetsBindingObserver {
  final NearbyAlertService _svc = NearbyAlertService.instance;
  StreamSubscription<SosAlert>? _sub;
  final Set<String> _open = {}; // mỗi event_id chỉ có tối đa một màn hình cảnh báo
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _svc.onNewAlert.listen(_onNewAlert);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _svc.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _svc.pause(); // chỉ gửi heartbeat khi ứng dụng đang mở
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context);
    if (auth.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onLogin());
    } else if (!auth.isAuthenticated) {
      _wasAuthenticated = false;
    }
  }

  Future<void> _onLogin() async {
    if (!mounted) return;
    final api = context.read<ApiClient>();
    final consent = await NearbyAlertService.readConsent();
    if (!mounted) return;
    if (consent == null) {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ConsentDialog(),
      );
      if (!mounted) return;
      await _svc.setConsent(accepted == true, api);
    } else if (consent) {
      await _svc.start(api);
    }
  }

  void _onNewAlert(SosAlert a) {
    if (!mounted || _open.contains(a.eventId)) return;
    _open.add(a.eventId);
    HapticFeedback.heavyImpact(); // một lần, không lặp liên tục
    SystemSound.play(SystemSoundType.alert);
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SOS',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => SosAlertDialog(eventId: a.eventId),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ).whenComplete(() => _open.remove(a.eventId));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Cảnh báo an toàn cho cộng đồng'),
      content: const Text(
        'Cho phép VeXe dùng vị trí của bạn khi đang mở ứng dụng để cảnh báo bạn khi có người gặp nguy hiểm ở gần, '
        'và để người ở gần nhận được SOS của bạn.\n\n'
        'Vị trí chỉ được gửi khi ứng dụng đang mở, chỉ lưu vị trí gần nhất, tự xóa khi bạn đăng xuất hoặc sau 24 giờ. '
        'Bạn có thể tắt bất cứ lúc nào trong màn hình SOS.',
        style: TextStyle(height: 1.45),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không, cảm ơn')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.white),
          child: const Text('Cho phép'),
        ),
      ],
    );
  }
}

/// Lớp phủ cảnh báo khẩn cấp. Nội dung cập nhật theo trạng thái thật từ server (đã kết thúc, đã phản hồi...).
class SosAlertDialog extends StatefulWidget {
  final String eventId;
  const SosAlertDialog({super.key, required this.eventId});

  @override
  State<SosAlertDialog> createState() => _SosAlertDialogState();
}

class _SosAlertDialogState extends State<SosAlertDialog> {
  static const _danger = Color(0xFFD32F2F);
  static const _brand = Color(0xFFFF6B00);
  late final SosService _sos;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sos = SosService(context.read<ApiClient>());
    // Cảnh báo đã hiển thị trên màn hình -> xác nhận "đã nhìn thấy" lên server
    WidgetsBinding.instance.addPostFrameCallback((_) => _acknowledge());
  }

  Future<void> _acknowledge() async {
    try {
      final a = await _sos.acknowledge(widget.eventId);
      NearbyAlertService.instance.updateAlert(a);
    } catch (_) {}
  }

  Future<void> _respond(String response) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final a = await _sos.respond(widget.eventId, response);
      NearbyAlertService.instance.updateAlert(a);
    } on SosException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ValueListenableBuilder<Map<String, SosAlert>>(
            valueListenable: NearbyAlertService.instance.alerts,
            builder: (context, alerts, _) {
              final a = alerts[widget.eventId];
              if (a == null) return const SizedBox.shrink();
              final active = a.isActive;
              final helping = a.myStatus == 'responding';
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                constraints: const BoxConstraints(maxWidth: 440),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: active ? _danger : Colors.green, width: 3),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(active ? Icons.warning_amber_rounded : Icons.verified_rounded, color: active ? _danger : Colors.green, size: 56),
                        const SizedBox(height: 8),
                        Text(
                          active ? 'CẢNH BÁO KHẨN CẤP' : 'SỰ CỐ ĐÃ KẾT THÚC',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: active ? _danger : Colors.green.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          active ? 'Có người đang gặp nguy hiểm ở gần bạn' : 'Người gửi SOS đã được xác nhận kết thúc sự cố.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        _row(Icons.near_me, a.distanceM != null ? 'Cách bạn khoảng ${a.distanceM} m (ước tính)' : 'Khoảng cách: chưa rõ'),
                        _row(Icons.schedule, 'Phát cảnh báo lúc ${a.createdAt != null ? DateFormat('HH:mm dd/MM').format(a.createdAt!) : '--'}'),
                        if (a.area != null && a.area!.isNotEmpty) _row(Icons.place_outlined, 'Khu vực gần đúng: ${a.area}'),
                        if (kSosIncidentTypeLabels[a.incidentType] != null && a.incidentType != 'general')
                          _row(Icons.report_gmailerrorred, 'Loại sự cố: ${kSosIncidentTypeLabels[a.incidentType]}'),
                        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: _danger))),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => SosAlertMapScreen(eventId: widget.eventId)));
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Xem vị trí'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(height: 8),
                          if (!helping)
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _respond('helping'),
                              icon: _busy
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.volunteer_activism),
                              label: const Text('Tôi có thể hỗ trợ'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _danger,
                                side: const BorderSide(color: _danger),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                              child: const Text('Đã ghi nhận: bạn đang hỗ trợ. Hãy giữ an toàn cho bản thân.', textAlign: TextAlign.center),
                            ),
                            TextButton(onPressed: _busy ? null : () => _respond('cannot_help'), child: const Text('Tôi không thể tiếp tục hỗ trợ')),
                          ],
                          if (a.myStatus == 'declined')
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text('Bạn đã báo không thể hỗ trợ.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                            ),
                        ],
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Đóng cảnh báo', style: TextStyle(color: Color(0xFF475569))),
                        ),
                        const Text(
                          'Thông tin cá nhân của người gửi SOS được ẩn. Nếu có nguy hiểm đến tính mạng hãy gọi 113 / 115.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF475569)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.3))),
          ],
        ),
      );
}
