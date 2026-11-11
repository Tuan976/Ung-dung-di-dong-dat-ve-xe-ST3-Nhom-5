import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/communication_service.dart';
import '../screens/communication/in_app_call_screen.dart';

class IncomingCallHost extends StatefulWidget {
  final Widget child;
  const IncomingCallHost({super.key, required this.child});

  @override
  State<IncomingCallHost> createState() => _IncomingCallHostState();
}

class _IncomingCallHostState extends State<IncomingCallHost> {
  bool _isShowingDialog = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkMonitoring();
  }

  void _checkMonitoring() {
    final auth = context.watch<AuthService>();
    final commService = context.read<CommunicationService>();

    if (auth.isAuthenticated) {
      final user = auth.currentUser;
      final role = (user != null && user.isOperator)
          ? 'OPERATOR'
          : 'PASSENGER';

      commService.startIncomingCallMonitoring(
        role: role,
        userId: user?.id,
        phone: user?.phone,
      );
    }
  }

  void _handleIncomingCall(CommunicationService commService) {
    if (commService.callStatus == CallStatus.incomingRinging && !_isShowingDialog) {
      _isShowingDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIncomingDialog(commService);
      });
    }
  }

  void _showIncomingDialog(CommunicationService commService) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Consumer<CommunicationService>(
          builder: (context, cs, _) {
            // Nếu người gọi dập máy giữa chừng, tự động đóng hộp thoại
            if (cs.callStatus != CallStatus.incomingRinging) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                }
              });
            }

            final user = context.read<AuthService>().currentUser;
            final myRole = (user != null && user.isOperator)
                ? 'OPERATOR'
                : 'PASSENGER';

            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Incoming Call Header Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_in_talk, color: Color(0xFF4ADE80), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'CUỘC GỌI ĐẾN',
                            style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F172A),
                        border: Border.all(color: const Color(0xFFF26A21), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          cs.counterpartName.isNotEmpty ? cs.counterpartName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Color(0xFFF26A21),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Name
                    Text(
                      cs.counterpartName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      '${cs.counterpartRole} • Mã vé #${cs.activeBookingId ?? ""}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions: Reject and Accept
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Nút từ chối
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (cs.activeBookingId != null) {
                                  cs.rejectCall(bookingId: cs.activeBookingId!);
                                }
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFEF4444),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Từ chối', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),

                        // Nút nghe máy
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final bId = cs.activeBookingId;
                                final cName = cs.counterpartName;
                                final cRole = cs.counterpartRole;

                                if (bId != null) {
                                  cs.answerCall(bookingId: bId, role: myRole);
                                }
                                Navigator.pop(ctx);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InAppCallScreen(
                                      bookingId: bId ?? 0,
                                      counterpartName: cName,
                                      counterpartRole: cRole,
                                      isIncoming: true,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF10B981),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.call, color: Colors.white, size: 26),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Nghe máy', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _isShowingDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final commService = context.watch<CommunicationService>();
    _handleIncomingCall(commService);
    return widget.child;
  }
}

