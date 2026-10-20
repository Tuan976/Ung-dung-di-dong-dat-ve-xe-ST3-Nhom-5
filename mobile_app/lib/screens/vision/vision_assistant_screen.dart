import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/config/vision_config.dart';
import '../../services/vision_service.dart';
import '../../services/booking_service.dart';
import '../../models/vision_result.dart';

class VisionAssistantScreen extends StatefulWidget {
  const VisionAssistantScreen({super.key});

  @override
  State<VisionAssistantScreen> createState() => _VisionAssistantScreenState();
}

class _VisionAssistantScreenState extends State<VisionAssistantScreen> {
  final VisionService _visionService = VisionService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _questionController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  bool _isLoading = false;
  String _currentMode = 'ticket'; // 'ticket', 'pickup', 'ocr', 'describe'
  VisionResult? _result;
  String? _errorMessage;

  // Route Analysis & Pickup Notification State
  List<Map<String, dynamic>> _activeBookings = [];
  Map<String, dynamic>? _selectedBooking;
  String _selectedRouteName = 'TP. Hồ Chí Minh - Đà Lạt';
  String _selectedStartPoint = 'TP. Hồ Chí Minh';
  String _selectedEndPoint = 'Đà Lạt';

  final List<Map<String, String>> _presetRoutes = const [
    {
      'name': 'TP. Hồ Chí Minh - Đà Lạt',
      'start': 'TP. Hồ Chí Minh',
      'end': 'Đà Lạt',
    },
    {
      'name': 'TP. Hồ Chí Minh - Cư Jút',
      'start': 'TP. Hồ Chí Minh',
      'end': 'Cư Jút',
    },
    {
      'name': 'TP. Hồ Chí Minh - Vũng Tàu',
      'start': 'TP. Hồ Chí Minh',
      'end': 'Vũng Tàu',
    },
    {
      'name': 'Hà Nội - Sa Pa',
      'start': 'Hà Nội',
      'end': 'Sa Pa',
    },
    {
      'name': 'Đà Nẵng - Huế',
      'start': 'Đà Nẵng',
      'end': 'Huế',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkServerHealth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveBookings();
    });
  }

  Future<void> _loadActiveBookings() async {
    try {
      final bookingService = Provider.of<BookingService>(context, listen: false);
      final list = await bookingService.getActiveBookings();
      if (!mounted) return;
      if (list.isNotEmpty) {
        setState(() {
          _activeBookings = list;
          _selectedBooking = list.first;
          _selectedRouteName = _selectedBooking!['route_name'] ?? _selectedRouteName;
          _selectedStartPoint = _selectedBooking!['start_point'] ?? _selectedStartPoint;
          _selectedEndPoint = _selectedBooking!['end_point'] ?? _selectedEndPoint;
        });
      }
    } catch (e) {
      debugPrint('Không tải được active bookings: $e');
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  String _serverStatus = 'Đang kiểm tra...';
  bool _isServerHealthy = false;

  Future<void> _checkServerHealth() async {
    final health = await _visionService.checkHealth();
    if (!mounted) return;
    setState(() {
      if (health['status'] == 'healthy') {
        _isServerHealthy = true;
        final model = health['ollama']?['configured_model'] ?? 'AI Vision';
        _serverStatus = 'Sẵn sàng ($model)';
      } else {
        _isServerHealthy = false;
        _serverStatus = health['message'] ?? 'Máy chủ AI chưa kết nối';
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _result = null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn ảnh: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _processImage() async {
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc chụp ảnh trước')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      VisionResult res;
      final filename = _selectedImageName ?? 'image.jpg';
      final customPrompt = _questionController.text.trim();

      if (_currentMode == 'ticket') {
        res = await _visionService.analyzeImage(
          imageBytes: _selectedImageBytes!,
          filename: filename,
          type: 'ticket',
          prompt: customPrompt.isNotEmpty ? customPrompt : null,
        );
      } else if (_currentMode == 'pickup') {
        res = await _visionService.analyzeImage(
          imageBytes: _selectedImageBytes!,
          filename: filename,
          type: 'pickup_location',
          prompt: customPrompt.isNotEmpty ? customPrompt : null,
          routeName: _selectedRouteName,
          startPoint: _selectedStartPoint,
          endPoint: _selectedEndPoint,
        );
      }
      } else if (_currentMode == 'ocr') {
        res = await _visionService.extractText(
          imageBytes: _selectedImageBytes!,
          filename: filename,
        );
      } else {
        res = await _visionService.describeImage(
          imageBytes: _selectedImageBytes!,
          filename: filename,
          prompt: customPrompt.isNotEmpty ? customPrompt : null,
        );
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (res.success) {
          _result = res;
        } else {
          _errorMessage = res.error ?? 'Phân tích thất bại';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi xử lý: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF0B192C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Trợ lý AI Vision',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Chọn môi trường kết nối',
            onPressed: _showEnvironmentSelector,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isServerHealthy ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isServerHealthy ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isServerHealthy ? Icons.check_circle_outline : Icons.error_outline,
                    color: _isServerHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Server: $_serverStatus',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isServerHealthy ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _checkServerHealth,
                    child: const Icon(Icons.refresh, size: 18, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mode Selector
            const Text(
              'Chọn tác vụ AI',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildModeChip('ticket', 'Soát vé xe', Icons.confirmation_number_outlined),
                  const SizedBox(width: 8),
                  _buildModeChip('pickup', 'Nhận diện điểm đón', Icons.location_on_outlined),
                  const SizedBox(width: 8),
                  _buildModeChip('ocr', 'Đọc chữ (OCR)', Icons.text_fields_outlined),
                  const SizedBox(width: 8),
                  _buildModeChip('describe', 'Mô tả hình ảnh', Icons.image_search_outlined),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_currentMode == 'pickup') ...[
              _buildRouteSelectorCard(),
              const SizedBox(height: 16),
            ],

            // Image Preview / Placeholder
            Container(
              width: double.infinity,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImageBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedImageBytes = null;
                                  _result = null;
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, size: 54, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        const Text(
                          'Chụp hoặc tải ảnh vé xe, điểm đón',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Máy ảnh'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryDark,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Thư viện'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryDark,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            // Optional customer question input
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                hintText: _getHintForCurrentMode(),
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.help_outline, size: 20, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0B192C), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_isLoading || _selectedImageBytes == null) ? null : _processImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('AI đang phân tích ảnh...', style: TextStyle(fontSize: 15)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 20),
                          SizedBox(width: 8),
                          Text('Bắt đầu phân tích AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Results Section
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error, color: Color(0xFFDC2626), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(String mode, String label, IconData icon) {
    final isSelected = _currentMode == mode;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _currentMode = mode);
      },
      selectedColor: const Color(0xFF0B192C),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0B192C) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology, color: Color(0xFF0284C7), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Kết quả phân tích',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (r.executionTime != null)
                Text(
                  '${r.executionTime}s',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
          const Divider(height: 24),

          // QR Code verification banner if present
          if (r.qrDetected)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code, color: Color(0xFF2563EB), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Phát hiện mã QR trên vé',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nội dung mã: ${r.qrContent ?? ""}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                  ),
                  if (r.ticketVerification != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      r.ticketVerification!['message'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: r.ticketVerification!['is_verified'] == true
                            ? const Color(0xFF15803D)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Route Corridor Analysis banner if present
          if (r.routeAnalysis != null)
            _buildRouteAnalysisBanner(r),

          // Detailed analysis text (cleaned from markdown asterisks)
          Text(
            (r.resultText ?? 'Không có nội dung phản hồi')
                .replaceAll('**', '')
                .replaceAll('### ', '')
                .replaceAll('## ', ''),
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                if (r.resultText != null) {
                  final cleanText = r.resultText!
                      .replaceAll('**', '')
                      .replaceAll('### ', '')
                      .replaceAll('## ', '');
                  Clipboard.setData(ClipboardData(text: cleanText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép nội dung phân tích vào bộ nhớ tạm'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Sao chép kết quả', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHintForCurrentMode() {
    switch (_currentMode) {
      case 'ticket':
        return 'Đặt câu hỏi về vé (VD: Giờ xe chạy mấy giờ? Số ghế ở đâu?)...';
      case 'pickup':
        return 'Hỏi về điểm đón (VD: Chỗ này ở quận huyện nào? Đón xe ở đâu an toàn?)...';
      case 'ocr':
        return 'Yêu cầu thêm về văn bản cần đọc...';
      default:
        return 'Hỏi về ảnh (VD: Đây là địa điểm nào? Thuộc quận/thành phố nào?)...';
    }
  }

  void _showEnvironmentSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cấu hình kết nối Vision AI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn địa chỉ phù hợp với thiết bị bạn đang chạy app:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              _buildEnvTile(
                VisionEnvironment.lanDevice,
                'Mạng nội bộ LAN (${VisionConfig.lanUrl})',
                'Khuyên dùng cho iPhone thật cài IPA cùng Wi-Fi với PC',
                trailing: IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Color(0xFF0B192C)),
                  tooltip: 'Đổi IP máy chủ',
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditLanUrlDialog();
                  },
                ),
              ),
              _buildEnvTile(
                VisionEnvironment.production,
                'Cloudflare HTTPS Tunnel (Toàn cầu)',
                'Dùng cho điện thoại thật qua 4G/Internet ngoài',
              ),
              _buildEnvTile(
                VisionEnvironment.androidEmulator,
                'Android Emulator (10.0.2.2:5050)',
                'Dùng cho máy ảo Android Studio',
              ),
              _buildEnvTile(
                VisionEnvironment.local,
                'Localhost (127.0.0.1:5050)',
                'Dùng khi test trên Windows / Web',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditLanUrlDialog() {
    final controller = TextEditingController(text: VisionConfig.lanUrl);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Nhập IP Máy tính (LAN)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập địa chỉ IP Wi-Fi của máy tính đang chạy AI Vision (hoặc LM Studio):',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://10.12.20.125:5050',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lan),
                helperText: 'Cổng 5050 (Vision Service) hoặc 1234 (LM Studio)',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B192C),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                await VisionConfig.setCustomLanUrl(newUrl);
                await VisionConfig.setEnvironment(VisionEnvironment.lanDevice);
                if (mounted) {
                  _checkServerHealth();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã cập nhật máy chủ: ${VisionConfig.baseUrl}')),
                  );
                }
              }
            },
            child: const Text('Lưu & Kết nối'),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvTile(VisionEnvironment env, String title, String subtitle, {Widget? trailing}) {
    final isSelected = VisionConfig.currentEnvironment == env;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? const Color(0xFF0B192C) : const Color(0xFF94A3B8),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      trailing: trailing,
      onTap: () {
        VisionConfig.setEnvironment(env);
        Navigator.pop(context);
        _checkServerHealth();
      },
    );
  }

  Widget _buildRouteSelectorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_bus, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lộ trình tuyến xe bạn đón',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (_activeBookings.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_activeBookings.length} vé hoạt động',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_activeBookings.isNotEmpty) ...[
            const Text(
              'Chọn vé đang chạy của bạn:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedBooking,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              items: _activeBookings.map((b) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: b,
                  child: Text(
                    '${b['ticket_code']} • ${b['route_name']} (Ghế ${b['seat_number']})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedBooking = val;
                    _selectedRouteName = val['route_name'] ?? _selectedRouteName;
                    _selectedStartPoint = val['start_point'] ?? _selectedStartPoint;
                    _selectedEndPoint = val['end_point'] ?? _selectedEndPoint;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            'Hoặc kiểm tra theo lộ trình phổ biến:',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _presetRoutes.map((r) {
              final isSelected = _selectedRouteName == r['name'] && _selectedBooking == null;
              return ChoiceChip(
                label: Text(r['name']!),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedBooking = null;
                      _selectedRouteName = r['name']!;
                      _selectedStartPoint = r['start']!;
                      _selectedEndPoint = r['end']!;
                    });
                  }
                },
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteAnalysisBanner(VisionResult r) {
    final isOnRoute = r.isOnRoute == true;
    final primaryColor = isOnRoute ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bgColor = isOnRoute ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final borderColor = isOnRoute ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnRoute ? Icons.verified : Icons.warning_amber_rounded,
                color: primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnRoute
                      ? 'ĐIỂM ĐÓN NẰM TRÊN LỘ TRÌNH XE'
                      : 'ĐIỂM ĐÓN NGOÀI LỘ TRÌNH',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (r.routeName != null && r.routeName!.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.alt_route, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tuyến xe: ${r.routeName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          if (r.matchedLandmark != null && r.matchedLandmark!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Địa điểm nhận diện: ${r.matchedLandmark}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (r.statusMessage != null && r.statusMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.statusMessage!,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isOnRoute ? const Color(0xFF15803D) : const Color(0xFF991B1B),
              ),
            ),
          ],
          if (r.pickupRecommendation != null && r.pickupRecommendation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Khuyến nghị đón xe: ${r.pickupRecommendation!}',
                      style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isOnRoute) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _showNotifyDriverSheet(r),
                icon: const Icon(Icons.campaign, size: 20),
                label: const Text(
                  'Báo cho nhà xe & tài xế đón tại đây',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showNotifyDriverSheet(VisionResult r) {
    final defaultPickup = r.pickupPointSuggested ??
        r.matchedLandmark ??
        "Điểm đón xác thực AI";
    final defaultPhone = _selectedBooking?['passenger_phone'] ?? '';
    final defaultTicket = _selectedBooking?['ticket_code'] ?? '';
    final defaultName = _selectedBooking?['passenger_name'] ?? '';

    final pickupCtrl = TextEditingController(text: defaultPickup);
    final phoneCtrl = TextEditingController(text: defaultPhone);
    final ticketCtrl = TextEditingController(text: defaultTicket);
    final nameCtrl = TextEditingController(text: defaultName);
    final noteCtrl = TextEditingController(text: 'Đang đứng chờ xe tại đây.');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.campaign, color: Color(0xFF16A34A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Báo điểm đón cho nhà xe',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Tài xế & trung tâm điều hành sẽ nhận được thông báo ngay lập tức',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Điểm đón thực tế (AI xác nhận):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: pickupCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on, color: Color(0xFF16A34A), size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mã vé (nếu có):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: ticketCtrl,
                              decoration: InputDecoration(
                                hintText: 'VD: VX1023',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Số điện thoại:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '090xxxxxxx',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Ghi chú cho bác tài:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      hintText: 'VD: Em mặc áo xanh đứng trước sảnh...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final pickupVal = pickupCtrl.text.trim();
                              if (pickupVal.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vui lòng nhập vị trí điểm đón')),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);

                              final bookingService = Provider.of<BookingService>(context, listen: false);
                              bool ok = false;
                              if (_selectedBooking != null && _selectedBooking!['id'] != null) {
                                ok = await bookingService.notifyPickupLocation(
                                  bookingId: _selectedBooking!['id'],
                                  pickupLocation: pickupVal,
                                  landmarkName: r.matchedLandmark,
                                  note: noteCtrl.text.trim(),
                                );
                              } else {
                                final res = await bookingService.notifyPickupPublic(
                                  pickupLocation: pickupVal,
                                  ticketCode: ticketCtrl.text.trim(),
                                  passengerPhone: phoneCtrl.text.trim(),
                                  passengerName: nameCtrl.text.trim(),
                                  routeName: r.routeName ?? _selectedRouteName,
                                  landmarkName: r.matchedLandmark,
                                  note: noteCtrl.text.trim(),
                                );
                                ok = res['success'] == true;
                              }

                              if (!context.mounted) return;
                              Navigator.pop(ctx);

                              showDialog(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Row(
                                    children: [
                                      Icon(
                                        ok ? Icons.check_circle : Icons.info_outline,
                                        color: ok ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(ok ? 'Báo nhà xe thành công!' : 'Đã gửi thông báo'),
                                    ],
                                  ),
                                  content: Text(
                                    ok
                                        ? 'Tài xế và ban điều hành tuyến ${r.routeName ?? _selectedRouteName} đã nhận được vị trí: "$pickupVal". Xe sẽ lưu ý đón bạn tại đây!'
                                        : 'Thông tin điểm đón đã được chuyển tiếp đến hệ thống điều hành xe khách.',
                                    style: const TextStyle(fontSize: 14, height: 1.5),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx),
                                      child: const Text('Đồng ý', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Gửi thông báo đón xe ngay',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
