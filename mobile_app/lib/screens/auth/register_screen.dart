import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/shared_components.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với điều khoản sử dụng'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final success = await authService.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký thành công! Hãy đăng nhập để bắt đầu.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.error ?? 'Đăng ký thất bại'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TRIPLY',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text('Tạo tài khoản mới', style: AppTextStyles.h2.copyWith(fontSize: 22)),
                      const SizedBox(height: 6),
                      Text(
                        'Đăng ký tài khoản để đặt vé và nhận ưu đãi độc quyền.',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      Text('Họ và tên', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                        decoration: const InputDecoration(
                          hintText: 'VD: Nguyễn Văn A',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      Text('Số điện thoại', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập số điện thoại' : null,
                        decoration: const InputDecoration(
                          hintText: 'VD: 0912345678',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      Text('Email', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập email' : null,
                        decoration: const InputDecoration(
                          hintText: 'VD: yourname@email.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      Text('Mật khẩu', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                          if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Tối thiểu 6 ký tự',
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
                      const SizedBox(height: 16),

                      // Confirm Password
                      Text('Xác nhận mật khẩu', style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                          if (v != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Nhập lại mật khẩu',
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
                      const SizedBox(height: 18),

                      // Terms Agreement
                      GestureDetector(
                        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  children: [
                                    const TextSpan(text: 'Tôi đồng ý với '),
                                    TextSpan(
                                      text: 'Điều khoản sử dụng & Chính sách bảo mật',
                                      style: AppTextStyles.captionBold.copyWith(color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Register CTA
                      PrimaryButton(
                        text: 'Tạo tài khoản',
                        isLoading: authService.isLoading,
                        onPressed: _register,
                        icon: Icons.person_add_rounded,
                      ),
                      const SizedBox(height: 18),

                      // Login redirect
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Đã có tài khoản? ', style: AppTextStyles.bodyMedium),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(
                              'Đăng nhập',
                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
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
