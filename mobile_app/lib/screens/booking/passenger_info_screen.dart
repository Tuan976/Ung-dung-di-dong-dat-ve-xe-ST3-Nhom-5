import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../models/trip.dart';

class PassengerInfoScreen extends StatefulWidget {
  final Trip trip;
  final String seat;

  const PassengerInfoScreen({
    super.key,
    required this.trip,
    required this.seat,
  });

  @override
  State<PassengerInfoScreen> createState() => _PassengerInfoScreenState();
}

class _PassengerInfoScreenState extends State<PassengerInfoScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedPickup;
  String? _selectedDropoff;

  final List<String> _pickups = ['Bến xe Gia Lâm', 'Bến xe Mỹ Đình', 'Bến xe Giáp Bát'];
  final List<String> _dropoffs = ['Bến xe Cầu Rào', 'Bến xe Niệm Nghĩa', 'Bến xe Thượng Lý'];

  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
    }
    _selectedPickup = _pickups.first;
    _selectedDropoff = _dropoffs.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isBooking = true);

    try {
      final booking = await context.read<BookingService>().createBooking(
        tripId: widget.trip.id,
        seatNumber: widget.seat,
        passengerName: _nameController.text.trim(),
        passengerPhone: _phoneController.text.trim(),
        pickupPoint: _selectedPickup,
        dropoffPoint: _selectedDropoff,
      );

      if (!mounted) return;
      context.pushReplacement('/payment', extra: {
        'booking': booking,
        'trip': widget.trip,
      });
    } on BookingConflictException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ghế đã được đặt', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          content: Text(e.message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); 
                context.pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
              child: const Text('Chọn ghế khác', style: TextStyle(color: Colors.white)),
            ),
          ],
        )
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, TextInputType type = TextInputType.text, int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label${required ? ' *' : ''}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
          ),
          validator: required ? (v) => v == null || v.isEmpty ? 'Vui lòng nhập $label' : null : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
              onChanged: onChanged,
              items: items.map<DropdownMenuItem<String>>((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: const Text('Thông tin hành khách', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)), onPressed: () {}),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSection('Thông tin liên hệ', Column(
                      children: [
                        _buildTextField('Họ và tên', _nameController, required: true),
                        const SizedBox(height: 16),
                        _buildTextField('Số điện thoại', _phoneController, required: true, type: TextInputType.phone),
                        const SizedBox(height: 16),
                        _buildTextField('Email (Tùy chọn)', _emailController, type: TextInputType.emailAddress, hint: 'minh.nguyen@example.com'),
                      ],
                    )),
                    
                    _buildSection('Điểm đón / Điểm trả', Column(
                      children: [
                        _buildDropdown('Điểm đón', _selectedPickup, _pickups, (val) => setState(() => _selectedPickup = val)),
                        const SizedBox(height: 16),
                        _buildDropdown('Điểm trả', _selectedDropoff, _dropoffs, (val) => setState(() => _selectedDropoff = val)),
                      ],
                    )),

                    _buildSection('Yêu cầu đặc biệt', _buildTextField('', _noteController, maxLines: 3, hint: 'Ví dụ: Say xe cần ngồi ghế đầu, mang theo vật nuôi...')),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isBooking ? null : _createBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: _isBooking
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Tiếp tục thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
