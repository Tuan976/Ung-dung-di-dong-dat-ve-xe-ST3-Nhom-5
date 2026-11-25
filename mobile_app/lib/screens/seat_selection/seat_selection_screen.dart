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
    if (_trip.seatMap == null || _trip.seatMap!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshSeatMap();
      });
    }
  }

  Future<void> _refreshSeatMap() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final updatedTrip = await context.read<TripService>().getTripDetails(_trip.id);
      if (!mounted) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải sơ đồ ghế: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSeatTap(String seat) {
    if (_trip.bookedSeats.contains(seat)) return;
    setState(() {
      _selectedSeat = _selectedSeat == seat ? null : seat;
    });
  }

  /// Phân tách danh sách ghế thành 2 tầng (Tầng dưới / Tầng trên) hỗ trợ mọi định dạng:
  /// 1. A01..A17 / B01..B17 (bắt đầu bằng A / B)
  /// 2. 1A, 1B, 1D, 1E..9A, 9B (kết thúc bằng A, B cho Tầng dưới và C, D, E cho Tầng trên)
  /// 3. A1D, B1D / A1T, B1T (kết thúc bằng D / T)
  /// 4. Fallback: Tự sinh ghế hoặc chia đôi danh sách theo tổng số ghế
  ({List<String> lower, List<String> upper}) _partitionSeats() {
    List<String> raw = _trip.seatMap ?? [];

    if (raw.isEmpty) {
      final total = _trip.totalSeats > 0 ? _trip.totalSeats : 34;
      final half = (total / 2).ceil();
      final generated = <String>[
        for (int i = 1; i <= half; i++) 'A${i.toString().padLeft(2, '0')}',
        for (int i = 1; i <= total - half; i++) 'B${i.toString().padLeft(2, '0')}',
      ];
      raw = generated;
    }

    // Định dạng kết thúc bằng D (Tầng dưới) và T (Tầng trên), VD: A1D, A1T
    final endsD = raw.where((s) => s.length >= 3 && s.toUpperCase().endsWith('D') && RegExp(r'^[A-C]\d+D$', caseSensitive: false).hasMatch(s)).toList();
    final endsT = raw.where((s) => s.length >= 3 && s.toUpperCase().endsWith('T') && RegExp(r'^[A-C]\d+T$', caseSensitive: false).hasMatch(s)).toList();
    if (endsD.isNotEmpty && endsT.isNotEmpty && (endsD.length + endsT.length) == raw.length) {
      return (lower: endsD, upper: endsT);
    }

    // Định dạng bắt đầu bằng A (Tầng dưới) và B (Tầng trên), VD: A01..A17, B01..B17
    final startsA = raw.where((s) => s.toUpperCase().startsWith('A')).toList();
    final startsB = raw.where((s) => s.toUpperCase().startsWith('B')).toList();
    if (startsA.isNotEmpty || startsB.isNotEmpty) {
      return (lower: startsA, upper: startsB);
    }

    // Định dạng số hàng + cột chữ cái: 1A, 1B, 1D, 1E, 2A, 2B, 2D, 2E...
    final colAB = raw.where((s) => RegExp(r'^\d+[AB]$', caseSensitive: false).hasMatch(s)).toList();
    final colCDE = raw.where((s) => RegExp(r'^\d+[C-E]$', caseSensitive: false).hasMatch(s)).toList();
    if (colAB.isNotEmpty || colCDE.isNotEmpty) {
      return (lower: colAB, upper: colCDE);
    }

    // Fallback: Chia đều 2 tầng nếu có nhiều hơn 12 ghế, ngược lại hiển thị 1 tầng
    if (raw.length > 12) {
      final mid = (raw.length / 2).ceil();
      return (lower: raw.sublist(0, mid), upper: raw.sublist(mid));
    }
    return (lower: raw, upper: const <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final floors = _partitionSeats();
    final seatsA = floors.lower;
    final seatsB = floors.upper;

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
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (seatsA.isNotEmpty)
                                Expanded(
                                  child: _buildFloor(
                                    seatsB.isEmpty ? 'SƠ ĐỒ GHẾ' : 'TẦNG DƯỚI',
                                    seatsA,
                                    showDriver: true,
                                  ),
                                ),
                              if (seatsA.isNotEmpty && seatsB.isNotEmpty) const SizedBox(width: 14),
                              if (seatsB.isNotEmpty)
                                Expanded(
                                  child: _buildFloor(
                                    'TẦNG TRÊN',
                                    seatsB,
                                    showDriver: false,
                                  ),
                                ),
                            ],
                          ),
                        ),
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

  /// Sắp xếp ghế trong mỗi tầng thành các hàng (2 ghế mỗi hàng cho xe giường nằm 34 chỗ)
  List<List<String>> _chunkIntoRows(List<String> seats, int perRow) {
    final rows = <List<String>>[];
    for (int i = 0; i < seats.length; i += perRow) {
      final end = (i + perRow < seats.length) ? i + perRow : seats.length;
      rows.add(seats.sublist(i, end));
    }
    return rows;
  }

  Widget _buildFloor(String title, List<String> seats, {required bool showDriver}) {
    final rows = _chunkIntoRows(seats, 2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$title (${seats.length} ghế)',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (showDriver)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bus_rounded, size: 15, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                  const SizedBox(width: 5),
                  const Text(
                    'Khoang Tài xế (Đầu xe)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stairs_rounded, size: 15, color: AppColors.textSecondary),
                  SizedBox(width: 5),
                  Text(
                    'Lối lên Tầng trên',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Column(
            children: [
              for (int r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final seat in rows[r]) _buildSeat(seat),
                    if (rows[r].length == 1) const SizedBox(width: 54),
                  ],
                ),
              ],
            ],
          ),
        ],
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
        width: 54,
        height: 48,
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
              size: 14,
              color: isSelected
                  ? Colors.white
                  : isOccupied
                      ? AppColors.seatOccupiedIcon
                      : AppColors.primary.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 2),
            Text(
              seat,
              style: TextStyle(
                color: textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
