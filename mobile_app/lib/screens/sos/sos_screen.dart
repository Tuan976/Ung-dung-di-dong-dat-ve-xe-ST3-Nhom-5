import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/sos_models.dart';
import '../../services/auth_service.dart';
import '../../services/nearby_alert_service.dart';
import '../../services/sos_service.dart';

class SosScreen extends StatefulWidget {
  /// true khi mở từ hành động lắc điện thoại: hiện bước xác nhận có đếm ngược, tránh gửi nhầm.
  final bool autoStart;
  const SosScreen({super.key, this.autoStart = false});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  static const _danger = Color(0xFFD32F2F);
  static const _brand = Color(0xFFFF6B00);

  late final SosService _sos;
  late final AnimationController _pulse;

  SosIncident? _incident;
  bool _loading = true;
  bool _sending = false;
  bool _updatingLocation = false;
  String? _error;
  String? _notice;
  Timer? _pollTimer;
  Timer? _locTimer;

  @override
  void initState() {
    super.initState();
    _sos = SosService(context.read<ApiClient>());
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pollTimer?.cancel();
    _locTimer?.cancel();
    super.dispose();
  }

  bool get _authed => context.read<AuthService>().isAuthenticated;

  Future<void> _bootstrap() async {
    if (!_authed) {
      setState(() => _loading = false);
      return;
    }
    try {
      final active = await _sos.getActive();
      if (!mounted) return;
      setState(() {
        _incident = active;
        _loading = false;
      });
      if (active != null) {
        _startTimers();
      } else if (widget.autoStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openConfirm(countdown: true));
      }
    } on SosException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _startTimers() {
    _pollTimer?.cancel();
    _locTimer?.cancel();
    if (_incident?.isLegacyBackend == true) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    _locTimer = Timer.periodic(const Duration(seconds: 20), (_) => _updateLocation(silent: true));
  }

  Future<void> _refresh() async {
    final inc = _incident;
    if (inc == null || inc.isLegacyBackend) return;
    try {
      final fresh = await _sos.getIncident(inc.eventId);
      if (!mounted) return;
      setState(() => _incident = fresh);
      if (!fresh.isActive) {
        _pollTimer?.cancel();
        _locTimer?.cancel();
      }
    } on SosException catch (_) {
      // mất mạng: giữ nguyên trạng thái, không tự kết thúc SOS
    }
  }

  Future<void> _openConfirm({required bool countdown}) async {
    if (!_authed) return;
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(countdown: countdown),
    );
    if (type != null) _send(type);
  }

  Future<void> _send(String type) async {
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    try {
      final fix = await SosService.locateOnce(requestPermission: true);
      final key = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
      final inc = await _sos.createSos(fix: fix, incidentType: type, idempotencyKey: key);
      if (!mounted) return;
      setState(() {
        _incident = inc;
        if (inc.isLegacyBackend) {
          _notice = 'Backend trên host đang chạy bản cũ chưa cập nhật api/v1/sos.py. Tín hiệu SOS cơ bản đã được gửi đến nhà xe, nhưng để xem/cập nhật vị trí GPS cần tải api/v1/sos.py lên host.';
        } else if (!fix.hasFix) {
          _notice = '${fix.error ?? 'Không lấy được vị trí'}. SOS đã được ghi nhận nhưng CHƯA có vị trí. Hãy nhấn "Cập nhật vị trí" khi có GPS.';
        }
      });
      _startTimers();
    } on SosException catch (e) {
      if (mounted) setState(() => _error = 'Chưa gửi được SOS: ${e.message}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateLocation({bool silent = false, LocationFix? manualFix}) async {
    final inc = _incident;
    if (inc == null || !inc.isActive || _updatingLocation) return;
    if (inc.isLegacyBackend) {
      if (!silent && mounted) {
        setState(() => _notice = 'Backend trên host đang chạy bản cũ (chưa hỗ trợ cập nhật vị trí thời gian thực). Hãy tải api/v1/sos.py lên host.');
      }
      return;
    }
    if (!silent) setState(() => _updatingLocation = true);
    try {
      final fix = manualFix ?? await SosService.locateOnce(requestPermission: !silent);
      if (!fix.hasFix) {
        if (!silent && mounted) setState(() => _notice = '${fix.error ?? 'Không lấy được vị trí'}. Vui lòng bật GPS / cấp quyền vị trí.');
        return;
      }
      final fresh = await _sos.updateLocation(inc.eventId, fix);
      if (mounted) {
        setState(() {
          _incident = fresh;
          _notice = null;
        });
      }
    } on SosException catch (e) {
      if (!silent && mounted) setState(() => _notice = e.message);
    } finally {
      if (!silent && mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _finish() async {
    final inc = _incident;
    if (inc == null) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kết thúc SOS?'),
        content: const Text('Cảnh báo sẽ được thu hồi và những người đã nhận sẽ thấy sự cố đã kết thúc. Lịch sử sự kiện vẫn được lưu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tiếp tục SOS')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancelled'), child: const Text('Báo nhầm')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'resolved'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Tôi đã an toàn'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    try {
      final done = await _sos.resolve(inc.eventId, resolution: choice);
      if (!mounted) return;
      _pollTimer?.cancel();
      _locTimer?.cancel();
      setState(() => _incident = done);
    } on SosException catch (e) {
      if (mounted) setState(() => _notice = 'Chưa kết thúc được SOS: ${e.message}');
    }
  }

  // ------------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final inc = _incident;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0F172A)),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Trung tâm Cứu hộ SOS', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : !_authed
                ? _needLogin()
                : inc == null
                    ? _idle()
                    : _incidentView(inc),
      ),
    );
  }

  Widget _needLogin() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 56, color: Color(0xFF64748B)),
            const SizedBox(height: 12),
            const Text('Bạn cần đăng nhập để gửi SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('SOS gắn với tài khoản để chống lạm dụng và để người hỗ trợ có thể phản hồi.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
              child: const Text('Đăng nhập'),
            ),
          ]),
        ),
      );

  Widget _idle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.warning_amber_rounded, color: _danger, size: 72),
          const SizedBox(height: 16),
          const Text('BẠN ĐANG GẶP NGUY HIỂM?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _danger)),
          const SizedBox(height: 12),
          const Text(
            'Nhấn nút SOS để phát cảnh báo kèm vị trí GPS của bạn tới những người dùng VeXe đang ở gần và tới tổng đài nhà xe.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _sending ? null : () => _openConfirm(countdown: false),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: 1.0 + 0.08 * _pulse.value,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _danger,
                    boxShadow: [BoxShadow(color: _danger.withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 8)],
                  ),
                  child: Center(
                    child: _sending
                        ? const Column(mainAxisSize: MainAxisSize.min, children: [
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                            SizedBox(height: 10),
                            Text('Đang gửi SOS...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ])
                        : const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _danger, fontWeight: FontWeight.w600)),
                TextButton(onPressed: () => _openConfirm(countdown: false), child: const Text('Thử gửi lại')),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          _sharingCard(),
          const SizedBox(height: 16),
          const Text(
            'CẢNH BÁO: Nghiêm cấm sử dụng tính năng này để đùa giỡn. Chỉ sử dụng trong trường hợp khẩn cấp thực sự.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _sharingCard() {
    return ValueListenableBuilder<NearbyStatus>(
      valueListenable: NearbyAlertService.instance.status,
      builder: (context, st, _) {
        final on = NearbyAlertService.instance.hasConsent;
        String label;
        switch (st) {
          case NearbyStatus.active:
            label = 'Đang nhận cảnh báo từ người ở gần';
            break;
          case NearbyStatus.noLocation:
            label = 'Bật nhưng chưa lấy được vị trí / chưa cấp quyền';
            break;
          case NearbyStatus.offline:
            label = 'Mất kết nối - đang thử kết nối lại';
            break;
          case NearbyStatus.disabled:
            label = 'Đang tắt - bạn sẽ không nhận cảnh báo từ người ở gần';
            break;
          default:
            label = on ? 'Đang khởi động...' : 'Đang tắt';
        }
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: SwitchListTile(
            value: on,
            activeThumbColor: _brand,
            title: const Text('Nhận cảnh báo SOS ở gần tôi', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('$label\nChia sẻ vị trí chỉ khi đang mở ứng dụng.', style: const TextStyle(fontSize: 12)),
            isThreeLine: true,
            onChanged: (v) => NearbyAlertService.instance.setConsent(v, context.read<ApiClient>()).then((_) {
              if (mounted) setState(() {});
            }),
          ),
        );
      },
    );
  }

  Widget _incidentView(SosIncident inc) {
    final fmt = DateFormat('HH:mm:ss dd/MM');
    final ended = !inc.isActive;
    final d = inc.delivery;
    final endedText = inc.status == 'cancelled'
        ? 'SOS đã được hủy (báo nhầm)'
        : inc.status == 'expired'
            ? 'SOS đã hết hạn tự động'
            : (inc.resolvedAt != null ? 'SOS đã được kết thúc' : 'SOS đã kết thúc');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ended ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ended ? Colors.green : _danger, width: 1.5),
            ),
            child: Column(children: [
              Icon(ended ? Icons.verified_rounded : Icons.sos, color: ended ? Colors.green : _danger, size: 44),
              const SizedBox(height: 6),
              Text(ended ? endedText : 'Đã phát cảnh báo SOS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ended ? Colors.green.shade800 : _danger)),
              const SizedBox(height: 4),
              Text(ended ? 'Cảnh báo không còn được phát.' : 'Backend đã tiếp nhận lúc ${inc.createdAt != null ? fmt.format(inc.createdAt!) : '--'}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            ]),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(_notice!, style: const TextStyle(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 14),
          _card('Vị trí đã ghi nhận', [
            if (!inc.hasLocation) ...[
              const Text('Chưa xác định được vị trí. Người ở gần CHƯA nhận được cảnh báo cho tới khi có vị trí.',
                  style: TextStyle(color: _danger, fontWeight: FontWeight.w600)),
              if (kIsWeb || kDebugMode) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _updatingLocation ? null : () {
                    _updateLocation(
                      manualFix: const LocationFix(
                        latitude: 10.8142,
                        longitude: 106.7118,
                        accuracy: 10.0,
                        permission: 'granted',
                      ),
                    );
                  },
                  icon: const Icon(Icons.pin_drop, size: 18, color: _brand),
                  label: const Text('Dùng vị trí mẫu để kiểm thử trên Web (TP.HCM)', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ] else ...[
              Text('${inc.latitude!.toStringAsFixed(5)}, ${inc.longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (inc.accuracyMeters != null) Text('Sai số GPS khoảng ${inc.accuracyMeters!.round()} m', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (inc.address != null && inc.address!.isNotEmpty) Text('Khu vực: ${inc.address}', style: const TextStyle(fontSize: 13)),
              Text('Cập nhật gần nhất: ${inc.lastLocationUpdateAt != null ? fmt.format(inc.lastLocationUpdateAt!) : '--'}',
                  style: const TextStyle(fontSize: 13)),
            ],
          ]),
          const SizedBox(height: 12),
          _card('Trạng thái phân phối cảnh báo', [
            if (inc.distributionSuppressed)
              const Text('Cảnh báo tới người ở gần đang bị giới hạn do bạn gửi SOS quá nhiều lần gần đây. Nhà xe vẫn nhận được yêu cầu của bạn.',
                  style: TextStyle(fontSize: 13))
            else if (!inc.hasLocation)
              const Text('Chờ có vị trí để xác định người ở gần.', style: TextStyle(fontSize: 13))
            else ...[
              Text('Thiết bị server xác định trong vùng cảnh báo: ${d.inZone}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Bán kính đang áp dụng: ${inc.currentRadiusM.round()} m', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text('Đã nhận cảnh báo: ${d.delivered}  •  Đã xem: ${d.acknowledged}  •  Báo đang hỗ trợ: ${d.responding}',
                  style: const TextStyle(fontSize: 13)),
              if (d.inZone == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Hiện chưa có người dùng nào ở gần đang mở ứng dụng. Hãy gọi 113 / 115 nếu cần trợ giúp ngay.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
            ],
          ]),
          const SizedBox(height: 16),
          if (!ended) ...[
            ElevatedButton.icon(
              onPressed: _updatingLocation ? null : () => _updateLocation(),
              icon: _updatingLocation
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.my_location),
              label: const Text('Cập nhật vị trí'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Kết thúc SOS (tôi đã an toàn / báo nhầm)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ] else
            ElevatedButton(
              onPressed: () => setState(() {
                _incident = null;
                _notice = null;
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B192C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Quay về trạng thái bình thường'),
            ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3)),
          const SizedBox(height: 6),
          ...children,
        ]),
      );
}

/// Xác nhận trước khi gửi: chọn nhanh loại sự cố (không bắt buộc), tùy chọn đếm ngược 5s khi mở bằng cách lắc.
class _ConfirmSheet extends StatefulWidget {
  final bool countdown;
  const _ConfirmSheet({required this.countdown});

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  String _type = 'general';
  int _left = 5;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.countdown) {
      _t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          Navigator.pop(context, _type);
        }
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            const Text('Xác nhận gửi SOS khẩn cấp', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Vị trí của bạn sẽ được gửi tới người dùng ở gần và nhà xe. Chọn nhanh loại sự cố (có thể bỏ qua):',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: kSosIncidentTypeLabels.entries
                  .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: _type == e.key,
                        selectedColor: const Color(0xFFFFE0CC),
                        onSelected: (_) => setState(() => _type = e.key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _type),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(widget.countdown ? 'GỬI SOS NGAY (tự gửi sau $_left giây)' : 'GỬI SOS NGAY',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy - tôi không gặp nguy hiểm')),
          ],
        ),
      ),
    );
  }
}
