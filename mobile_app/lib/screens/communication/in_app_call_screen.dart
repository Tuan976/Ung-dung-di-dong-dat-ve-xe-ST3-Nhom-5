import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/communication_service.dart';

class InAppCallScreen extends StatefulWidget {
  final int bookingId;
  final String counterpartName;
  final String counterpartRole;
  final bool isIncoming;

  const InAppCallScreen({
    super.key,
    required this.bookingId,
    required this.counterpartName,
    required this.counterpartRole,
    this.isIncoming = false,
  });

  @override
  State<InAppCallScreen> createState() => _InAppCallScreenState();
}

class _InAppCallScreenState extends State<InAppCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasAutoPopped = false;

  static const Color brandOrange = Color(0xFFF26A21);
  static const Color darkBg = Color(0xFF181E29);
  static const Color darkSurface = Color(0xFF263244);
  static const Color callRed = Color(0xFFE53935);
  static const Color callGreen = Color(0xFF43A047);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleAutoPop(CallStatus status) {
    if ((status == CallStatus.ended || status == CallStatus.rejected) &&
        !_hasAutoPopped) {
      _hasAutoPopped = true;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunicationService>(
      builder: (context, commService, child) {
        final status = commService.callStatus;
        _handleAutoPop(status);

        String statusLabel = 'Đang kết nối...';
        Color statusColor = Colors.white70;

        switch (status) {
          case CallStatus.outgoingRinging:
            statusLabel = 'Đang đổ chuông...';
            statusColor = brandOrange;
            break;
          case CallStatus.incomingRinging:
            statusLabel = 'Cuộc gọi thoại đến...';
            statusColor = callGreen;
            break;
          case CallStatus.connected:
            statusLabel = commService.formattedDuration;
            statusColor = Colors.greenAccent;
            break;
          case CallStatus.ended:
            statusLabel = 'Cuộc gọi đã kết thúc';
            statusColor = Colors.redAccent;
            break;
          case CallStatus.rejected:
            statusLabel = 'Cuộc gọi bị từ chối';
            statusColor = Colors.orangeAccent;
            break;
          case CallStatus.idle:
            statusLabel = 'Sẵn sàng';
            break;
        }

        return Scaffold(
          backgroundColor: darkBg,
          body: SafeArea(
            child: Stack(
              children: [
                // Background subtle ambient radial glow
                Positioned(
                  top: -100,
                  left: -50,
                  right: -50,
                  height: 350,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          brandOrange.withOpacity(0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70, size: 20),
                        tooltip: 'Thu nhỏ',
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                size: 13, color: Colors.white60),
                            const SizedBox(width: 5),
                            Text(
                              'Mã vé #${widget.bookingId}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Center Content: Avatar & Info
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulse Avatar
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final scale = (status == CallStatus.connected ||
                                  status == CallStatus.outgoingRinging ||
                                  status == CallStatus.incomingRinging)
                              ? _pulseAnimation.value
                              : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: darkSurface,
                                border: Border.all(
                                  color: brandOrange.withOpacity(0.6),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandOrange.withOpacity(0.25),
                                    blurRadius: 30,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  widget.counterpartName.isNotEmpty
                                      ? widget.counterpartName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: brandOrange,
                                    fontSize: 52,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          widget.counterpartName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Role Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: brandOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.counterpartRole.isNotEmpty
                              ? widget.counterpartRole
                              : 'Chuyến đi',
                          style: const TextStyle(
                            color: brandOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Call Duration / Status
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Row(
                          key: ValueKey<String>(statusLabel),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (status == CallStatus.connected)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Call Controls
                Positioned(
                  bottom: 36,
                  left: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // If incoming call is ringing, show Accept & Reject
                      if (status == CallStatus.incomingRinging) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              icon: Icons.call_end_rounded,
                              label: 'Từ chối',
                              bgColor: callRed,
                              onPressed: () {
                                commService.rejectCall(
                                    bookingId: widget.bookingId);
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.call_rounded,
                              label: 'Nghe máy',
                              bgColor: callGreen,
                              onPressed: () {
                                final user =
                                    context.read<AuthService>().currentUser;
                                final role = (user != null &&
                                        (user.isDriver || user.isStaff))
                                    ? 'OPERATOR'
                                    : 'PASSENGER';
                                commService.answerCall(
                                  bookingId: widget.bookingId,
                                  role: role,
                                );
                              },
                            ),
                          ],
                        ),
                      ] else ...[
                        // In Call / Ringing controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Mute button
                            _buildFeatureToggle(
                              icon: commService.isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: commService.isMuted
                                  ? 'Đã tắt mic'
                                  : 'Tắt mic',
                              isActive: commService.isMuted,
                              onTap: commService.toggleMute,
                            ),

                            // Speaker button
                            _buildFeatureToggle(
                              icon: commService.isSpeakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_down_rounded,
                              label: commService.isSpeakerOn
                                  ? 'Loa ngoài'
                                  : 'Loa trong',
                              isActive: commService.isSpeakerOn,
                              onTap: commService.toggleSpeaker,
                            ),

                            // End call button
                            _buildActionButton(
                              icon: Icons.call_end_rounded,
                              label: 'Kết thúc',
                              bgColor: callRed,
                              onPressed: () {
                                commService.endCall(
                                    bookingId: widget.bookingId);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white
                  : Colors.white.withOpacity(0.12),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? darkBg : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
