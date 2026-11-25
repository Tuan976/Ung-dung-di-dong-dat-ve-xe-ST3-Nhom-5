import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/trip_service.dart';
import '../../models/trip.dart';
import '../../widgets/shared_components.dart';

class SeatSelectionScreen extends StatefulWidget {
  final Trip initialTrip;
  final String? initialPickup;
  final String? initialDropoff;
  final String? pickupStationId;
  final String? dropoffStationId;

  const SeatSelectionScreen({
    super.key,
    required this.initialTrip,
    this.initialPickup,
    this.initialDropoff,
    this.pickupStationId,
    this.dropoffStationId,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  late Trip _trip;
  bool _isLoading = false;
  String? _selectedSeat;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
  }

  Future<void> _refreshSeatMap() async {
    setState(() => _isLoading = true);
    try {
      final updatedTrip = await context.read<TripService>().getTripDetails(_trip.id);
      setState(() {
        _trip = updatedTrip;
        if (_selectedSeat != null && _trip.bookedSeats.contains(_selectedSeat)) {
          _selectedSeat = null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ghế bạn chọn vừa được người khác đặt. Vui lòng chọn ghế khác.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSeatTap(String seat) {
    if (_trip.bookedSeats.contains(seat)) return;
    setState(() {
      _selectedSeat = _selectedSeat == seat ? null : seat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final seatMap = _trip.seatMap ?? [];

    final seatsA = seatMap.where((s) => s.startsWith('A')).toList();
    final seatsB = seatMap.where((s) => s.startsWith('B')).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn vị trí ghế',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_trip.departureStation} → ${_trip.arrivalStation} • ${_trip.departureTime}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới sơ đồ ghế',
            icon: const Icon(Icons.refresh_rounded, size: 21, color: AppColors.textPrimary),
            onPressed: _refreshSeatMap,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const BookingStepIndicator(currentStep: 2),
            const Divider(height: 1, color: AppColors.border),

            // Legend Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendItem(Colors.white, AppColors.seatAvailableBorder, 'Ghế trống'),
                  const SizedBox(width: 20),
                  _legendItem(AppColors.primary, AppColors.primary, 'Đang chọn'),
                  const SizedBox(width: 20),
                  _legendItem(AppColors.seatOccupied, AppColors.seatOccupied, 'Đã đặt'),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Seat Map Floors
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (seatsA.isNotEmpty) _buildFloor('TẦNG DƯỚI', seatsA, showDriver: true),
                          if (seatsA.isNotEmpty && seatsB.isNotEmpty) const SizedBox(width: 14),
                          if (seatsB.isNotEmpty) _buildFloor('TẦNG TRÊN', seatsB, showDriver: false),
                        ],
                      ),
                    ),
            ),

            // Sticky Bottom Summary & CTA
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Ghế đã chọn: ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedSeat != null ? AppColors.primaryLight : AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedSeat ?? 'Chưa chọn',
                                style: TextStyle(
                                  color: _selectedSeat != null ? AppColors.primary : AppColors.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedSeat != null ? fmt.format(_trip.price) : '0 đ',
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
                    text: 'Tiếp tục',
                    icon: Icons.arrow_forward_rounded,
                    width: 150,
                    height: 48,
                    onPressed: _selectedSeat == null
                        ? null
                        : () async {
                            final result = await context.push('/passenger_info', extra: {
                              'trip': _trip,
                              'seat': _selectedSeat,
                              'pickup': widget.initialPickup,
                              'dropoff': widget.initialDropoff,
                              'pickup_station_id': widget.pickupStationId,
                              'dropoff_station_id': widget.dropoffStationId,
                            });
                            if (result == true) _refreshSeatMap();
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color fill, Color border, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFloor(String title, List<String> seats, {required bool showDriver}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (showDriver)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      const Text(
                        'Tài xế',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: seats.map((s) => _buildSeat(s)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeat(String seat) {
    final isOccupied = _trip.bookedSeats.contains(seat);
    final isSelected = _selectedSeat == seat;

    Color fill;
    Color border;
    Color textColor;

    if (isOccupied) {
      fill = AppColors.seatOccupied;
      border = AppColors.seatOccupied;
      textColor = AppColors.textMuted;
    } else if (isSelected) {
      fill = AppColors.primary;
      border = AppColors.primary;
      textColor = Colors.white;
    } else {
      fill = Colors.white;
      border = AppColors.seatAvailableBorder;
      textColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: border, width: 1.4),
          boxShadow: isSelected ? AppColors.activeGlow : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_seat_rounded,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : isOccupied
                      ? AppColors.seatOccupiedIcon
                      : AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 1),
            Text(
              seat,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
