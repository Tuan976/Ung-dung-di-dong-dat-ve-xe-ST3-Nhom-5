import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/trip_service.dart';
import '../../services/map_booking_service.dart';
import '../../models/booking_strategy.dart';
import '../../models/trip.dart';
import '../../models/map_station.dart';
import '../../widgets/shared_components.dart';

class SearchResultsScreen extends StatefulWidget {
  final String from;
  final String to;
  final String date;
  final MapStation? pickupStop;
  final MapStation? dropoffStop;

  const SearchResultsScreen({
    super.key,
    required this.from,
    required this.to,
    required this.date,
    this.pickupStop,
    this.dropoffStop,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Future<List<Trip>> _futureTrips;
  RouteBookingStrategy? _strategy;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _checkMapStrategy();
  }

  void _loadTrips() {
    _futureTrips = context.read<TripService>().searchTrips(
          from: widget.from,
          to: widget.to,
          date: widget.date,
        );
  }

  Future<void> _checkMapStrategy() async {
    try {
      final s = await MapBookingService().getRouteStrategy(from: widget.from, to: widget.to);
      if (mounted) {
        setState(() => _strategy = s);
      }
    } catch (_) {}
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.from,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                            ),
                            Flexible(
                              child: Text(
                                widget.to,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Khởi hành: ${_formatDate(widget.date)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_strategy?.hasMapConfig == true)
                    InkWell(
                      onTap: () {
                        context.push(
                          '/map_booking?route_id=${_strategy?.routeId ?? ""}&direction=${_strategy?.direction ?? "forward"}&from=${Uri.encodeComponent(widget.from)}&to=${Uri.encodeComponent(widget.to)}&date=${widget.date}&passengers=1',
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, size: 15, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Bản đồ',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const BookingStepIndicator(currentStep: 1),
            const Divider(height: 1, color: AppColors.border),

            if (widget.pickupStop != null || widget.dropoffStop != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.pickupStop != null)
                            Text(
                              'Điểm đón: ${widget.pickupStop!.name}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (widget.dropoffStop != null)
                            Text(
                              'Điểm trả: ${widget.dropoffStop!.name}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // List
            Expanded(
              child: FutureBuilder<List<Trip>>(
                future: _futureTrips,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    return EmptyStateWidget(
                      icon: Icons.wifi_off_rounded,
                      title: 'Không thể tải danh sách chuyến',
                      description: '${snapshot.error}',
                      buttonText: 'Thử lại',
                      onButtonPressed: () => setState(_loadTrips),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.directions_bus_outlined,
                      title: 'Không tìm thấy chuyến xe phù hợp',
                      description: 'Hãy thử đổi ngày khởi hành hoặc chọn tuyến đường khác.',
                      buttonText: 'Chọn lại hành trình',
                      onButtonPressed: () => context.pop(),
                    );
                  }

                  final trips = snapshot.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final isLowSeat = trip.availableSeats <= 5;
                      return AppCard(
                        onTap: () => context.push('/trip/${trip.id}', extra: {
                          'pickup_stop': widget.pickupStop,
                          'dropoff_stop': widget.dropoffStop,
                        }),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Top: Company + Bus type + Seat status
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.directions_bus_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trip.companyName,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        trip.busType,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: 'Còn ${trip.availableSeats} chỗ',
                                  type: isLowSeat ? BadgeType.warning : BadgeType.success,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Middle: Departure & Arrival Timeline
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trip.departureTime,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        trip.departureStation,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  height: 1.5,
                                                  color: AppColors.border,
                                                ),
                                              ),
                                              const Icon(
                                                Icons.directions_bus_rounded,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                              Expanded(
                                                child: Container(
                                                  height: 1.5,
                                                  color: AppColors.border,
                                                ),
                                              ),
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.success,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Chuyến thẳng',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        trip.arrivalTime.isNotEmpty ? trip.arrivalTime : '--:--',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        trip.arrivalStation,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Bottom: Highlighted Price + Select Trip CTA
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Giá vé',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    Text(
                                      fmt.format(trip.price),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: () => context.push('/trip/${trip.id}', extra: {
                                      'pickup_stop': widget.pickupStop,
                                      'dropoff_stop': widget.dropoffStop,
                                    }),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'Chọn chuyến',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
