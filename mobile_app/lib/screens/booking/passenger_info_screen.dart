import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../models/trip.dart';
import '../../services/smart_boarding_service.dart';
import '../../widgets/shared_components.dart';

class PassengerInfoScreen extends StatefulWidget {
  final Trip trip;
  final String seat;
  final String? initialPickup;
  final String? initialDropoff;
  final String? pickupStationId;
  final String? dropoffStationId;

  const PassengerInfoScreen({
    super.key,
    required this.trip,
    required this.seat,
    this.initialPickup,
    this.initialDropoff,
    this.pickupStationId,
    this.dropoffStationId,
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

  late final List<String> _pickups = [
    'Bến xe trung tâm ${widget.trip.departureStation}',
    'Văn phòng nhà xe tại ${widget.trip.departureStation}',
    'Điểm đón dọc Quốc lộ (${widget.trip.departureStation})',
  ];
  late final List<String> _dropoffs = [
    'Bến xe trung tâm ${widget.trip.arrivalStation}',
    'Văn phòng nhà xe tại ${widget.trip.arrivalStation}',
    'Điểm trả dọc Quốc lộ (${widget.trip.arrivalStation})',
  ];

  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
    }

    if (widget.initialPickup != null && widget.initialPickup!.isNotEmpty) {
      if (!_pickups.contains(widget.initialPickup)) {
        _pickups.insert(0, widget.initialPickup!);
      }
      _selectedPickup = widget.initialPickup;
    } else {
      _selectedPickup = _pickups.first;
    }

    if (widget.initialDropoff != null && widget.initialDropoff!.isNotEmpty) {
      if (!_dropoffs.contains(widget.initialDropoff)) {
        _dropoffs.insert(0, widget.initialDropoff!);
      }
      _selectedDropoff = widget.initialDropoff;
    } else {
      _selectedDropoff = _dropoffs.first;
    }
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
        pickupStationId: widget.pickupStationId,
        dropoffStationId: widget.dropoffStationId,
      );

      SmartBoardingService.instance.notifyPaymentPending(
        ticketCode: booking.ticketCode,
        routeName: widget.trip.routeName,
        seatNumber: widget.seat,
        expiresAt: booking.expiresAt,
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Ghế vừa được đặt',
            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800),
          ),
          content: Text(e.message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop(true);
              },
              child: const Text('Chọn ghế khác'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? hint,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            '$label${required ? ' *' : ''}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 19, color: AppColors.textSecondary) : null,
          ),
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập $label' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    IconData icon,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: items.contains(value) ? value : items.first,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 19, color: AppColors.primary),
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thông tin hành khách',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            const BookingStepIndicator(currentStep: 3),
            const Divider(height: 1, color: AppColors.border),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Booking Context Summary Banner
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.trip.departureStation} → ${widget.trip.arrivalStation}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.trip.companyName} • ${widget.trip.departureTime}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: 'Ghế ${widget.seat}',
                            type: BadgeType.primary,
                          ),
                        ],
                      ),
                    ),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin liên hệ nhận vé',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            'Họ và tên hành khách',
                            _nameController,
                            required: true,
                            hint: 'VD: Nguyễn Văn Minh',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            'Số điện thoại',
                            _phoneController,
                            required: true,
                            type: TextInputType.phone,
                            hint: 'VD: 0912345678',
                            icon: Icons.phone_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            'Email nhận vé điện tử (Tùy chọn)',
                            _emailController,
                            type: TextInputType.emailAddress,
                            hint: 'minh.nguyen@example.com',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Điểm đón & Điểm trả',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildDropdown(
                            'Điểm đón khách',
                            Icons.trip_origin_rounded,
                            _selectedPickup,
                            _pickups,
                            (val) => setState(() => _selectedPickup = val),
                          ),
                          const SizedBox(height: 14),
                          _buildDropdown(
                            'Điểm trả khách',
                            Icons.location_on_rounded,
                            _selectedDropoff,
                            _dropoffs,
                            (val) => setState(() => _selectedDropoff = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ghi chú cho nhà xe',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            '',
                            _noteController,
                            maxLines: 3,
                            hint: 'Ví dụ: Cần hỗ trợ hành lý, đón đúng điểm hẹn...',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tổng thanh toán',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fmt.format(widget.trip.price),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PrimaryButton(
                      text: 'Tiếp tục thanh toán',
                      isLoading: _isBooking,
                      onPressed: _createBooking,
                      width: 190,
                      height: 48,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
