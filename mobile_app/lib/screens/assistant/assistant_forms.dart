part of 'assistant_screen.dart';

class _SearchForm extends StatefulWidget {
  const _SearchForm({
    super.key,
    required this.locations,
    required this.criteria,
    required this.busy,
    required this.settingsError,
    required this.onRetry,
    required this.onSubmit,
  });

  final List<String> locations;
  final AssistantData? criteria;
  final bool busy;
  final bool settingsError;
  final VoidCallback onRetry;
  final ValueChanged<AssistantData> onSubmit;

  @override
  State<_SearchForm> createState() => _SearchFormState();
}

class _SearchFormState extends State<_SearchForm> {
  final _form = GlobalKey<FormState>();
  late String? _origin = widget.criteria?['from'] as String?;
  late String? _destination = widget.criteria?['to'] as String?;
  late DateTime? _date = DateTime.tryParse(
    widget.criteria?['date'] as String? ?? '',
  );
  late final _count = TextEditingController(
    text: (widget.criteria?['pax'] ?? 1).toString(),
  );

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final end = today.add(const Duration(days: 730));
    final candidate = _date ?? today;
    final initial = candidate.isBefore(today) || candidate.isAfter(end)
        ? today
        : candidate;
    final date = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: end,
      initialDate: initial,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Widget _places(
    String label,
    IconData icon,
    String? selected,
    ValueChanged<String?> change,
  ) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: widget.locations.contains(selected) ? selected : null,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: _brandOrange),
    ),
    items: [
      for (final place in widget.locations)
        DropdownMenuItem(
          value: place,
          child: Text(place, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: widget.busy ? null : change,
    validator: (value) => value == null ? 'Chọn địa điểm.' : null,
  );

  @override
  Widget build(BuildContext context) {
    return _AssistantCard(
      borderColor: _brandOrange.withValues(alpha: 0.25),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.search_rounded, size: 18, color: _brandOrange),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tìm kiếm chuyến xe',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Chọn điểm đi, điểm đến và ngày khởi hành',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.settingsError)
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tải lại danh sách địa điểm'),
              ),
            _places(
              'Điểm đi',
              Icons.trip_origin_rounded,
              _origin,
              (value) => setState(() => _origin = value),
            ),
            _places(
              'Điểm đến',
              Icons.location_on_rounded,
              _destination,
              (value) => setState(() => _destination = value),
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: widget.busy ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16, color: _brandOrange),
                      label: Text(
                        _date == null
                            ? 'Chọn ngày đi'
                            : DateFormat('dd/MM/yyyy').format(_date!),
                        style: TextStyle(
                          color: _date == null ? AppColors.textSecondary : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    controller: _count,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số vé',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (value) {
                      final count = int.tryParse(value?.trim() ?? '');
                      return count == null || count < 1 || count > 20
                          ? 'Từ 1 đến 20'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed:
                  widget.busy || _date == null || widget.locations.isEmpty
                  ? null
                  : () {
                      if (!_form.currentState!.validate()) return;
                      widget.onSubmit({
                        'from': _origin,
                        'to': _destination,
                        'date': DateFormat('yyyy-MM-dd').format(_date!),
                        'pax': int.parse(_count.text.trim()),
                      });
                    },
              icon: const Icon(Icons.directions_bus_rounded, size: 18),
              label: const Text('Tìm chuyến'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookupForm extends StatefulWidget {
  const _LookupForm({
    super.key,
    this.code,
    required this.busy,
    required this.onSubmit,
  });

  final String? code;
  final bool busy;
  final void Function(String code, String phone) onSubmit;

  @override
  State<_LookupForm> createState() => _LookupFormState();
}

class _LookupFormState extends State<_LookupForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.code);
  final _phone = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AssistantCard(
    borderColor: _brandOrange.withValues(alpha: 0.25),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.manage_search_rounded, size: 18, color: _brandOrange),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tra cứu vé xe điện tử',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Nhập mã đặt vé và số điện thoại đã đăng ký',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Mã vé',
              hintText: 'HT12345678',
              prefixIcon: Icon(Icons.confirmation_number_outlined, size: 19),
              counterText: '',
            ),
            maxLength: 10,
            validator: (value) =>
                RegExp(
                  r'^HT\d{8}$',
                  caseSensitive: false,
                ).hasMatch(value?.trim() ?? '')
                ? null
                : 'Nhập mã vé hợp lệ.',
          ),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại đặt vé',
              prefixIcon: Icon(Icons.phone_outlined, size: 19),
              counterText: '',
            ),
            maxLength: 20,
            validator: _validatePhone,
          ),
          FilledButton.icon(
            onPressed: widget.busy
                ? null
                : () {
                    if (_form.currentState!.validate()) {
                      widget.onSubmit(_code.text.trim(), _phone.text.trim());
                    }
                  },
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Tra cứu'),
          ),
        ],
      ),
    ),
  );
}

String? _validatePhone(String? value) =>
    RegExp(r'^\d{8,15}$')
        .hasMatch((value ?? '').replaceAll(RegExp(r'[\s.-]'), ''))
    ? null
    : 'Nhập số điện thoại hợp lệ.';
