import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/shared_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  final _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get('/api/v1/notifications');
      if (response.statusCode == 200) {
        setState(() {
          _notifications = response.data;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Vừa xong';
      if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
      if (difference.inHours < 24) return '${difference.inHours} giờ trước';
      return '${difference.inDays} ngày trước';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    onPressed: _loadNotifications,
                    icon: const Icon(Icons.done_all_rounded, color: AppColors.primary, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _notifications.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.notifications_none_rounded,
                          title: 'Chưa có thông báo mới',
                          description: 'Các cập nhật về vé xe, lịch khởi hành và ưu đãi sẽ hiển thị tại đây.',
                          buttonText: 'Tìm chuyến xe',
                          onButtonPressed: () => context.go('/home'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _notifications.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];

                              IconData icon = Icons.notifications_outlined;
                              Color iconColor = AppColors.primary;
                              Color iconBg = AppColors.primaryLight;
                              Color? indicatorColor = AppColors.primary;

                              if (notif['type'] == 'SUCCESS') {
                                icon = Icons.check_circle_outline_rounded;
                                iconColor = AppColors.success;
                                iconBg = AppColors.successBg;
                                indicatorColor = AppColors.primary;
                              } else if (notif['type'] == 'PROMO') {
                                icon = Icons.local_offer_outlined;
                                iconColor = AppColors.primary;
                                iconBg = AppColors.primaryLight;
                                indicatorColor = AppColors.primary;
                              } else if (notif['type'] == 'REMINDER') {
                                icon = Icons.schedule_rounded;
                                iconColor = AppColors.warning;
                                iconBg = AppColors.warningBg;
                              }

                              return _buildNotificationItem(
                                title: notif['title'] ?? '',
                                content: notif['message'] ?? '',
                                time: _formatTime(notif['created_at']),
                                icon: icon,
                                iconColor: iconColor,
                                iconBg: iconBg,
                                indicatorColor: notif['is_read'] == true ? null : indicatorColor,
                              );
                            },
                          ),
                        ),
            ),

            const AppNavBar(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String content,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    Color? indicatorColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (indicatorColor != null) Container(width: 4, color: indicatorColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              content,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
