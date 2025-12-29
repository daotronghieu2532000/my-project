import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/first_time_bonus_service.dart';
import '../root_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _promoCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rePasswordController = TextEditingController();
  
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _obscurePassword = true;
  bool _obscureRePassword = true;
  int _countdown = 0;
  bool _isValidatingPromoCode = false;
  String? _promoCodeError;
  int? _rateLimitWaitSeconds;
  bool _isRateLimited = false;
  
  // Kiểm tra yêu cầu mật khẩu - Đơn giản hóa như Shopee, Facebook
  bool _hasMinLength(String password) => password.length >= 6;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _promoCodeController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    super.dispose();
  }
  
  void _startCountdown([int? initialSeconds]) {
    final seconds = initialSeconds ?? 60;
    setState(() {
      _countdown = seconds;
      _isRateLimited = false;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _isRateLimited = false;
            _rateLimitWaitSeconds = null;
          }
        });
        return _countdown > 0;
      }
      return false;
    });
  }
  
  void _startRateLimitCountdown(int waitSeconds) {
    setState(() {
      _isRateLimited = true;
      _rateLimitWaitSeconds = waitSeconds;
      _countdown = waitSeconds;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _isRateLimited = false;
            _rateLimitWaitSeconds = null;
          }
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
    
    // Kiểm tra nếu đang bị rate limit
    if (_isRateLimited && _countdown > 0) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _authService.registerSendOTP(_phoneController.text.trim());
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _otpSent = true;
            _isRateLimited = false;
            _rateLimitWaitSeconds = null;
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
          // Kiểm tra nếu bị rate limit
          final waitSeconds = result['wait_seconds'] as int?;
          final errorCode = result['error_code'] as String?;
          
          if (errorCode == 'RATE_LIMIT_EXCEEDED' && waitSeconds != null) {
            // Bị rate limit, hiển thị thông báo mềm mại và bắt đầu countdown
            _startRateLimitCountdown(waitSeconds);
            
            // Hiển thị thông báo mềm mại
            String friendlyMessage = result['message'] ?? 'Vui lòng đợi trước khi gửi lại';
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friendlyMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (waitSeconds > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Vui lòng đợi ${_formatWaitTime(waitSeconds)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: waitSeconds > 60 ? 5 : 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            // Lỗi khác
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Gửi OTP thất bại'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
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
  
  String _formatWaitTime(int seconds) {
    if (seconds >= 86400) {
      final hours = (seconds / 3600).ceil();
      return '$hours giờ';
    } else if (seconds >= 3600) {
      final hours = (seconds / 3600).ceil();
      return '$hours giờ';
    } else if (seconds >= 60) {
      final minutes = (seconds / 60).ceil();
      return '$minutes phút';
    } else {
      return '$seconds giây';
    }
  }
  
  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _authService.registerVerifyOTP(
        phoneNumber: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
      );
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _otpVerified = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Xác thực OTP thành công'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Xác thực OTP thất bại'),
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
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    // Kiểm tra số điện thoại Việt Nam (10 số, bắt đầu bằng 0)
    final phoneRegex = RegExp(r'^0[0-9]{9}$');
    if (!phoneRegex.hasMatch(value.trim())) {
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
    // Validate đơn giản - chỉ yêu cầu tối thiểu 6 ký tự
    if (!_hasMinLength(value)) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }
    return null;
  }


  String? _validateRePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu';
    }
    if (value != _passwordController.text) {
      return 'Mật khẩu không khớp';
    }
    return null;
  }

  /// Validate mã thưởng real-time (gọi API)
  Future<void> _validatePromoCode(String code) async {
    if (code.isEmpty) {
      setState(() {
        _promoCodeError = null;
        _isValidatingPromoCode = false;
      });
      return;
    }

    setState(() {
      _isValidatingPromoCode = true;
      _promoCodeError = null;
    });

    try {
      final apiService = ApiService();
      final token = await apiService.getValidToken();
      if (token == null) {
        setState(() {
          _promoCodeError = 'Không thể xác thực mã giới thiệu';
          _isValidatingPromoCode = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.socdo.vn/v1/validate_promo_code?code=${Uri.encodeComponent(code)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            if (data['data']['valid'] == true) {
              setState(() {
                _promoCodeError = null;
                _isValidatingPromoCode = false;
              });
            } else {
              // Mã không hợp lệ
              setState(() {
                _promoCodeError = data['data']['message'] ?? 'Mã giới thiệu không hợp lệ hoặc đã hết hạn';
                _isValidatingPromoCode = false;
              });
            }
          } else {
            setState(() {
              _promoCodeError = 'Mã giới thiệu không tồn tại';
              _isValidatingPromoCode = false;
            });
          }
        } else {
          setState(() {
            _promoCodeError = 'Mã giới thiệu không tồn tại';
            _isValidatingPromoCode = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _promoCodeError = 'Mã giới thiệu không tồn tại';
          _isValidatingPromoCode = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.register(
        fullName: '',
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
        rePassword: _rePasswordController.text,
        promoCode: _promoCodeController.text.trim().isNotEmpty 
            ? _promoCodeController.text.trim() 
            : null,
      );

      if (result['success'] == true) {
        // Đăng ký thành công, tự động đăng nhập luôn
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đăng ký thành công'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // ✅ Lưu promo_code_id vào SharedPreferences nếu có
          if (result['data'] != null) {
            final data = result['data'] as Map<String, dynamic>?;
            if (data != null && data['promo_code_id'] != null) {
              // print('✅ [REGISTER] Lưu promo_code_id: ${data['promo_code_id']}');
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('pending_promo_code_id', data['promo_code_id'] as int);
              if (data['promo_code_expires_at'] != null) {
                await prefs.setInt('pending_promo_code_expires_at', data['promo_code_expires_at'] as int);
              }
            } else {
              // print('⚠️ [REGISTER] Không có promo_code_id trong response: $data');
            }
          } else {
            // print('⚠️ [REGISTER] result[data] is null');
          }
          
          // Tự động đăng nhập với thông tin vừa đăng ký
          final loginResult = await _authService.login(
            _phoneController.text.trim(),
            _passwordController.text,
          );
          
          if (mounted) {
            if (loginResult['success'] == true) {
              // ✅ Kiểm tra có promo code không và gọi checkAndGrantBonus
              final prefs = await SharedPreferences.getInstance();
              final promoCodeId = prefs.getInt('pending_promo_code_id');
              
              if (promoCodeId != null) {
                // print('✅ [BONUS] Bắt đầu tạo bonus với promoCodeId: $promoCodeId');
                // Gọi API tạo bonus với promo code
                final bonusService = FirstTimeBonusService();
                final user = await _authService.getCurrentUser();
                if (user != null) {
                  // print('✅ [BONUS] User ID: ${user.userId}');
                  // ✅ Gọi API và kiểm tra kết quả
                  final bonusResult = await bonusService.checkAndGrantBonus(user.userId, promoCodeId: promoCodeId);
                  // print('📊 [BONUS] Kết quả từ API: $bonusResult');
                  
                  // ✅ Kiểm tra bonus có được tạo thành công không
                  if (bonusResult != null && bonusResult['has_bonus'] == true) {
                    if (bonusResult['is_new_bonus'] == true) {
                      // print('✅ [BONUS] Bonus đã được tạo thành công!');
                      // Set flag để hiển thị dialog
                      await prefs.setBool('show_bonus_dialog', true);
                    } else {
                      // print('⚠️ [BONUS] Bonus đã tồn tại từ trước');
                    }
                  } else {
                    // ❌ Bonus không được tạo, log lỗi
                    // print('❌ [BONUS] Không tạo được bonus: $bonusResult');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(bonusResult?['message'] ?? 'Không thể tạo bonus. Vui lòng thử lại.'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                  
                  // Xóa pending promo code (dù thành công hay thất bại)
                  await prefs.remove('pending_promo_code_id');
                  await prefs.remove('pending_promo_code_expires_at');
                } else {
                  // print('❌ [BONUS] User is null');
                }
              } else {
                // print('⚠️ [BONUS] promoCodeId is null - User đăng ký không có mã thưởng');
              }
              
              // Đăng nhập thành công, chuyển vào trang chủ
              // Dialog cảm ơn sẽ được hiển thị ở home_screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const RootShell(initialIndex: 0),
                ),
                (route) => false, // Xóa tất cả các route trước đó
              );
            } else {
              // Đăng nhập thất bại, quay lại màn hình trước (thường không xảy ra)
              Navigator.of(context).pop();
            }
          }
        }
      } else {
        if (mounted) {
          // ✅ Nếu OTP hết hạn, reset trạng thái để user có thể xác minh lại
          if (result['error_code'] == 'OTP_EXPIRED') {
            setState(() {
              _otpSent = false;
              _otpVerified = false;
              _otpController.clear();
              _countdown = 0;
            });
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Đăng ký thất bại'),
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
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
              children: [
                // Modern AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                        'Đăng ký',
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(80),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_add_rounded,
                                size: 32,
                                color: const Color(0xFFDC3545),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                          
                          // Modern Form Container
                          Container(
                            padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                                // Compact Phone field
                                TextFormField(
                                  controller: _phoneController,
                                  enabled: !_otpVerified, // ✅ Cho phép edit nếu chưa verify OTP
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
                                    fillColor: Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: _validatePhone,
                                  textInputAction: TextInputAction.next,
                                ),
                                
                                if (_otpSent && !_otpVerified) ...[
                                  const SizedBox(height: 16),
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
                                        color: const Color(0xFFADB5BD),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      labelStyle: TextStyle(
                                        color: const Color(0xFF6C757D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.sms_rounded,
                                        color: const Color(0xFF6C757D),
                                        size: 20,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      counterText: '',
                                    ),
                                    validator: _validateOTP,
                                    textInputAction: TextInputAction.done,
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
                                          _isRateLimited
                                              ? 'Vui lòng đợi ${_formatWaitTime(_countdown)}'
                                              : 'Gửi lại sau $_countdown giây',
                                          style: TextStyle(
                                            color: _isRateLimited ? Colors.orange[700] : Colors.grey[600],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: _isRateLimited ? null : () {
                                            setState(() {
                                              _otpSent = false;
                                              _otpController.clear();
                                            });
                                            _sendOTP();
                                          },
                                          child: Text(
                                            'Gửi lại mã',
                                            style: TextStyle(
                                              color: _isRateLimited ? Colors.grey[400] : const Color(0xFFDC3545),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Hiển thị thông báo rate limit nếu có
                                  if (_isRateLimited && _rateLimitWaitSeconds != null && _rateLimitWaitSeconds! > 60)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.orange[200]!),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: 16,
                                              color: Colors.orange[700],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Để đảm bảo an toàn, bạn cần đợi ${_formatWaitTime(_rateLimitWaitSeconds!)} trước khi gửi lại. Nếu cần hỗ trợ, vui lòng liên hệ hotline 0943.051.818',
                                                style: TextStyle(
                                                  color: Colors.orange[900],
                                                  fontSize: 12,
                                                  height: 1.4,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                                
                                if (_otpVerified) ...[
                                  const SizedBox(height: 16),
                                  // Password field
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
                                      helperText: 'Mật khẩu phải có ít nhất 6 ký tự',
                                      helperStyle: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        height: 1.3,
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
                                      fillColor: Colors.grey[50],
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    validator: _validatePassword,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (value) {
                                      if (_rePasswordController.text.isNotEmpty) {
                                        _formKey.currentState!.validate();
                                      }
                                    },
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Compact Re-password field
                                  TextFormField(
                                  controller: _rePasswordController,
                                  obscureText: _obscureRePassword,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF212529),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Nhập lại mật khẩu',
                                    hintText: 'Nhập lại mật khẩu',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFFADB5BD),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    labelStyle: TextStyle(
                                      color: const Color(0xFF6C757D),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      color: const Color(0xFF6C757D),
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureRePassword 
                                          ? Icons.visibility_rounded 
                                          : Icons.visibility_off_rounded,
                                        color: const Color(0xFF6C757D),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureRePassword = !_obscureRePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: _validateRePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleRegister(),
                                ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Mã thưởng field (optional) - Đặt ở cuối cùng
                                  TextFormField(
                                    controller: _promoCodeController,
                                    enabled: !_isValidatingPromoCode,
                                    textCapitalization: TextCapitalization.characters,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF212529),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Mã giới thiệu (nếu có)🎁',
                                      hintText: 'Nhập mã giới thiệu nếu có',
                                      hintStyle: TextStyle(
                                        color: const Color(0xFFADB5BD),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      labelStyle: TextStyle(
                                        color: const Color(0xFF6C757D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.card_giftcard,
                                        color: const Color(0xFF6C757D),
                                        size: 20,
                                      ),
                                      suffixIcon: _isValidatingPromoCode
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : _promoCodeError != null
                                              ? Icon(
                                                  Icons.error_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                )
                                              : _promoCodeController.text.isNotEmpty && _promoCodeError == null
                                                  ? Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                      size: 20,
                                                    )
                                                  : null,
                                      errorText: _promoCodeError,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    // ✅ Chỉ validate khi user blur (rời khỏi field) hoặc nhấn nút đăng ký
                                    onEditingComplete: () {
                                      // Khi user nhấn Done/Enter, validate nếu có giá trị
                                      if (_promoCodeController.text.trim().isNotEmpty) {
                                        _validatePromoCode(_promoCodeController.text.trim());
                                      }
                                    },
                                    // ✅ Xóa auto-validate khi đang nhập để tránh nhảy con trỏ
                                    onChanged: (value) {
                                      // Chỉ clear error khi user đang nhập, không validate tự động
                                      if (_promoCodeError != null) {
                                        setState(() {
                                          _promoCodeError = null;
                                        });
                                      }
                                    },
                                    textInputAction: TextInputAction.done,
                                  ),
                                ],
                                
                                const SizedBox(height: 24),
                                
                                // Modern Register button
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
                                    onPressed: (_isLoading || _isRateLimited) ? null : (_otpVerified ? _handleRegister : (_otpSent ? _verifyOTP : _sendOTP)),
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
                                        : Text(
                                            _otpVerified 
                                                ? 'Đăng ký' 
                                                : (_otpSent 
                                                    ? 'Xác thực OTP' 
                                                    : (_isRateLimited && _countdown > 0
                                                        ? 'Vui lòng đợi ${_formatWaitTime(_countdown)}'
                                                        : 'Gửi mã OTP')),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                // Thông báo Zalo - chỉ hiển thị khi chưa gửi OTP
                                if (!_otpSent) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/icons/zalo_icon.webp',
                                          width: 20,
                                          height: 20,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.info_outline,
                                              size: 18,
                                              color: Colors.grey[600],
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '! Lưu ý: sử dụng số điện thoại đã kích hoạt Zalo nhận mã OTP',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 20),
                                
                                // Modern Login link
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Đã có tài khoản? ',
                                        style: TextStyle(
                                          color: const Color(0xFF6C757D),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(
                                          'Đăng nhập ngay',
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
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}