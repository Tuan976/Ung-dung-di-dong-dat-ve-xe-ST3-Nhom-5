import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/communication_service.dart';
import 'in_app_call_screen.dart';

class TripChatScreen extends StatefulWidget {
  final int bookingId;
  final String? counterpartName;
  final String? counterpartRole;

  const TripChatScreen({
    super.key,
    required this.bookingId,
    this.counterpartName,
    this.counterpartRole,
  });

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;

  bool _isLoading = true;
  String _targetName = 'Đối phương';
  String _targetRole = '';
  String _busPlate = '';
  List<Map<String, dynamic>> _messages = [];

  static const Color brandOrange = Color(0xFFF26A21);
  static const Color brandOrangeLight = Color(0xFFFFF0E6);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color bgOverall = Color(0xFFF8F9FB);
  static const Color textMain = Color(0xFF263244);
  static const Color textSub = Color(0xFF778397);
  static const Color borderSubtle = Color(0xFFE7EAF0);

  final List<String> _quickReplies = [
    'Xe sắp tới chưa ạ?',
    'Tôi đã đến điểm đón rồi ạ.',
    'Tôi mặc áo đen, đứng trước cây xăng.',
    'Bác tài đợi tôi 2 phút nhé!',
    'Xe đang trên đường tới điểm đón.',
    'Bác chuẩn bị hành lý nhé, xe tới ngay.',
  ];

  @override
  void initState() {
    super.initState();
    _targetName = widget.counterpartName ?? 'Nhà xe / Tài xế';
    _targetRole = widget.counterpartRole ?? '';
    _loadMessages();

    // Polling tin nhắn mới mỗi 3 giây
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final commService = context.read<CommunicationService>();
    final data = await commService.getChatHistory(widget.bookingId);

    if (mounted && data != null) {
      final user = context.read<AuthService>().currentUser;
      final isDriverOrStaff = user != null && (user.isDriver || user.isStaff);

      final p = data['passenger'] as Map<String, dynamic>?;
      final op = data['operator'] as Map<String, dynamic>?;

      setState(() {
        if (isDriverOrStaff) {
          _targetName = p?['name'] ?? widget.counterpartName ?? 'Hành khách';
          _targetRole = 'Hành khách • Ghế ${p?['seat'] ?? "N/A"}';
        } else {
          _targetName = op?['driver_name'] ?? widget.counterpartName ?? 'Tài xế';
          _busPlate = op?['bus_plate'] ?? '';
          _targetRole = 'Tài xế xe $_busPlate';
        }
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _isLoading = false;
      });

      if (!silent) _scrollToBottom();
    } else if (!silent && mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, {String type = 'TEXT'}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _msgController.clear();
    final user = context.read<AuthService>().currentUser;
    final isDriverOrStaff = user != null && (user.isDriver || user.isStaff);
    final senderRole = isDriverOrStaff ? 'OPERATOR' : 'PASSENGER';
    final senderName = user?.name ?? (isDriverOrStaff ? 'Tài xế' : 'Hành khách');

    // Thêm tạm thời vào list để hiển thị mượt mà tức thì
    final tempMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_role': senderRole,
      'sender_name': senderName,
      'message': cleanText,
      'message_type': type,
      'created_at': 'Vừa xong',
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    final commService = context.read<CommunicationService>();
    await commService.sendMessage(
      bookingId: widget.bookingId,
      message: cleanText,
      senderRole: senderRole,
      senderName: senderName,
      messageType: type,
    );
  }

  void _startInAppCall() {
    final user = context.read<AuthService>().currentUser;
    final isDriverOrStaff = user != null && (user.isDriver || user.isStaff);
    final callerRole = isDriverOrStaff ? 'OPERATOR' : 'PASSENGER';
    final callerName = user?.name ?? (isDriverOrStaff ? 'Tài xế' : 'Hành khách');

    final commService = context.read<CommunicationService>();
    commService.initiateCall(
      bookingId: widget.bookingId,
      callerRole: callerRole,
      callerName: callerName,
      receiverName: _targetName,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppCallScreen(
          bookingId: widget.bookingId,
          counterpartName: _targetName,
          counterpartRole: _targetRole,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isDriverOrStaff = user != null && (user.isDriver || user.isStaff);
    final myRole = isDriverOrStaff ? 'OPERATOR' : 'PASSENGER';

    return Scaffold(
      backgroundColor: bgOverall,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: borderSubtle, width: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: brandOrangeLight,
                shape: BoxShape.circle,
                border: Border.all(color: brandOrange.withOpacity(0.3)),
              ),
              child: const Icon(Icons.person, color: brandOrange, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _targetName,
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _targetRole.isNotEmpty ? _targetRole : 'Chuyến xe #${widget.bookingId}',
                    style: const TextStyle(color: textSub, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // NÚT GỌI THOẠI TRONG APP
          IconButton(
            tooltip: 'Gọi thoại trực tiếp trong app',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: brandOrangeLight,
                shape: BoxShape.circle,
                border: Border.all(color: brandOrange.withOpacity(0.4)),
              ),
              child: const Icon(Icons.phone_in_talk, color: brandOrange, size: 18),
            ),
            onPressed: _startInAppCall,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // 1. Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: brandOrange))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: brandOrangeLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline, color: brandOrange, size: 40),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có tin nhắn nào',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textMain),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Nhắn tin để trao đổi điểm đón và giờ chạy thuận tiện!',
                              style: TextStyle(color: textSub, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_role'] == myRole;
                          final isCallLog = msg['message_type'] == 'CALL_LOG';

                          if (isCallLog) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  msg['message'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: textSub,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? brandOrange : surfaceWhite,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                border: isMe ? null : Border.all(color: borderSubtle),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['message'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : textMain,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['created_at'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white.withOpacity(0.7) : textSub,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 2. Quick Replies Horizontal Bar
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _quickReplies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final reply = _quickReplies[i];
                return ActionChip(
                  label: Text(
                    reply,
                    style: const TextStyle(fontSize: 11, color: textMain, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: surfaceWhite,
                  side: const BorderSide(color: borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  onPressed: () => _sendMessage(reply, type: 'QUICK_REPLY'),
                );
              },
            ),
          ),

          // 3. Bottom Input Row
          Container(
            padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).padding.bottom + 8),
            decoration: const BoxDecoration(
              color: surfaceWhite,
              border: Border(top: BorderSide(color: borderSubtle, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: const TextStyle(fontSize: 13, color: textSub),
                      filled: true,
                      fillColor: bgOverall,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: brandOrange, width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) => _sendMessage(val),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: brandOrange,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_msgController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
