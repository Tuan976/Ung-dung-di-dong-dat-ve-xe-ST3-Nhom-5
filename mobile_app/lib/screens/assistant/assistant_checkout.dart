part of 'assistant_screen.dart';

class _Checkout extends StatefulWidget {
  const _Checkout({
    super.key,
    required this.service,
    required this.data,
    required this.onBack,
    required this.onDone,
  });

  final AssistantService service;
  final AssistantData data;
  final VoidCallback onBack;
  final ValueChanged<AssistantData> onDone;

  @override
  State<_Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<_Checkout> {
  final _form = GlobalKey<FormState>();
  final _selected = <String>{};
  late final _trip = widget.data['trip'] as AssistantData;
  late final _quantity = widget.data['pax'] as int;
  late final _contact = widget.data['contact'] as AssistantData;
  late final _name = TextEditingController(
    text: _contact['name'] as String? ?? '',
  );
  late final _phone = TextEditingController(
    text: _contact['phone'] as String? ?? '',
  );
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  AssistantData? _map;
  String _payment = 'cash';
  String? _error;
  bool _loading = false;
  bool _reviewing = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pickup.dispose();
    _dropoff.dispose();
    super.dispose();
  }

  Future<void> _loadSeats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final map = await widget.service.seats(_trip['trip_id'] as int);
      if (!mounted) return;
      if (map['price'] is! num || map['seat_map'] is! List) {
        throw const AssistantException('Sơ đồ ghế chưa sẵn sàng.');
      }
      setState(() {
        _selected.clear();
        _map = map;
        _reviewing = false;
      });
    } on AssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Iterable<List<AssistantData>> _rows(AssistantData floor) sync* {
    for (final row in floor['rows'] as List? ?? const []) {
      yield assistantItems(row);
    }
  }

  void _autoSelect(List<AssistantData> floors) {
    bool available(AssistantData seat) =>
        seat['status'] == 'available' && seat['id'] is String;
    final rows = floors.expand(_rows).toList();
    final sameRow = rows
        .where((row) => row.where(available).length >= _quantity)
        .firstOrNull;
    final pool = (sameRow ?? rows.expand((row) => row)).where(available);
    setState(() {
      _selected
        ..clear()
        ..addAll(pool.take(_quantity).map((seat) => seat['id'] as String));
      _error = _selected.length < _quantity
          ? 'Chuyến này hiện không đủ ghế trống.'
          : null;
    });
  }

  void _review() {
    if (_selected.length != _quantity || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _reviewing = true;
    });
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.service.book({
        'trip_id': _trip['trip_id'],
        'seats': _selected.toList(),
        'expected_price': _map!['price'],
        'name': _name.text.trim(),
        'phone': _phone.text.trim().replaceAll(RegExp(r'[\s.-]'), ''),
        'pickup': _pickup.text.trim(),
        'dropoff': _dropoff.text.trim(),
        'payment_method': _payment,
      });
      if (!mounted) return;
      final checkout = Uri.tryParse(result['checkoutUrl'] as String? ?? '');
      final codes = (result['ticket_codes'] as List? ?? const [])
          .whereType<String>()
          .toList();
      if (checkout?.scheme == 'https' && checkout!.hasAuthority) {
        widget.onDone({
          'response': 'Đã giữ ghế. Bạn mở cổng thanh toán để hoàn tất.',
          'payment_url': checkout.toString(),
        });
      } else if (codes.isNotEmpty) {
        widget.onDone({
          'response': 'Đã đặt vé thành công. Bạn thanh toán tiền mặt trên xe.',
          'codes': codes,
        });
      } else {
        setState(
          () => _error = 'Bạn kiểm tra lại vé đã đặt trước khi thử lại.',
        );
      }
    } on AssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _seatLegend() {
    Widget dot(Color bg, Color border, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        dot(Colors.white, AppColors.seatAvailableBorder, 'Ghế trống'),
        dot(_brandOrange, _brandOrange, 'Đang chọn'),
        dot(AppColors.seatOccupied, AppColors.seatOccupied, 'Đã đặt'),
      ],
    );
  }

  Widget _seatRows(List<AssistantData> floors) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _seatLegend(),
        const Divider(height: 1, color: AppColors.border),
        for (final floor in floors) ...[
          Text(
            floor['floor'] as String? ?? 'Sơ đồ ghế',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          for (final row in _rows(floor))
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final seat in row)
                  if (seat['id'] is String)
                    FilterChip(
                      label: Text(
                        (seat['name'] ?? seat['id']).toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: _selected.contains(seat['id'])
                              ? Colors.white
                              : seat['status'] == 'available'
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                        ),
                      ),
                      showCheckmark: false,
                      selectedColor: _brandOrange,
                      backgroundColor: Colors.white,
                      disabledColor: AppColors.seatOccupied,
                      side: BorderSide(
                        color: _selected.contains(seat['id'])
                            ? _brandOrange
                            : AppColors.border,
                      ),
                      selected: _selected.contains(seat['id']),
                      onSelected: seat['status'] != 'available'
                          ? null
                          : (selected) {
                              setState(() {
                                _error = null;
                                final id = seat['id'] as String;
                                if (!selected) {
                                  _selected.remove(id);
                                } else if (_selected.length < _quantity) {
                                  _selected.add(id);
                                }
                              });
                            },
                    ),
              ],
            ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final map = _map;
    return _AssistantCard(
      borderColor: _brandOrange.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _reviewing ? Icons.fact_check_outlined : Icons.event_seat_rounded,
                  size: 18,
                  color: _brandOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reviewing ? 'Xác nhận đặt vé' : 'Chọn ghế và thông tin',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "${_trip['route_text']} · ${_trip['time_text']}",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _submitting ? null : widget.onBack,
                child: const Text('Quay lại'),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(color: _brandOrange),
            )
          else if (map != null && !_reviewing)
            _details(assistantItems(map['seat_map']))
          else if (map != null)
            _summary(map['price'] as num),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_error != null && !_loading && !_submitting)
            OutlinedButton.icon(
              onPressed: _loadSeats,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tải lại sơ đồ ghế'),
            ),
        ],
      ),
    );
  }

  Widget _details(List<AssistantData> floors) {
    final available = floors
        .expand(_rows)
        .expand((row) => row)
        .where((seat) => seat['status'] == 'available')
        .length;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _brandOrange.withValues(alpha: 0.2)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  'Đã chọn ${_selected.length}/$_quantity ghế',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  onPressed: available >= _quantity
                      ? () => _autoSelect(floors)
                      : null,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
                  label: Text('Chọn giúp $_quantity ghế'),
                ),
              ],
            ),
          ),
          _seatRows(floors),
          TextFormField(
            controller: _name,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Họ tên hành khách',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
              counterText: '',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên hành khách.'
                : null,
          ),
          TextFormField(
            controller: _phone,
            maxLength: 20,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại liên hệ',
              prefixIcon: Icon(Icons.phone_outlined, size: 19),
              counterText: '',
            ),
            validator: _validatePhone,
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pickup,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Điểm đón',
                    counterText: '',
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _dropoff,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Điểm trả',
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: _payment,
            decoration: const InputDecoration(
              labelText: 'Phương thức thanh toán',
              prefixIcon: Icon(Icons.payments_outlined, size: 19),
            ),
            items: [
              const DropdownMenuItem(
                value: 'cash',
                child: Text('Tiền mặt trên xe'),
              ),
              if (widget.data['online_payment'] == true)
                const DropdownMenuItem(
                  value: 'payos',
                  child: Text('Thanh toán qua PayOS'),
                ),
            ],
            onChanged: (value) => setState(() => _payment = value ?? 'cash'),
          ),
          FilledButton(
            onPressed: _selected.length == _quantity ? _review : null,
            child: const Text('Xem lại đơn'),
          ),
        ],
      ),
    );
  }

  Widget _summary(num price) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              'Ghế ${_selected.join(', ')} · ${_name.text.trim()} · ${_phone.text.trim()}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 13.5,
              ),
            ),
            if (_pickup.text.trim().isNotEmpty)
              Text(
                'Điểm đón: ${_pickup.text.trim()}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            if (_dropoff.text.trim().isNotEmpty)
              Text(
                'Điểm trả: ${_dropoff.text.trim()}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            Text(
              _payment == 'cash' ? 'Tiền mặt trên xe' : 'Thanh toán qua PayOS',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 12, color: AppColors.border),
            Text(
              'Tổng cộng ${_price(price * _selected.length)}',
              style: const TextStyle(
                color: _brandOrange,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: _submitting
                ? null
                : () => setState(() {
                      _reviewing = false;
                      _error = null;
                    }),
            child: const Text('Chỉnh sửa'),
          ),
          FilledButton(
            onPressed: _submitting ? null : _confirm,
            child: Text(_submitting ? 'Đang đặt vé…' : 'Xác nhận đặt vé'),
          ),
        ],
      ),
    ],
  );
}
