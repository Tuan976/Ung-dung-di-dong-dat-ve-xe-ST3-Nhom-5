import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/booking.dart';
import '../../models/trip.dart';
import '../../widgets/shared_components.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Booking booking;
  final Trip trip;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Celebratory Success Badge
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.successBorder, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.success, size: 42),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Đặt vé thành công!',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Vé điện tử của bạn đã được xác nhận trên hệ thống Triply.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                    ),

                    const SizedBox(height: 24),

                    // Commercial E-Ticket Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.cardShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Top Brand Header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            color: AppColors.primary,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MÃ VÉ ĐIỆN TỬ',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      booking.ticketCode,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Ghế ${booking.seatNumber}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Route Display
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        trip.departureStation,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                      child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
                                    ),
                                    Flexible(
                                      child: Text(
                                        trip.arrivalStation,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Real QR Code
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border, width: 1.5),
                                  ),
                                  child: QrImageView(
                                    data: booking.ticketCode,
                                    version: QrVersions.auto,
                                    size: 148,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Xuất trình mã QR này cho nhân viên nhà xe khi lên xe',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),

                                const SizedBox(height: 20),
                                const Divider(height: 1, color: AppColors.border),
                                const SizedBox(height: 16),

                                _buildDetailRow('Nhà xe vận hành:', trip.companyName.isNotEmpty ? trip.companyName : 'Triply Partner'),
                                const SizedBox(height: 10),
                                _buildDetailRow(
                                  'Thời gian khởi hành:',
                                  '${trip.departureTime}${trip.departureDate.isNotEmpty ? " • ${trip.departureDate}" : ""}',
                                ),
                                const SizedBox(height: 10),
                                _buildDetailRow(
                                  'Vị trí ghế ngồi:',
                                  'Ghế ${booking.seatNumber}',
                                  valueColor: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  PrimaryButton(
                    text: 'Xem chi tiết vé',
                    icon: Icons.confirmation_number_outlined,
                    onPressed: () => context.pushReplacement('/tickets/${booking.id}'),
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    text: 'Về trang chủ',
                    icon: Icons.home_outlined,
                    width: double.infinity,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color valueColor = AppColors.textPrimary}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: valueColor, fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
