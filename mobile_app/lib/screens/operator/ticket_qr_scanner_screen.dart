import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/company_service.dart';

class TicketQrScannerScreen extends StatefulWidget {
  const TicketQrScannerScreen({super.key});

  @override
  State<TicketQrScannerScreen> createState() => _TicketQrScannerScreenState();
}

class _TicketQrScannerScreenState extends State<TicketQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isFlashOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue != null && rawValue.trim().isNotEmpty) {
      _processScannedCode(rawValue.trim());
    }
  }

  Future<void> _processScannedCode(String rawCode) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    // Sanitize ticket code
    String code = rawCode.trim().toUpperCase();
    if (code.contains('CODE=')) {
      code = code.split('CODE=').last.split('&').first.trim();
    } else if (code.contains(':')) {
      code = code.split(':').last.trim();
    }

    try {
      final companyService = context.read<CompanyService>();
      final result = await companyService.scanTicketCode(code);

      if (!mounted) return;
      _showScanResultDialog(result, code);
    } catch (e) {
      if (!mounted) return;
      _showScanResultDialog({
        'success': false,
        'message': 'Lỗi kết nối khi soát vé: $e',
      }, code);
    }
  }

  void _showScanResultDialog(Map<String, dynamic> result, String scannedCode) {
    final success = result['success'] == true;
    final alreadyBoarded = result['already_boarded'] == true;
    final ticket = result['ticket'] as Map<String, dynamic>?;
    final message = result['message']?.toString() ?? '';

    Color headerBg;
    Color headerText;
    IconData headerIcon;
    String statusTitle;

    if (success && !alreadyBoarded) {
      headerBg = const Color(0xFFE9F8F0);
      headerText = const Color(0xFF16A36A);
      headerIcon = Icons.check_circle_rounded;
      statusTitle = 'SOÁT VÉ THÀNH CÔNG';
    } else if (success && alreadyBoarded) {
      headerBg = const Color(0xFFFFF5E5);
      headerText = const Color(0xFFE99A22);
      headerIcon = Icons.info_rounded;
      statusTitle = 'VÉ ĐÃ CHECK-IN TRƯỚC ĐÓ';
    } else {
      headerBg = const Color(0xFFFFF5F3);
      headerText = const Color(0xFFDC2626);
      headerIcon = Icons.cancel_rounded;
      statusTitle = 'VÉ KHÔNG HỢP LỆ';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: headerText.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(headerIcon, color: headerText, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: TextStyle(
                              color: headerText,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            style: TextStyle(
                              color: headerText.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ticket Details Card
              if (ticket != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: Column(
                    children: [
                      // Passenger & Seat Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket['passenger_name'] ?? 'Khách hàng',
                                  style: const TextStyle(
                                    color: Color(0xFF263244),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'SĐT: ${ticket['passenger_phone'] ?? 'Chưa có'}',
                                  style: const TextStyle(
                                    color: Color(0xFF778397),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0E6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF26A21)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'SỐ GHẾ',
                                  style: TextStyle(
                                    color: Color(0xFFE65B16),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  ticket['seat_number'] ?? 'N/A',
                                  style: const TextStyle(
                                    color: Color(0xFFF26A21),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFE7EAF0)),
                      ),

                      // Route & Bus Plate
                      _buildInfoRow('Tuyến xe:', ticket['route'] ?? 'N/A', Icons.route),
                      const SizedBox(height: 8),
                      _buildInfoRow('Biển số xe:', ticket['license_plate'] ?? 'Chưa gán', Icons.directions_bus),
                      const SizedBox(height: 8),
                      _buildInfoRow('Khởi hành:', ticket['departure_time'] ?? 'N/A', Icons.access_time),
                      const SizedBox(height: 8),
                      _buildInfoRow('Điểm đón:', ticket['pickup_point'] ?? 'Tại bến xe', Icons.location_on),
                      const SizedBox(height: 8),
                      _buildInfoRow('Mã vé:', ticket['ticket_code'] ?? scannedCode, Icons.qr_code_2),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                // Ticket Not Found Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code, color: Color(0xFF778397)),
                      const SizedBox(width: 10),
                      Text(
                        'Mã đã quét: $scannedCode',
                        style: const TextStyle(
                          color: Color(0xFF263244),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE7EAF0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          color: Color(0xFF778397),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF26A21),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Quét vé tiếp theo',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
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
    ).whenComplete(() {
      // Re-enable scanning after sheet closes
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF778397)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF778397),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF263244),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.keyboard, color: Color(0xFFF26A21)),
              SizedBox(width: 8),
              Text(
                'Nhập mã vé thủ công',
                style: TextStyle(
                  color: Color(0xFF263244),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Ví dụ: HT12345678',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE7EAF0)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF778397))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF26A21),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final code = textController.text.trim();
                if (code.isNotEmpty) {
                  Navigator.pop(ctx);
                  _processScannedCode(code);
                }
              },
              child: const Text('Kiểm tra & Soát vé', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263244)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soát Vé QR Bằng Camera',
              style: TextStyle(
                color: Color(0xFF263244),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Hướng camera về mã QR vé của khách hàng',
              style: TextStyle(color: Color(0xFF778397), fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bật/tắt đèn Flash',
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? const Color(0xFFF26A21) : const Color(0xFF778397),
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
          IconButton(
            tooltip: 'Đổi camera',
            icon: const Icon(Icons.flip_camera_ios, color: Color(0xFF778397)),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Live Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off, color: Colors.white70, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Không thể truy cập cảm biến camera: ${error.errorCode}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF26A21),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.keyboard),
                        label: const Text('Nhập mã vé thủ công'),
                        onPressed: _showManualInputDialog,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Scanner Target Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: const Color(0xFFF26A21),
                borderRadius: 16,
                borderLength: 36,
                borderWidth: 5,
                cutOutSize: MediaQuery.of(context).size.width * 0.72,
              ),
            ),
          ),

          // 3. Instruction Top Overlay
          Positioned(
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Color(0xFFF26A21), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Đưa mã QR vào khung ngắm để soát vé',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Controls: Manual Input Button
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF263244),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.keyboard, color: Color(0xFFF26A21)),
              label: const Text(
                'Nhập mã vé thủ công (HT...)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              onPressed: _showManualInputDialog,
            ),
          ),

          // 5. Loading Overlay when verifying ticket
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: const Center(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFF26A21)),
                        SizedBox(height: 16),
                        Text(
                          'Đang xác thực vé...',
                          style: TextStyle(
                            color: Color(0xFF263244),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom Shape for QR Scanner Overlay with Cutout
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = const Color(0xFFF26A21),
    this.borderWidth = 4.0,
    this.overlayColor = const Color(0x88000000),
    this.borderRadius = 12,
    this.borderLength = 32,
    required this.cutOutSize,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutLeft = (width - cutOutSize) / 2;
    final cutOutTop = (height - cutOutSize) / 2;
    final cutOutRect = Rect.fromLTWH(cutOutLeft, cutOutTop, cutOutSize, cutOutSize);

    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutLeft = (width - cutOutSize) / 2;
    final cutOutTop = (height - cutOutSize) / 2;
    final r = borderRadius;
    final l = borderLength;

    final paintOverlay = Paint()..color = overlayColor;
    final outerPath = getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(outerPath, paintOverlay);

    final paintBorder = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final cutOutRect = Rect.fromLTWH(cutOutLeft, cutOutTop, cutOutSize, cutOutSize);

    // Draw 4 corners
    // Top-Left
    final pathTL = Path()
      ..moveTo(cutOutRect.left, cutOutRect.top + l)
      ..lineTo(cutOutRect.left, cutOutRect.top + r)
      ..arcToPoint(Offset(cutOutRect.left + r, cutOutRect.top), radius: Radius.circular(r))
      ..lineTo(cutOutRect.left + l, cutOutRect.top);
    canvas.drawPath(pathTL, paintBorder);

    // Top-Right
    final pathTR = Path()
      ..moveTo(cutOutRect.right - l, cutOutRect.top)
      ..lineTo(cutOutRect.right - r, cutOutRect.top)
      ..arcToPoint(Offset(cutOutRect.right, cutOutRect.top + r), radius: Radius.circular(r))
      ..lineTo(cutOutRect.right, cutOutRect.top + l);
    canvas.drawPath(pathTR, paintBorder);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(cutOutRect.left, cutOutRect.bottom - l)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - r)
      ..arcToPoint(Offset(cutOutRect.left + r, cutOutRect.bottom), radius: Radius.circular(r))
      ..lineTo(cutOutRect.left + l, cutOutRect.bottom);
    canvas.drawPath(pathBL, paintBorder);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(cutOutRect.right - l, cutOutRect.bottom)
      ..lineTo(cutOutRect.right - r, cutOutRect.bottom)
      ..arcToPoint(Offset(cutOutRect.right, cutOutRect.bottom - r), radius: Radius.circular(r))
      ..lineTo(cutOutRect.right, cutOutRect.bottom - l);
    canvas.drawPath(pathBR, paintBorder);
  }

  @override
  ShapeBorder scale(double t) => this;
}
