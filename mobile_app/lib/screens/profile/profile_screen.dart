import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/shared_components.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final name = user?.name ?? 'Khách hàng Triply';
    final phone = user?.phone ?? 'Chưa cập nhật số điện thoại';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TriplyLogo(iconSize: 30, fontSize: 17),
                  Text(
                    'Tài khoản cá nhân',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 60),
                ],
              ),
            ),

            // Avatar & User Info Card
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    phone,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Menu Items
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Operator Portal Entry Card (Clean Orange & White Commercial Design)
                    AppCard(
                      onTap: () => context.push('/operator'),
                      color: AppColors.surfaceWarm,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cổng Quản Trị Nhà Xe Triply',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Điều hành chuyến xe, sơ đồ ghế, hành khách & doanh thu',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 15),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildMenuItem(
                      Icons.chat_bubble_outline_rounded,
                      'Trợ lý đặt vé Triply 24/7',
                      () => context.push('/assistant'),
                      badge: 'AI',
                    ),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      Icons.history_rounded,
                      'Lịch sử đặt vé & chuyến đi',
                      () => context.push('/trip-history'),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      Icons.confirmation_number_outlined,
                      'Quản lý vé của tôi',
                      () => context.go('/tickets'),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      Icons.auto_awesome_outlined,
                      'Trợ lý thị giác AI Vision',
                      () => context.push('/vision'),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      Icons.article_outlined,
                      'Điều khoản & Chính sách bảo mật',
                      () => context.push('/terms'),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      Icons.support_agent_rounded,
                      'Trung tâm hỗ trợ khách hàng',
                      () => context.push('/assistant'),
                    ),

                    const SizedBox(height: 20),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.errorBorder),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await context.read<AuthService>().logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                        label: const Text(
                          'Đăng xuất tài khoản',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            const AppNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {String? badge}) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (badge != null) ...[
            StatusBadge(label: badge, type: BadgeType.primary),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
