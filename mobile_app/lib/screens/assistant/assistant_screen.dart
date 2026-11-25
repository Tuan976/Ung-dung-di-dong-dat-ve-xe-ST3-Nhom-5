import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../services/assistant_service.dart';

part 'assistant_checkout.dart';
part 'assistant_forms.dart';

const _brandOrange = AppColors.primary;
const _greeting =
    'Xin chào! Mình là Trợ lý Triply. Bạn muốn tìm chuyến xe, đặt vé nhanh hay tra cứu vé đã đặt?';
final _currency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);
String _price(Object? value) => value is num ? _currency.format(value) : '—';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.service});

  final AssistantService? service;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final _service = widget.service ?? AssistantService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<AssistantData> _messages = [
    {'response': _greeting},
  ];
  List<String> _locations = [];
  AssistantData? _panel;
  bool _busy = false;
  bool _gemini = false;
  bool _settingsError = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _service.settings();
      if (!mounted) return;
      setState(() {
        _locations = (settings['locations'] as List? ?? const [])
            .whereType<String>()
            .toList();
        _gemini = settings['gemini_enabled'] == true;
        _settingsError = false;
      });
    } on AssistantException {
      if (mounted) setState(() => _settingsError = true);
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send(AssistantData action, {String? userText}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      if (userText != null) _messages.add({'response': userText, 'user': true});
    });
    _scrollDown();
    try {
      final reply = await _service.ask(action);
      if (!mounted) return;
      final checkout = reply['checkout'];
      setState(() {
        if (action['action'] == 'reset') {
          _messages
            ..clear()
            ..add({'response': _greeting});
          _input.clear();
        } else {
          _messages.add(reply);
        }
        _panel = checkout is AssistantData
            ? {'panel': 'checkout', 'checkout': checkout}
            : reply['panel'] == 'search' || reply['panel'] == 'lookup'
                ? reply
                : null;
      });
    } on AssistantException catch (error) {
      if (!mounted) return;
      setState(
        () => _messages.add({
          'response': error.message,
          if (error.authRequired)
            'links': [
              {'label': 'Đăng nhập tài khoản', 'href': '/auth'},
            ],
        }),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollDown();
      }
    }
  }

  bool get _booking => _panel?['panel'] == 'checkout';

  void _sendText() {
    final value = _input.text.trim();
    if (value.isEmpty || _busy || _booking) return;
    _input.clear();
    _send({'message': value}, userText: value);
  }

  void _showPanel(String type, {String? code}) {
    setState(() {
      if (_panel?['panel'] == type && code == null) {
        _panel = null;
      } else {
        _panel = {'panel': type, 'code': code};
      }
    });
    _scrollDown();
  }

  Future<void> _cancel(AssistantData ticket) async {
    final code = ticket['code'];
    if (code is! String) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Xác nhận hủy vé',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Text(
          "Bạn có chắc chắn muốn hủy vé $code (Ghế ${ticket['seat']}) không?",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ vé', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy vé'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _send({'action': 'cancel_ticket', 'code': code, 'confirmed': true});
    }
  }

  Future<void> _openLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null || uri.hasAuthority || uri.hasScheme) return;
    switch (uri.path) {
      case '/':
        context.go('/home');
      case '/auth':
        context.push(switch (uri.queryParameters['mode']) {
          'register' => '/register',
          'forgot' => '/forgot_password',
          _ => '/login',
        });
      case '/profile':
        context.push('/profile');
      case '/search':
        context.push(
          Uri(
            path: '/search_results',
            queryParameters: {
              'from': uri.queryParameters['start_point'] ?? '',
              'to': uri.queryParameters['end_point'] ?? '',
              'date': uri.queryParameters['date'] ?? '',
            },
          ).toString(),
        );
      default:
        if (!RegExp(r'^/thong-tin/[a-z-]+$').hasMatch(uri.path)) return;
        await _launch(
          Uri.parse(ApiConfig.baseUrl).replace(path: uri.path, query: ''),
        );
    }
  }

  Future<void> _launch(Uri uri) async {
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không mở được đường dẫn.')));
    }
  }

  void _completed(AssistantData result) {
    setState(() {
      _messages.add(result);
      _panel = null;
    });
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && !_booking;
    final activePanel = _panel?['panel'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppColors.textPrimary),
          tooltip: 'Quay lại',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Center(
                child: Icon(Icons.directions_bus_rounded, color: _brandOrange, size: 21),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Trợ lý Triply',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Flexible(
                        child: Text(
                          'Đang hoạt động • Đặt vé nhanh 24/7',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            onPressed: enabled ? () => _send({'action': 'reset'}) : null,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  for (final message in _messages) _message(message, enabled),
                  if (_busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              size: 15,
                              color: _brandOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _brandOrange,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Trợ lý Triply đang tìm thông tin…',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_panel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildPanel(_panel!),
                    ),
                ],
              ),
            ),

            // Bottom Quick Actions & Message Composer
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick Actions Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 8,
                      children: [
                        _QuickActionButton(
                          icon: Icons.search_rounded,
                          label: 'Tìm chuyến',
                          isActive: activePanel == 'search',
                          onPressed: enabled ? () => _showPanel('search') : null,
                        ),
                        _QuickActionButton(
                          icon: Icons.manage_search_rounded,
                          label: 'Tra vé',
                          isActive: activePanel == 'lookup',
                          onPressed: enabled ? () => _showPanel('lookup') : null,
                        ),
                        _QuickActionButton(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Vé của tôi',
                          isActive: false,
                          onPressed: enabled
                              ? () => _send(
                                    {'action': 'tickets'},
                                    userText: 'Vé của tôi',
                                  )
                              : null,
                        ),
                        _QuickActionButton(
                          icon: Icons.support_agent_rounded,
                          label: 'Hỗ trợ',
                          isActive: false,
                          onPressed: enabled
                              ? () => _send(
                                    {'message': 'Liên hệ hỗ trợ'},
                                    userText: 'Liên hệ hỗ trợ',
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Modern Input Bar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            controller: _input,
                            enabled: !_booking,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendText(),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              filled: false,
                              hintText: 'Nhập hành trình: TP.HCM đi Đà Lạt mai, 2 vé...',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                              ),
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: _brandOrange,
                            disabledBackgroundColor: AppColors.border,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          tooltip: 'Gửi tin nhắn',
                          onPressed: enabled ? _sendText : null,
                          icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                  if (_gemini)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 12, color: _brandOrange),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Câu tìm chuyến có thể được xử lý bằng Google Gemini.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(AssistantData panel) => switch (panel['panel']) {
    'search' => _SearchForm(
      key: ObjectKey(panel),
      locations: _locations,
      criteria: panel['criteria'] as AssistantData?,
      busy: _busy,
      settingsError: _settingsError,
      onRetry: _loadSettings,
      onSubmit: (criteria) => _send({'action': 'search', ...criteria}),
    ),
    'lookup' => _LookupForm(
      key: ObjectKey(panel),
      code: panel['code'] as String?,
      busy: _busy,
      onSubmit: (code, phone) => _send({
        'action': 'lookup',
        'code': code,
        'phone': phone,
      }, userText: 'Tra cứu vé $code'),
    ),
    _ => _Checkout(
      key: ObjectKey(panel),
      service: _service,
      data: panel['checkout'] as AssistantData,
      onBack: () => setState(() => _panel = null),
      onDone: _completed,
    ),
  };

  Widget _message(AssistantData data, bool enabled) {
    final user = data['user'] == true;
    final criteria = data['criteria'];
    final url = Uri.tryParse(data['payment_url'] as String? ?? '');
    final responseText = (data['response'] as String? ?? '').trim();

    // Deduplicate links by href/label so no repeated guidance buttons appear
    final rawLinks = assistantItems(data['links']);
    final seenLabels = <String>{};
    final uniqueLinks = <AssistantData>[];
    for (final link in rawLinks) {
      final label = (link['label'] as String? ?? '').trim();
      if (label.isNotEmpty && seenLabels.add(label)) {
        uniqueLinks.add(link);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (responseText.isNotEmpty)
            Row(
              mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!user) ...[
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(top: 2, right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _brandOrange.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      size: 16,
                      color: _brandOrange,
                    ),
                  ),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: user ? _brandOrange : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(user ? 16 : 4),
                        bottomRight: Radius.circular(user ? 4 : 16),
                      ),
                      border: Border.all(
                        color: user ? _brandOrange : AppColors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (user ? _brandOrange : AppColors.textPrimary)
                              .withValues(alpha: user ? 0.16 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      responseText,
                      style: TextStyle(
                        color: user ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: user ? FontWeight.w500 : FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Search criteria summary pill
          if (criteria is AssistantData &&
              criteria['from'] != null &&
              criteria['to'] != null)
            Container(
              margin: const EdgeInsets.only(left: 38),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _brandOrange.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route_rounded, size: 16, color: _brandOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        "${criteria['from']} → ${criteria['to']}",
                        if (criteria['date'] is String)
                          (criteria['date'] as String).split('-').reversed.join('/'),
                        if (criteria['pax'] != null) "${criteria['pax']} hành khách",
                        if (criteria['time'] != null) criteria['time'],
                      ].join(' • '),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Trip Result Cards
          for (final trip in assistantItems(data['trips']))
            _TripCard(
              trip: trip,
              select: enabled
                  ? () => _send({
                        'action': 'select_trip',
                        'trip_id': trip['trip_id'],
                      }, userText: "Chọn chuyến ${trip['time_text']}")
                  : null,
            ),

          // Ticket Result Cards
          for (final ticket in assistantItems(data['tickets']))
            _TicketCard(
              ticket: ticket,
              onView: enabled && ticket['booking_id'] is int
                  ? () => context.push("/tickets/${ticket['booking_id']}")
                  : null,
              onCancel: enabled && ticket['can_cancel'] == true
                  ? () => _cancel(ticket)
                  : null,
            ),

          // Action buttons & Deep links
          if (data['clear_filters'] == true ||
              uniqueLinks.isNotEmpty ||
              (data['codes'] as List? ?? const []).isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (data['clear_filters'] == true)
                  OutlinedButton.icon(
                    onPressed: enabled
                        ? () => _send({'action': 'clear_filters'})
                        : null,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: const Text('Bỏ lọc giờ và loại xe'),
                  ),
                for (final link in uniqueLinks)
                  OutlinedButton.icon(
                    onPressed: enabled
                        ? () => _openLink(link['href'] as String)
                        : null,
                    icon: const Icon(Icons.open_in_new_rounded, size: 15, color: _brandOrange),
                    label: Text(link['label'] as String),
                  ),
                for (final code
                    in (data['codes'] as List? ?? const []).whereType<String>())
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.successBg,
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.successBorder),
                    ),
                    onPressed: enabled
                        ? () => _showPanel('lookup', code: code)
                        : null,
                    icon: const Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.success),
                    label: Text('Tra vé $code'),
                  ),
              ],
            ),

          if (url != null && url.scheme == 'https' && url.hasAuthority)
            FilledButton.icon(
              onPressed: enabled ? () => _launch(url) : null,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Mở cổng thanh toán'),
            ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primaryLight : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? _brandOrange : AppColors.border,
              width: isActive ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? _brandOrange : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? _brandOrange : AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? AppColors.border, width: 1),
      boxShadow: AppColors.cardShadow,
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, this.select});

  final AssistantData trip;
  final VoidCallback? select;

  @override
  Widget build(BuildContext context) {
    final routeText = (trip['route_text'] as String? ?? '');
    final parts = routeText.split('→').map((s) => s.trim()).toList();
    final origin = parts.isNotEmpty ? parts.first : routeText;
    final destination = parts.length > 1 ? parts.last : '';
    final companyName = trip['company_name'] as String? ?? 'Nhà xe Triply';
    final busType = trip['bus_type_text'] as String? ?? 'Limousine';
    final timeText = trip['time_text'] as String? ?? '';
    final seats = trip['available_seats'];
    final seatCount = seats is int ? seats : int.tryParse('$seats') ?? 0;
    final isLowSeats = seatCount > 0 && seatCount <= 5;

    return _AssistantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Company + Bus Type + Available seats badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: _brandOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            busType,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isLowSeats ? AppColors.warningBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLowSeats ? AppColors.warningBorder : AppColors.successBorder,
                  ),
                ),
                child: Text(
                  '$seatCount ghế trống',
                  style: TextStyle(
                    color: isLowSeats ? AppColors.warning : AppColors.success,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Middle box: Route & Departure Time
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route origin -> destination
                if (destination.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.trip_origin_rounded, size: 15, color: _brandOrange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          origin,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
                      ),
                      const Icon(Icons.location_on_rounded, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          destination,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    routeText,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 15, color: _brandOrange),
                    const SizedBox(width: 6),
                    const Text(
                      'Khởi hành:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        timeText,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Footer: Highlighted Price + Select Seat CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giá vé niêm yết',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _price(trip['price_value']),
                          style: const TextStyle(
                            color: _brandOrange,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const TextSpan(
                          text: ' / vé',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 42,
                child: FilledButton.icon(
                  onPressed: select,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.event_seat_rounded, size: 17),
                  label: const Text('Chọn ghế'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, this.onView, this.onCancel});

  final AssistantData ticket;
  final VoidCallback? onView;
  final VoidCallback? onCancel;

  String _label(Object? key) =>
      const {
        'CONFIRMED': 'Đã xác nhận',
        'HOLD': 'Đang giữ chỗ',
        'CANCELLED': 'Đã hủy',
        'Paid': 'Đã thanh toán',
        'Pending': 'Chờ thu tiền',
        'Unpaid': 'Chưa thanh toán',
        'Refund Pending': 'Chờ hoàn tiền',
        'Expired': 'Hết hạn',
        'Cancelled': 'Đã hủy',
      }[key] ??
      key?.toString() ??
      '—';

  @override
  Widget build(BuildContext context) {
    final statusRaw = ticket['status']?.toString() ?? '';
    final isCancelled = statusRaw == 'CANCELLED' || statusRaw == 'Cancelled';
    final isConfirmed = statusRaw == 'CONFIRMED' || statusRaw == 'Paid';

    final badgeBg = isCancelled
        ? AppColors.errorBg
        : isConfirmed
            ? AppColors.successBg
            : AppColors.warningBg;
    final badgeFg = isCancelled
        ? AppColors.error
        : isConfirmed
            ? AppColors.success
            : AppColors.warning;

    return _AssistantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded, size: 16, color: _brandOrange),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${ticket['code']}",
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _label(ticket['status']),
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticket['route'] as String? ?? '',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "${ticket['departure']} • Ghế ${ticket['seat']} • ${_price(ticket['price'])}",
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (ticket['pickup'] is String && (ticket['pickup'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Điểm đón: ${ticket['pickup']}",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
          if (ticket['dropoff'] is String && (ticket['dropoff'] as String).isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              "Điểm trả: ${ticket['dropoff']}",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Thanh toán: ${_label(ticket['payment_status'])}',
            style: const TextStyle(
              color: _brandOrange,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onView != null || onCancel != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                if (onView != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Mở vé'),
                    ),
                  ),
                if (onView != null && onCancel != null) const SizedBox(width: 8),
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.errorBorder),
                      ),
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                      label: const Text('Hủy vé'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
