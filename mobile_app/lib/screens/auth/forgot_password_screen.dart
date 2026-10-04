import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../core/config/api_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step: 1 = enter email, 2 = enter code + new password
  int _step = 1;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Vui lòng nhập email');
      return;
    }

    setState(() { _isLoading = true; _error = null; _message = null; });

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          _step = 2;
          _message = data['message'] ?? 'Mã xác nhận đã được gửi về email của bạn.';
        });
      } else {
        setState(() => _error = data['message'] ?? 'Có lỗi xảy ra');
      }
    } catch (_) {
      setState(() => _error = 'Không thể kết nối đến máy chủ');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;

    if (code.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã xác nhận');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _error = 'Mật khẩu tối thiểu 6 ký tự');
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': code, 'password': newPw}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt lại mật khẩu thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      } else {
        setState(() => _error = data['message'] ?? 'Mã không hợp lệ hoặc đã hết hạn');
      }
    } catch (_) {
      setState(() => _error = 'Không thể kết nối đến máy chủ');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0B192C), width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _step == 2
                          ? setState(() { _step = 1; _error = null; _message = null; })
                          : context.pop(),
                      child: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF0F172A)),
                    ),
                    const Expanded(
                      child: Text('Quên mật khẩu',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 28),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Icon
                    Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(Icons.lock_reset, size: 40, color: Color(0xFF0B192C)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Step indicator
                    Row(
                      children: [
                        _StepDot(active: true, label: '1', done: _step == 2),
                        Expanded(child: Container(height: 2, color: _step == 2 ? const Color(0xFF0B192C) : const Color(0xFFE2E8F0))),
                        _StepDot(active: _step == 2, label: '2', done: false),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Nhập email', style: TextStyle(fontSize: 11, color: _step >= 1 ? const Color(0xFF0B192C) : const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                        Text('Đặt mật khẩu mới', style: TextStyle(fontSize: 11, color: _step == 2 ? const Color(0xFF0B192C) : const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                      ],
                    ),

                    const SizedBox(height: 32),

                    if (_step == 1) ...[
                      const Text('Nhập email của bạn',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Chúng tôi sẽ gửi mã xác nhận về email bạn đã đăng ký.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                      const SizedBox(height: 24),
                      const Text('Email', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco('example@gmail.com', Icons.email_outlined),
                      ),
                    ] else ...[
                      const Text('Đặt lại mật khẩu',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),

                      // Success message
                      if (_message != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mark_email_read, size: 18, color: Color(0xFF16A34A)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_message!, style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13))),
                            ],
                          ),
                        ),

                      const Text('Mã xác nhận (6 ký tự)',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _codeController,
                        decoration: _inputDeco('Nhập mã từ email', Icons.vpn_key_outlined),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Mật khẩu mới',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: _inputDeco('Tối thiểu 6 ký tự', Icons.lock_outlined).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF94A3B8), size: 20),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Xác nhận mật khẩu',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: _inputDeco('Nhập lại mật khẩu', Icons.lock_outlined).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF94A3B8), size: 20),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),
                    ],

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : (_step == 1 ? _sendCode : _resetPassword),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B192C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                            : Text(
                                _step == 1 ? 'Gửi mã xác nhận' : 'Đặt lại mật khẩu',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),

                    if (_step == 2) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: _isLoading ? null : _sendCode,
                          child: const Text('Gửi lại mã',
                              style: TextStyle(color: Color(0xFF00639B), fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  final String label;

  const _StepDot({required this.active, required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: active || done ? const Color(0xFF0B192C) : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(label, style: TextStyle(color: active ? Colors.white : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
