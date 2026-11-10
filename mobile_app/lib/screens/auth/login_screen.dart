import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/shared_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String _selectedRole = 'passenger'; // 'passenger' or 'company'
  bool _isGoogleLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final success = await authService.login(
      _phoneController.text.trim(),
      _passwordController.text,
      role: _selectedRole,
    );

    if (!mounted) return;

    if (success) {
      if (authService.isOperator || _selectedRole == 'company') {
        context.go('/operator');
      } else {
        context.go('/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.error ?? 'Đăng nhập thất bại'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      final googleSignIn = GoogleSignIn(
        clientId: '895279102171-osavv8pcm88dhmrai7moecpkpjfpi171.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': account.email,
          'name': account.displayName ?? account.email,
          'google_id': account.id,
          'photo': account.photoUrl ?? '',
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final authService = context.read<AuthService>();
        await authService.loginWithToken(
          data['data']['access_token'],
          data['data']['user'],
        );
        if (mounted) context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Đăng nhập Google thất bại'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Header Brand Logo
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.directions_bus_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'TRIP',
                              style: AppTextStyles.h2.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.secondary,
                              ),
                            ),
                            Text(
                              'LY',
                              style: AppTextStyles.h2.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Hệ thống vé xe khách cao cấp',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main Content Card
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
                      // Role Switcher Tabs (Hành khách vs Đối tác Nhà xe)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRole = 'passenger'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'passenger' ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _selectedRole == 'passenger'
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 16,
                                        color: _selectedRole == 'passenger' ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Hành khách',
                                        style: TextStyle(
                                          color: _selectedRole == 'passenger' ? AppColors.primary : AppColors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRole = 'company'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'company' ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _selectedRole == 'company'
                                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.business_rounded,
                                        size: 16,
                                        color: _selectedRole == 'company' ? Colors.white : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Đối tác Nhà xe',
                                        style: TextStyle(
                                          color: _selectedRole == 'company' ? Colors.white : AppColors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        _selectedRole == 'company' ? 'Cổng Nhà Xe & Vận Hành' : 'Chào mừng bạn trở lại',
                        style: AppTextStyles.h2.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedRole == 'company'
                            ? 'Dành cho nhà xe, nhân viên điều hành, phụ xe và tài xế.'
                            : 'Đăng nhập để đặt vé xe và quản lý chuyến đi dễ dàng.',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 24),

                      // Phone or Email Field
                      Text(
                        'Số điện thoại hoặc Email',
                        style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Vui lòng nhập số điện thoại hoặc email' : null,
                        decoration: const InputDecoration(
                          hintText: 'VD: 0912345678 hoặc email@domain.com',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Password Field
                      Text(
                        'Mật khẩu',
                        style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                        decoration: InputDecoration(
                          hintText: 'Nhập mật khẩu của bạn',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot_password'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Quên mật khẩu?',
                            style: AppTextStyles.captionBold.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login Button
                      PrimaryButton(
                        text: _selectedRole == 'company' ? 'Đăng nhập Cổng Nhà Xe' : 'Đăng nhập',
                        isLoading: authService.isLoading,
                        onPressed: _login,
                        icon: Icons.login_rounded,
                      ),
                      const SizedBox(height: 16),

                      // Register link (for passenger)
                      if (_selectedRole == 'passenger')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Chưa có tài khoản? ', style: AppTextStyles.bodyMedium),
                            GestureDetector(
                              onTap: () => context.push('/register'),
                              child: Text(
                                'Đăng ký ngay',
                                style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                              ),
                            ),
                          ],
                        )
                      else
                        Center(
                          child: Text(
                            'Liên hệ quản trị viên hãng xe để được cấp tài khoản.',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ),

                      if (_selectedRole == 'passenger') ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Hoặc đăng nhập bằng', style: AppTextStyles.tiny),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Social Button
                        OutlinedButton(
                          onPressed: (_isGoogleLoading || authService.isLoading) ? null : _googleLogin,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CustomPaint(painter: _GoogleLogoPainter()),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Tiếp tục với Google',
                                      style: AppTextStyles.buttonSecondary.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Google "G" logo painter with clean colors
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.5708, 1.5708, true, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 3.1416, 1.5708, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 1.5708, 1.5708, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -3.1416, 1.5708, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.55, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTRB(cx, cy - r * 0.15, cx + r, cy + r * 0.15), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
