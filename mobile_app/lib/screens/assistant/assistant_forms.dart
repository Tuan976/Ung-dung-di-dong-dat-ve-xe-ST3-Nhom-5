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
    String? selected,
    ValueChanged<String?> change,
  ) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: widget.locations.contains(selected) ? selected : null,
    decoration: InputDecoration(labelText: label),
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
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 9,
          children: [
            if (widget.settingsError)
              TextButton(
                onPressed: widget.onRetry,
                child: const Text('Tải lại danh sách địa điểm'),
              ),
            _places(
              'Điểm đi',
              _origin,
              (value) => setState(() => _origin = value),
            ),
            _places(
              'Điểm đến',
              _destination,
              (value) => setState(() => _destination = value),
            ),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.busy ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      _date == null
                          ? 'Chọn ngày đi'
                          : DateFormat('dd/MM/yyyy').format(_date!),
                    ),
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: TextFormField(
                    controller: _count,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số vé'),
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
            FilledButton(
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
              child: const Text('Tìm chuyến'),
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
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Mã vé',
              hintText: 'HT12345678',
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
            ),
            maxLength: 20,
            validator: _validatePhone,
          ),
          FilledButton(
            onPressed: widget.busy
                ? null
                : () {
                    if (_form.currentState!.validate()) {
                      widget.onSubmit(_code.text.trim(), _phone.text.trim());
                    }
                  },
            child: const Text('Tra cứu'),
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
