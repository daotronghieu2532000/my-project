import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (result['success'] == true) {
          // Đăng nhập thành công
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đăng nhập thành công'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Quay lại màn hình trước
          Navigator.of(context).pop(true);
        } else {
          // Đăng nhập thất bại
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đăng nhập thất bại'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Đóng',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Đóng',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image - Ảnh 300x658px phù hợp với tỉ lệ màn hình điện thoại
          Image.asset(
            'lib/src/core/assets/images/logo_socdo.png',
            fit: BoxFit.cover, // Fill toàn màn hình, không có khoảng trắng
            alignment: Alignment.center, // Căn giữa - tỉ lệ 1:2.19 gần khớp với màn hình
            filterQuality: FilterQuality.high, // Chất lượng cao để ảnh nét
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF8F9FA),
                      Color(0xFFE9ECEF),
                    ],
                  ),
                ),
              );
            },
          ),
          // Subtle overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.8),
                ],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Modern AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF495057)),
                          iconSize: 20,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF212529),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          
                          // Compact Logo/Icon
                          Center(
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(60),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 32,
                                color: const Color(0xFFDC3545),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Modern Typography
                          Text(
                            'Chào mừng bạn quay lại!',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF212529),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'Đăng nhập để tiếp tục mua sắm',
                            style: TextStyle(
                              fontSize: 15,
                              color: const Color(0xFF6C757D),
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Modern Form Container
                          Container(
                            padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Compact Username field
                                TextFormField(
                                  controller: _usernameController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF212529),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Số điện thoại',
                                    hintText: 'Nhập số điện thoại',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFFADB5BD),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    labelStyle: TextStyle(
                                      color: const Color(0xFF6C757D),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.phone_rounded,
                                      color: const Color(0xFF6C757D),
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.9),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Vui lòng nhập số điện thoại';
                                    }
                                    if (value.trim().length < 10) {
                                      return 'Số điện thoại phải có ít nhất 10 số';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Compact Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF212529),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Mật khẩu',
                                    hintText: 'Nhập mật khẩu',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFFADB5BD),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    labelStyle: TextStyle(
                                      color: const Color(0xFF6C757D),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_rounded,
                                      color: const Color(0xFF6C757D),
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword 
                                          ? Icons.visibility_rounded 
                                          : Icons.visibility_off_rounded,
                                        color: const Color(0xFF6C757D),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Vui lòng nhập mật khẩu';
                                    }
                                    if (value.length < 6) {
                                      return 'Mật khẩu phải có ít nhất 6 ký tự';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Modern Login button
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFDC3545),
                                        Color(0xFFC82333),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFDC3545).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Đăng nhập',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Modern Register link
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Chưa có tài khoản? ',
                                        style: TextStyle(
                                          color: const Color(0xFF6C757D),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const RegisterScreen(),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'Đăng ký ngay',
                                          style: TextStyle(
                                            color: const Color(0xFFDC3545),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                            decorationColor: const Color(0xFFDC3545),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Modern Forgot password
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE9ECEF),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Quên mật khẩu?',
                                  style: TextStyle(
                                    color: const Color(0xFFDC3545),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
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
        ],
      ),
    );
  }
}