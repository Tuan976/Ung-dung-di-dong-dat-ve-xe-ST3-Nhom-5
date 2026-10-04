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

    // Group seats by row (A, B, C...)
    final Map<String, List<String>> rows = {};
    for (final seat in seatMap) {
      final row = seat.replaceAll(RegExp(r'[0-9]'), '');
      rows.putIfAbsent(row, () => []).add(seat);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF0F172A)),
                  ),
                  const Expanded(
                    child: Text('Chọn ghế',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  GestureDetector(
                    onTap: _refreshSeatMap,
                    child: const Icon(Icons.refresh, size: 22, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),

            // Route info strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFFE0F2FE),
              child: Text(
                '${_trip.departureStation} → ${_trip.arrivalStation} • ${_trip.departureTime}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF0B192C), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),

            // Legend
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _legendItem(const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), 'Trống'),
                  _legendItem(const Color(0xFF0B192C), const Color(0xFF0B192C), 'Đang chọn'),
                  _legendItem(const Color(0xFF94A3B8), const Color(0xFF94A3B8), 'Đã đặt'),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Seat map
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0B192C)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Bus front indicator
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_bus, size: 16, color: Color(0xFF94A3B8)),
                                SizedBox(width: 6),
                                Text('Đầu xe', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                          ),
                          if (rows.isEmpty)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: seatMap.map((s) => _buildSeat(s)).toList(),
                            )
                          else
                            ...rows.entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 24,
                                        alignment: Alignment.center,
                                        child: Text(e.key,
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(width: 8),
                                      ...e.value.map((s) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 5),
                                            child: _buildSeat(s),
                                          )),
                                    ],
                                  ),
                                )),
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
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSeat(String seat) {
    final isOccupied = _trip.bookedSeats.contains(seat);
    final isSelected = _selectedSeat == seat;

    Color fill;
    Color border;
    Color textColor;

    if (isOccupied) {
      fill = const Color(0xFF94A3B8);
      border = const Color(0xFF94A3B8);
      textColor = Colors.white;
    } else if (isSelected) {
      fill = const Color(0xFF0B192C);
      border = const Color(0xFF0B192C);
      textColor = Colors.white;
    } else {
      fill = const Color(0xFFF1F5F9);
      border = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF0F172A);
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x400B192C), blurRadius: 8, offset: Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          seat,
          style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
