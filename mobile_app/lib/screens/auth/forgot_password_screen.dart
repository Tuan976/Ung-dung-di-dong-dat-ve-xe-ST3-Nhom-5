import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/shared_components.dart';

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
            content: Text('Đặt lại mật khẩu thành công! Hãy đăng nhập bằng mật khẩu mới.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_step == 2) {
              setState(() { _step = 1; _error = null; _message = null; });
            } else {
              context.pop();
            }
          },
        ),
        title: const Text('Quên mật khẩu'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step Indicator
                    Row(
                      children: [
                        _StepDot(active: true, label: '1', done: _step == 2),
                        Expanded(
                          child: Container(
                            height: 2.5,
                            color: _step == 2 ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        _StepDot(active: _step == 2, label: '2', done: false),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nhập email',
                          style: TextStyle(
                            fontSize: 12,
                            color: _step >= 1 ? AppColors.primary : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Đặt lại mật khẩu',
                          style: TextStyle(
                            fontSize: 12,
                            color: _step == 2 ? AppColors.primary : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),

                    if (_step == 1) ...[
                      Text('Khôi phục mật khẩu', style: AppTextStyles.h2.copyWith(fontSize: 20)),
                      const SizedBox(height: 6),
                      Text(
                        'Nhập email bạn đã đăng ký để nhận mã bảo mật xác nhận.',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 20),

                      Text('Địa chỉ Email', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'example@domain.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                        ),
                      ),
                    ] else ...[
                      Text('Thiết lập mật khẩu mới', style: AppTextStyles.h2.copyWith(fontSize: 20)),
                      const SizedBox(height: 6),
                      Text(
                        'Kiểm tra hộp thư đến (và mục spam) để lấy mã xác nhận.',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 18),

                      if (_message != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.successBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mark_email_read_rounded, size: 18, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_message!, style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),

                      Text('Mã xác nhận (6 ký tự)', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Nhập mã 6 ký tự',
                          prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Mật khẩu mới', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          hintText: 'Tối thiểu 6 ký tự',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Xác nhận mật khẩu mới', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Nhập lại mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.errorBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    PrimaryButton(
                      text: _step == 1 ? 'Gửi mã xác nhận' : 'Đặt lại mật khẩu',
                      isLoading: _isLoading,
                      onPressed: _step == 1 ? _sendCode : _resetPassword,
                      icon: _step == 1 ? Icons.send_rounded : Icons.check_circle_outline_rounded,
                    ),

                    if (_step == 2) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _sendCode,
                          child: const Text('Gửi lại mã xác nhận', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
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
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: done ? AppColors.success : (active ? AppColors.primary : AppColors.border),
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
