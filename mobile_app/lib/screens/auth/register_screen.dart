import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

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
        const SnackBar(content: Text('Vui lòng đồng ý với điều khoản sử dụng'), backgroundColor: Colors.orange),
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
          content: Text('Đăng ký thành công! Hãy đăng nhập.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.error ?? 'Đăng ký thất bại'),
          backgroundColor: Colors.red,
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0B192C), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with logo & back button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(left: 16, right: 24, top: 8, bottom: 8),
                        child: Row(
                          spacing: 8,
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF0F172A)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: ShapeDecoration(
                                color: const Color(0xFF0B192C),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Center(
                                child: Icon(Icons.directions_bus, color: Colors.white, size: 20),
                              ),
                            ),
                            const Text(
                              'VéXe',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 22,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form content
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 20,
                          children: [
                            // Title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 6,
                              children: const [
                                Text(
                                  'Tạo tài khoản',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 28,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Đăng ký nhanh chóng để khám phá các chuyến đi.',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 15,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),

                            // Full name
                            _FormField(
                              label: 'Họ và tên',
                              child: TextFormField(
                                controller: _nameController,
                                decoration: _inputDecoration('Nhập đầy đủ họ và tên'),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập họ tên' : null,
                              ),
                            ),

                            // Phone
                            _FormField(
                              label: 'Số điện thoại',
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration('Nhập số điện thoại').copyWith(
                                  prefixText: '+84  ',
                                  prefixStyle: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập số điện thoại' : null,
                              ),
                            ),

                            // Email
                            _FormField(
                              label: 'Email',
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration('Nhập địa chỉ email'),
                                validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập email' : null,
                              ),
                            ),

                            // Password
                            _FormField(
                              label: 'Mật khẩu',
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: _inputDecoration('Nhập mật khẩu').copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                                  if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                                  return null;
                                },
                              ),
                            ),

                            // Confirm password
                            _FormField(
                              label: 'Xác nhận mật khẩu',
                              child: TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                decoration: _inputDecoration('Nhập lại mật khẩu').copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                                  if (v != _passwordController.text) return 'Mật khẩu không khớp';
                                  return null;
                                },
                              ),
                            ),

                            // Terms checkbox
                            GestureDetector(
                              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                              child: Row(
                                spacing: 10,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: ShapeDecoration(
                                      color: _agreedToTerms ? const Color(0xFF0B192C) : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                          color: _agreedToTerms ? const Color(0xFF0B192C) : const Color(0xFFE2E8F0),
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: _agreedToTerms
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: const TextSpan(
                                        style: TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 14,
                                          fontFamily: 'Inter',
                                        ),
                                        children: [
                                          TextSpan(text: 'Tôi đồng ý với '),
                                          TextSpan(
                                            text: 'Điều khoản sử dụng',
                                            style: TextStyle(
                                              color: Color(0xFF00639B),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Register button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: authService.isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0B192C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  elevation: 0,
                                ),
                                child: authService.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                      )
                                    : const Text(
                                        'Đăng ký',
                                        style: TextStyle(fontSize: 15, fontFamily: 'Inter', fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),

                            // Already have account
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 6,
                              children: [
                                const Text(
                                  'Đã có tài khoản?',
                                  style: TextStyle(color: Color(0xFF475569), fontSize: 14, fontFamily: 'Inter'),
                                ),
                                GestureDetector(
                                  onTap: () => context.pop(),
                                  child: const Text(
                                    'Đăng nhập',
                                    style: TextStyle(
                                      color: Color(0xFF00639B),
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom home indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Container(
                    width: 140,
                    height: 5,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF94A3B8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        child,
      ],
    );
  }
}
