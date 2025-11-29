import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

enum OTPMethod {
  call,   // Cuộc gọi Stringee
  sms,    // SMS eSMS
  zns,    // Zalo ZNS
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _rePasswordController = TextEditingController();
  
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _otpSent = false;
  bool _obscureNewPassword = true;
  bool _obscureRePassword = true;
  int _countdown = 0;
  OTPMethod _selectedMethod = OTPMethod.sms; // Mặc định là SMS
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _rePasswordController.dispose();
    super.dispose();
  }
  
  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _countdown--;
        });
        return _countdown > 0;
      }
      return false;
    });
  }
  
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      late Map<String, dynamic> result;
      
      // Gọi API tương ứng với phương thức được chọn
      switch (_selectedMethod) {
        case OTPMethod.call:
          result = await _authService.forgotPasswordStringeeCall(_phoneController.text.trim());
          break;
        case OTPMethod.sms:
          result = await _authService.forgotPasswordSMS(_phoneController.text.trim());
          break;
        case OTPMethod.zns:
          result = await _authService.forgotPasswordZNS(_phoneController.text.trim());
          break;
      }
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _otpSent = true;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Mã OTP đã được gửi'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gửi OTP thất bại'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
  
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _authService.verifyOTPAndResetPassword(
        phoneNumber: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
        rePassword: _rePasswordController.text,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đổi mật khẩu thành công'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Quay về màn hình login sau 2 giây
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đổi mật khẩu thất bại'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
  
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    final phone = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length != 10 || !phone.startsWith('0')) {
      return 'Số điện thoại phải có 10 chữ số và bắt đầu bằng 0';
    }
    return null;
  }
  
  String? _validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mã OTP';
    }
    if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Mã OTP phải là 6 chữ số';
    }
    return null;
  }
  
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 chữ hoa';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 chữ thường';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 chữ số';
    }
    // Kiểm tra ký tự đặc biệt - tránh dấu nháy đơn trong raw string
    final specialChars = r'!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?';
    final specialCharPattern = RegExp('[$specialChars]');
    if (!specialCharPattern.hasMatch(value)) {
      return 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt';
    }
    return null;
  }
  
  String? _validateRePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu';
    }
    if (value != _newPasswordController.text) {
      return 'Mật khẩu xác nhận không khớp';
    }
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF212529)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Quên mật khẩu',
          style: TextStyle(
            color: Color(0xFF212529),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
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
          ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 40,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'Khôi phục mật khẩu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212529),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      _otpSent 
                        ? 'Nhập mã OTP và mật khẩu mới'
                        : 'Nhập số điện thoại để nhận mã OTP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Phương thức nhận OTP
                    if (!_otpSent) ...[
                      const Text(
                        'Chọn phương thức nhận OTP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212529),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // OTP Method Selection
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<OTPMethod>(
                              value: OTPMethod.call,
                              groupValue: _selectedMethod,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMethod = value!;
                                });
                              },
                              title: const Row(
                                children: [
                                  Icon(Icons.phone_in_talk_rounded, color: Color(0xFF28A745), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Cuộc gọi (Stringee)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: const Text(
                                'Nhận mã OTP qua cuộc gọi thoại',
                                style: TextStyle(fontSize: 12),
                              ),
                              activeColor: const Color(0xFFDC3545),
                            ),
                            Divider(height: 1, color: Colors.grey[300]),
                            RadioListTile<OTPMethod>(
                              value: OTPMethod.sms,
                              groupValue: _selectedMethod,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMethod = value!;
                                });
                              },
                              title: const Row(
                                children: [
                                  Icon(Icons.sms_rounded, color: Color(0xFF007BFF), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tin nhắn SMS (eSMS)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: const Text(
                                'Nhận mã OTP qua tin nhắn SMS',
                                style: TextStyle(fontSize: 12),
                              ),
                              activeColor: const Color(0xFFDC3545),
                            ),
                            Divider(height: 1, color: Colors.grey[300]),
                            RadioListTile<OTPMethod>(
                              value: OTPMethod.zns,
                              groupValue: _selectedMethod,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMethod = value!;
                                });
                              },
                              title: const Row(
                                children: [
                                  Icon(Icons.chat_bubble_rounded, color: Color(0xFF0088FF), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Zalo ZNS',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: const Text(
                                'Nhận mã OTP qua Zalo',
                                style: TextStyle(fontSize: 12),
                              ),
                              activeColor: const Color(0xFFDC3545),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                    
                    // Phone number field
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_otpSent,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF212529),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: '0123456789',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w400,
                        ),
                        labelStyle: const TextStyle(
                          color: Color(0xFF6C757D),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_rounded,
                          color: Color(0xFF6C757D),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDC3545),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      validator: _validatePhone,
                    ),
                    
                    if (_otpSent) ...[
                      const SizedBox(height: 20),
                      
                      // OTP field
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF212529),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Mã OTP',
                          hintText: '123456',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                          ),
                          labelStyle: const TextStyle(
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(
                            Icons.sms_rounded,
                            color: Color(0xFF6C757D),
                            size: 20,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC3545),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          counterText: '',
                        ),
                        validator: _validateOTP,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // New password field
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF212529),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          hintText: 'Nhập mật khẩu mới',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                          ),
                          labelStyle: const TextStyle(
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFF6C757D),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC3545),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Re-password field
                      TextFormField(
                        controller: _rePasswordController,
                        obscureText: _obscureRePassword,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF212529),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          hintText: 'Nhập lại mật khẩu',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                          ),
                          labelStyle: const TextStyle(
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFF6C757D),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureRePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureRePassword = !_obscureRePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC3545),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                        ),
                        validator: _validateRePassword,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Resend OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa nhận được mã? ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (_countdown > 0)
                            Text(
                              'Gửi lại sau $_countdown giây',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                });
                                _sendOTP();
                              },
                              child: const Text(
                                'Gửi lại mã',
                                style: TextStyle(
                                  color: Color(0xFFDC3545),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Submit button
                    ElevatedButton(
                      onPressed: _isLoading ? null : (_otpSent ? _resetPassword : _sendOTP),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC3545),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _otpSent ? 'Đổi mật khẩu' : 'Gửi mã OTP',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

