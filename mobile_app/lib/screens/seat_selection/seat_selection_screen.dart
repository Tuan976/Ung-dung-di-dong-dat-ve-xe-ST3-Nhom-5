import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/trip_service.dart';
import '../../models/trip.dart';
import '../../core/constants/app_colors.dart';

class SeatSelectionScreen extends StatefulWidget {
  final Trip initialTrip;

  const SeatSelectionScreen({super.key, required this.initialTrip});

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
              backgroundColor: Colors.red,
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
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final seatMap = _trip.seatMap ?? [];

    final seatsA = seatMap.where((s) => s.startsWith('A')).toList();
    final seatsB = seatMap.where((s) => s.startsWith('B')).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22, color: Color(0xFF475569)),
            onPressed: _refreshSeatMap,
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CHỌN GHẾ & ĐẶT VÉ',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Text('${_trip.departureStation} - ${_trip.arrivalStation} • ${_trip.departureTime}'.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.white, const Color(0xFFE2E8F0), 'TRỐNG'),
                const SizedBox(width: 16),
                _legendItem(const Color(0xFFEA580C), const Color(0xFFEA580C), 'ĐANG CHỌN'),
                const SizedBox(width: 16),
                _legendItem(const Color(0xFFCBD5E1), const Color(0xFFCBD5E1), 'ĐÃ BÁN'),
              ],
            ),

            const SizedBox(height: 24),

            // Seat map
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0B192C)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (seatsA.isNotEmpty) _buildFloor('TẦNG DƯỚI', seatsA),
                          if (seatsA.isNotEmpty && seatsB.isNotEmpty) const SizedBox(width: 20),
                          if (seatsB.isNotEmpty) _buildFloor('TẦNG TRÊN', seatsB),
                        ],
                      ),
                    ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: const Color(0x0F0F172A), blurRadius: 12, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedSeat != null ? 'Ghế: $_selectedSeat' : 'Chưa chọn ghế',
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedSeat != null ? fmt.format(_trip.price) : '0đ',
                          style: const TextStyle(color: Color(0xFF00639B), fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _selectedSeat == null
                          ? null
                          : () async {
                              final result = await context.push('/passenger_info', extra: {
                                'trip': _trip,
                                'seat': _selectedSeat,
                              });
                              if (result == true) _refreshSeatMap();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B192C),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text('Tiếp tục',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _legendItem(Color fill, Color border, String label) {
    return Row(
      children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: 1),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildFloor(String title, List<String> seats) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 16,
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
      fill = const Color(0xFFCBD5E1);
      border = const Color(0xFFCBD5E1);
      textColor = Colors.white;
    } else if (isSelected) {
      fill = const Color(0xFFEA580C);
      border = const Color(0xFFEA580C);
      textColor = Colors.white;
    } else {
      fill = Colors.white;
      border = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF0F172A);
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x40EA580C), blurRadius: 8, offset: Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          seat,
          style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
