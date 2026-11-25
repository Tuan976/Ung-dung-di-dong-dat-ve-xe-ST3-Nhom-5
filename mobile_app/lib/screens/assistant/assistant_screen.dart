import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../services/assistant_service.dart';

part 'assistant_checkout.dart';
part 'assistant_forms.dart';

const _navy = Color(0xFF18243A);
const _orange = Color(0xFFB63A16);
const _greeting = 'Bạn muốn tìm chuyến, đặt vé hay tra vé đã đặt?';
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
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
              {'label': 'Đăng nhập', 'href': '/auth'},
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
    setState(() => _panel = {'panel': type, 'code': code});
    _scrollDown();
  }

  Future<void> _cancel(AssistantData ticket) async {
    final code = ticket['code'];
    if (code is! String) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy vé'),
        content: Text("Bạn muốn hủy vé $code, ghế ${ticket['seat']}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ vé'),
          ),
          FilledButton(
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Trợ lý HUTECH BUS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            onPressed: enabled ? () => _send({'action': 'reset'}) : null,
            icon: Icon(
              Icons.refresh,
              color: enabled ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(15),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  for (final message in _messages) _message(message, enabled),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Đang xử lý…'),
                        ],
                      ),
                    ),
                  if (_panel != null) _buildPanel(_panel!),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 7,
                      children: [
                        ActionChip(
                          label: const Text('Tìm chuyến'),
                          onPressed: enabled
                              ? () => _showPanel('search')
                              : null,
                        ),
                        ActionChip(
                          label: const Text('Tra vé'),
                          onPressed: enabled
                              ? () => _showPanel('lookup')
                              : null,
                        ),
                        ActionChip(
                          label: const Text('Vé của tôi'),
                          onPressed: enabled
                              ? () => _send({
                                  'action': 'tickets',
                                }, userText: 'Vé của tôi')
                              : null,
                        ),
                        ActionChip(
                          label: const Text('Hỗ trợ'),
                          onPressed: enabled
                              ? () => _send({'message': 'Liên hệ hỗ trợ'})
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          enabled: !_booking,
                          maxLength: 500,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendText(),
                          decoration: const InputDecoration(
                            labelText: 'Tin nhắn cho trợ lý',
                            hintText: 'TP.HCM đi Cư Jút mai, 2 vé',
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Gửi tin nhắn',
                        onPressed: enabled ? _sendText : null,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                  if (_gemini)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Câu tìm chuyến có thể được xử lý bằng Google Gemini.',
                        style: Theme.of(context).textTheme.bodySmall,
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
      }, userText: 'Tra cứu vé'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Align(
            alignment: user ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: user ? _orange : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: user ? _orange : AppColors.border),
              ),
              child: Text(
                data['response'] as String? ?? '',
                style: TextStyle(
                  color: user ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (criteria is AssistantData &&
              criteria['from'] != null &&
              criteria['to'] != null)
            Text(
              [
                "${criteria['from']} → ${criteria['to']}",
                if (criteria['date'] is String)
                  (criteria['date'] as String).split('-').reversed.join('/'),
                if (criteria['pax'] != null) "${criteria['pax']} vé",
                if (criteria['time'] != null) criteria['time'],
              ].join(' · '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          if (data['clear_filters'] == true)
            OutlinedButton(
              onPressed: enabled
                  ? () => _send({'action': 'clear_filters'})
                  : null,
              child: const Text('Bỏ lọc giờ và loại xe'),
            ),
          for (final link in assistantItems(data['links']))
            OutlinedButton(
              onPressed: enabled
                  ? () => _openLink(link['href'] as String)
                  : null,
              child: Text(link['label'] as String),
            ),
          for (final code
              in (data['codes'] as List? ?? const []).whereType<String>())
            OutlinedButton(
              onPressed: enabled
                  ? () => _showPanel('lookup', code: code)
                  : null,
              child: Text('Tra vé $code'),
            ),
          if (url != null && url.scheme == 'https' && url.hasAuthority)
            FilledButton(
              onPressed: enabled ? () => _launch(url) : null,
              child: const Text('Mở cổng thanh toán'),
            ),
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, this.select});

  final AssistantData trip;
  final VoidCallback? select;

  @override
  Widget build(BuildContext context) => _AssistantCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(
          trip['route_text'] as String,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          "${trip['company_name']} · ${trip['bus_type_text']}",
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        Text("${trip['time_text']} · ${trip['available_seats']} ghế trống"),
        Text(
          "${_price(trip['price_value'])} / vé",
          style: const TextStyle(color: _orange, fontWeight: FontWeight.w800),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: select, child: const Text('Chọn ghế')),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => _AssistantCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        Text(
          "${ticket['code']} · ${_label(ticket['status'])}",
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(ticket['route'] as String),
        Text(
          "${ticket['departure']} · Ghế ${ticket['seat']} · ${_price(ticket['price'])}",
        ),
        if (ticket['pickup'] is String &&
            (ticket['pickup'] as String).isNotEmpty)
          Text("Điểm đón: ${ticket['pickup']}"),
        if (ticket['dropoff'] is String &&
            (ticket['dropoff'] as String).isNotEmpty)
          Text("Điểm trả: ${ticket['dropoff']}"),
        Text(_label(ticket['payment_status'])),
        Wrap(
          spacing: 8,
          children: [
            if (onView != null)
              OutlinedButton(onPressed: onView, child: const Text('Mở vé')),
            if (onCancel != null)
              OutlinedButton(onPressed: onCancel, child: const Text('Hủy vé')),
          ],
        ),
      ],
    ),
  );
}
