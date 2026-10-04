import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_nav_bar.dart';

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
      print('Error loading notifications: $e');
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(Icons.done_all, color: Color(0xFF0F172A), size: 24),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00639B)))
                : _notifications.isEmpty
                  ? const Center(
                      child: Text(
                        'Bạn chưa có thông báo nào.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      color: const Color(0xFF00639B),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          
                          IconData icon = Icons.info_outline;
                          Color iconColor = const Color(0xFF475569);
                          Color iconBg = const Color(0xFFF1F5F9);
                          Color? indicatorColor;

                          if (notif['type'] == 'SUCCESS') {
                            icon = Icons.check;
                            iconColor = const Color(0xFF10B981);
                            iconBg = const Color(0xFFD1FAE5);
                            indicatorColor = const Color(0xFF00639B);
                          } else if (notif['type'] == 'PROMO') {
                            icon = Icons.percent;
                            iconColor = const Color(0xFF0284C7);
                            iconBg = const Color(0xFFE0F2FE);
                            indicatorColor = const Color(0xFF00639B);
                          } else if (notif['type'] == 'REMINDER') {
                            icon = Icons.access_time_filled;
                            iconColor = const Color(0xFFD97706);
                            iconBg = const Color(0xFFFEF3C7);
                          }

                          return _buildNotificationItem(
                            title: notif['title'] ?? '',
                            content: notif['message'] ?? '',
                            time: _formatTime(notif['created_at']),
                            icon: icon,
                            iconColor: iconColor,
                            iconBg: iconBg,
                            indicatorColor: notif['is_read'] ? null : indicatorColor,
                          );
                        },
                      ),
                    ),
            ),

            AppNavBar(currentIndex: 2),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (indicatorColor != null)
                Container(width: 4, color: indicatorColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
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
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
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
                                color: Color(0xFF475569),
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
