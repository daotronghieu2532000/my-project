import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import 'api_service.dart';
import 'push_notification_service.dart';
import 'first_time_bonus_service.dart';
import '../models/user.dart';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _loginTimeKey =
      'login_time'; // Không sử dụng nữa, chỉ để clean up

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isLoggingOut = false; // Flag để ngăn restore user data

  // Callback để thông báo khi trạng thái đăng nhập thay đổi
  final List<Function()> _onAuthStateChanged = [];

  /// Đăng ký tài khoản mới
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phoneNumber,
    required String password,
    required String rePassword,
  }) async {
    try {
      final response = await _apiService.post(
        '/register',
        body: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'password': password,
          're_password': rePassword,
        },
      );

      if (response != null) {
        try {
          final data = jsonDecode(response.body);

          if (data['success'] == true) {
            return {
              'success': true,
              'message': data['message'] ?? 'Đăng ký thành công',
              'data': data['data'],
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Đăng ký thất bại',
            };
          }
        } catch (e) {
          return {'success': false, 'message': 'Lỗi xử lý dữ liệu từ server'};
        }
      } else {
        return {'success': false, 'message': 'Lỗi kết nối server'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối server'};
    }
  }

  /// Đăng nhập
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _apiService.post(
        '/login',
        body: {'username': username, 'password': password},
      );

      if (response != null) {
        try {
          final data = jsonDecode(response.body);

          // Kiểm tra success field trong response
          if (data['success'] == true && data['data'] != null) {
            // Đăng nhập thành công
            final user = User.fromJson(data['data']);
            await _saveUser(user);

            // ✅ Kiểm tra và tặng bonus lần đầu tải app
            final bonusService = FirstTimeBonusService();
            final bonusInfo = await bonusService.checkAndGrantBonus(
              user.userId,
            );

            // Lưu thông tin bonus vào SharedPreferences để hiển thị UI
            if (bonusInfo != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'first_time_bonus_info',
                jsonEncode(bonusInfo),
              );

              // Nếu là bonus mới, lưu flag để hiển thị dialog
              if (bonusInfo['is_new_bonus'] == true) {
                await prefs.setBool('show_bonus_dialog', true);
              }
            }

            // Register FCM token sau khi login thành công
            _registerPushToken();

            return {
              'success': true,
              'message': data['message'] ?? 'Đăng nhập thành công',
              'user': user,
            };
          } else {
            // Đăng nhập thất bại - có response nhưng success = false
            return {'success': false, 'message': 'Sai tài khoản hoặc mật khẩu'};
          }
        } catch (jsonError) {
          // Lỗi parse JSON
          return {'success': false, 'message': 'Lỗi xử lý dữ liệu từ server'};
        }
      } else {
        // Không có response
        return {'success': false, 'message': 'Không thể kết nối đến server'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Có lỗi xảy ra: $e'};
    }
  }

  /// Lưu thông tin user vào SharedPreferences
  Future<void> _saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Lưu thông tin user (vĩnh viễn)
      await prefs.setString(_userKey, jsonEncode(user.toJson()));

      _currentUser = user;

      // Thông báo cho các listener về việc thay đổi trạng thái
      _notifyAuthStateChanged();
    } catch (e) {}
  }

  Future<User?> getCurrentUser() async {
    if (_isLoggingOut) {
      return null;
    }

    if (_currentUser != null) {
      return _currentUser;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userData);
        return _currentUser;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Force clear toàn bộ AuthService (dùng khi logout)
  void forceClear() {
    _currentUser = null;
    _onAuthStateChanged.clear();
  }

  /// Logout hoàn toàn với verification
  Future<void> logoutCompletely() async {
    // Step 0: Set flag để ngăn restore user data
    _isLoggingOut = true;

    // Step 1: Clear memory FIRST
    _currentUser = null;

    // Step 2: Clear listeners BEFORE clearing SharedPreferences
    _onAuthStateChanged.clear();

    // Step 3: Clear SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_loginTimeKey);
      await prefs.commit();

      // Step 4: Verify
      final verify = prefs.getString(_userKey);
      if (verify != null) {
        await prefs.clear();
        await prefs.commit();
      }
    } catch (e) {}

    // Step 5: Clear API token
    try {
      await _apiService.clearToken();
    } catch (e) {}

    // Step 6: Reset flag sau khi hoàn thành
    _isLoggingOut = false;
  }

  /// Kiểm tra user đã đăng nhập chưa
  Future<bool> isLoggedIn() async {
    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
    }
  }

  /// Đăng xuất
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // CRITICAL: Clear user data TRƯỚC KHI xóa SharedPreferences
      _currentUser = null;

      // Xóa SharedPreferences và đợi hoàn tất
      await prefs.remove(_userKey);
      await prefs.remove(_loginTimeKey);

      // CRITICAL: Force commit để đảm bảo SharedPreferences được lưu
      await prefs.commit();

      // CRITICAL: Verify SharedPreferences đã được xóa
      final verifyUserJson = prefs.getString(_userKey);

      if (verifyUserJson != null) {
        await prefs.clear(); // Force clear toàn bộ SharedPreferences
        await prefs.commit();
      }

      // CRITICAL: Xóa API token để tránh auto-login
      await _apiService.clearToken();

      // CRITICAL: Force clear listeners để tránh restore user
      _onAuthStateChanged.clear();
    } catch (e) {
      // Vẫn đảm bảo clear local state ngay cả khi có lỗi
      _currentUser = null;
      _onAuthStateChanged.clear();
    }
  }

  /// Thêm listener cho sự thay đổi trạng thái đăng nhập
  void addAuthStateListener(Function() listener) {
    _onAuthStateChanged.add(listener);
  }

  /// Xóa listener
  void removeAuthStateListener(Function() listener) {
    _onAuthStateChanged.remove(listener);
  }

  /// Thông báo cho tất cả listener về sự thay đổi trạng thái
  void _notifyAuthStateChanged() {
    for (int i = 0; i < _onAuthStateChanged.length; i++) {
      try {
        _onAuthStateChanged[i]();
      } catch (e) {}
    }
  }

  /// Cập nhật thông tin user
  Future<void> updateUser(User user) async {
    await _saveUser(user);
  }

  /// Lấy URL avatar (với fallback)
  String getAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return 'lib/src/core/assets/images/user_default.png';
    }

    // Nếu avatar là URL đầy đủ
    if (avatar.startsWith('http')) {
      return avatar;
    }

    // Xử lý trường hợp có prefix socdo.vn trong path
    String cleanPath = avatar;
    if (avatar.startsWith('socdo.vn/')) {
      cleanPath = avatar.substring(9); // Bỏ "socdo.vn/"
    }

    // Nếu avatar là path relative, thêm tiền tố https://socdo.vn/
    if (cleanPath.startsWith('/')) {
      return 'https://socdo.vn$cleanPath';
    } else {
      return 'https://socdo.vn/$cleanPath';
    }
  }

  /// Lấy tên hiển thị
  String getDisplayName(User user) {
    return user.name.isNotEmpty ? user.name : user.username;
  }

  /// Lấy số dư hiển thị
  String getFormattedBalance(User user) {
    return '${user.userMoney.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND';
  }

  /// Register FCM token sau khi login
  Future<void> _registerPushToken() async {
    try {
      final pushService = PushNotificationService();

      // Kiểm tra và khởi tạo PushNotificationService nếu cần
      if (!pushService.isInitialized) {
        await pushService.initialize();
      }

      // Lấy token hiện tại
      final token = await FirebaseMessaging.instance.getToken();

      if (token == null) {
        return;
      }

      // Kiểm tra xem đã có user đăng nhập chưa
      final user = await getCurrentUser();
      if (user != null) {
        // Gọi API đăng ký token lên server
        final deviceInfo = await _getDeviceInfo();
        final String platform = deviceInfo['platform'] ?? 'unknown';
        final String model = deviceInfo['model'] ?? 'unknown';
        final String appVersion = deviceInfo['appVersion'] ?? 'unknown';

        final success = await _apiService.registerDeviceToken(
          userId: user.userId,
          deviceToken: token,
          platform: platform,
          deviceModel: model,
          appVersion: appVersion,
        );

        if (success) {
          print('✅ Đã đăng ký FCM token thành công cho user ${user.userId}');
        }
      }
     } catch (e) {
       print('❌ Lỗi khi đăng ký FCM token: $e');
     }
  }

  /// Lấy thông tin thiết bị
  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      String platform = 'unknown';
      String model = 'unknown';
      String appVersion = 'unknown';

      // Lấy thông tin platform và model
      if (defaultTargetPlatform == TargetPlatform.android) {
        platform = 'android';
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        model = '${deviceInfo.brand} ${deviceInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
        final deviceInfo = await DeviceInfoPlugin().iosInfo;
        model = '${deviceInfo.name} ${deviceInfo.model}';
      }

      // Lấy version app
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;

      return {'platform': platform, 'model': model, 'appVersion': appVersion};
    } catch (e) {
      return {
        'platform': 'unknown',
        'model': 'unknown',
        'appVersion': 'unknown',
      };
    }
  }

  /// Gửi OTP qua SMS (eSMS) - ĐÃ TẮT
  // Future<Map<String, dynamic>> forgotPasswordSMS(String phoneNumber) async {
  //   try {
  //     final response = await _apiService.post(
  //       '/forgot_password_sms',
  //       body: {'phone_number': phoneNumber},
  //     );
  //
  //     if (response != null) {
  //       try {
  //         final data = jsonDecode(response.body);
  //         if (data['success'] == true) {
  //           return {
  //             'success': true,
  //             'message':
  //                 data['message'] ??
  //                 'Mã OTP đã được gửi đến số điện thoại của bạn',
  //             'data': data['data'],
  //           };
  //         } else {
  //           String errorMessage = data['message'] ?? 'Gửi OTP thất bại';
  //           return {
  //             'success': false,
  //             'message': errorMessage,
  //           };
  //         }
  //       } catch (e) {
  //         return {
  //           'success': false,
  //           'message': 'Lỗi xử lý dữ liệu từ server',
  //         };
  //       }
  //     } else {
  //       return {'success': false, 'message': 'Lỗi kết nối server'};
  //     }
  //   } catch (e) {
  //     return {
  //       'success': false,
  //       'message': 'Lỗi kết nối server',
  //     };
  //   }
  // }

  /// Gửi OTP qua cuộc gọi Stringee - ĐÃ TẮT
  // Future<Map<String, dynamic>> forgotPasswordStringeeCall(
  //   String phoneNumber,
  // ) async {
  //   try {
  //     final response = await _apiService.post(
  //       '/forgot_password_call',
  //       body: {'phone_number': phoneNumber},
  //     );
  //
  //     if (response != null) {
  //       try {
  //         final data = jsonDecode(response.body);
  //         if (data['success'] == true) {
  //           return {
  //             'success': true,
  //             'message':
  //                 data['message'] ?? 'Bạn sẽ nhận được cuộc gọi với mã OTP',
  //             'data': data['data'],
  //           };
  //         } else {
  //           String errorMessage = data['message'] ?? 'Gửi OTP thất bại';
  //           return {'success': false, 'message': errorMessage};
  //         }
  //       } catch (e) {
  //         return {'success': false, 'message': 'Lỗi xử lý dữ liệu từ server'};
  //       }
  //     } else {
  //       return {'success': false, 'message': 'Lỗi kết nối server'};
  //     }
  //   } catch (e) {
  //     return {'success': false, 'message': 'Lỗi kết nối server'};
  //   }
  // }

  /// Gửi OTP qua Zalo ZNS
  Future<Map<String, dynamic>> forgotPasswordZNS(String phoneNumber) async {
    try {
      final response = await _apiService.post(
        '/forgot_password_zns',
        body: {'phone_number': phoneNumber},
      );

      if (response != null) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            return {
              'success': true,
              'message': data['message'] ?? 'Mã OTP đã được gửi qua Zalo',
              'data': data['data'],
            };
          } else {
            String errorMessage = data['message'] ?? 'Gửi OTP thất bại';
            return {'success': false, 'message': errorMessage};
          }
        } catch (e) {
          return {'success': false, 'message': 'Lỗi xử lý dữ liệu từ server'};
        }
      } else {
        return {'success': false, 'message': 'Lỗi kết nối server'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối server'};
    }
  }

  /// Xác thực OTP và đổi mật khẩu
  Future<Map<String, dynamic>> verifyOTPAndResetPassword({
    required String phoneNumber,
    required String otp,
    required String newPassword,
    required String rePassword,
  }) async {
    try {
      final response = await _apiService.post(
        '/verify_otp_reset_password',
        body: {
          'phone_number': phoneNumber,
          'otp': otp,
          'new_password': newPassword,
          're_password': rePassword,
        },
      );

      if (response != null) {
        try {
          final data = jsonDecode(response.body);

          if (data['success'] == true) {
            return {
              'success': true,
              'message': data['message'] ?? 'Đổi mật khẩu thành công',
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Đổi mật khẩu thất bại',
            };
          }
        } catch (e) {
          return {'success': false, 'message': 'Lỗi xử lý dữ liệu từ server'};
        }
      } else {
        return {'success': false, 'message': 'Lỗi kết nối server'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối server'};
    }
  }

  /// Đăng nhập bằng Google
  Future<Map<String, dynamic>> loginWithGoogle({
    required String googleId,
    required String idToken,
    String? email,
    String? name,
    String? photoUrl,
  }) async {
    try {
      final response = await _apiService.post(
        '/login_google',
        body: {
          'google_id': googleId,
          'id_token': idToken,
          if (email != null) 'email': email,
          if (name != null) 'name': name,
          if (photoUrl != null) 'photo_url': photoUrl,
        },
      );

      if (response != null) {
        // Kiểm tra status code
        if (response.statusCode != 200 && response.statusCode != 201) {
          // Thử parse error message từ response
          try {
            final errorData = jsonDecode(response.body);
            return {
              'success': false,
              'message':
                  errorData['message'] ??
                  'Đăng nhập thất bại (Status: ${response.statusCode})',
            };
          } catch (e) {
            return {
              'success': false,
              'message': 'Đăng nhập thất bại (Status: ${response.statusCode})',
            };
          }
        }

        try {
          final data = jsonDecode(response.body);

          if (data['success'] == true && data['data'] != null) {
            // Đăng nhập thành công
            final user = User.fromJson(data['data']);
            await _saveUser(user);

            // ✅ Kiểm tra và tặng bonus lần đầu tải app
            final bonusService = FirstTimeBonusService();
            final bonusInfo = await bonusService.checkAndGrantBonus(
              user.userId,
            );

            // Lưu thông tin bonus vào SharedPreferences để hiển thị UI
            if (bonusInfo != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'first_time_bonus_info',
                jsonEncode(bonusInfo),
              );

              // Nếu là bonus mới, lưu flag để hiển thị dialog
              if (bonusInfo['is_new_bonus'] == true) {
                await prefs.setBool('show_bonus_dialog', true);
              }
            }

            // Register FCM token sau khi login thành công
            _registerPushToken();

            return {
              'success': true,
              'message': data['message'] ?? 'Đăng nhập thành công',
              'user': user,
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Đăng nhập thất bại',
            };
          }
        } catch (jsonError) {
          return {
            'success': false,
            'message': 'Lỗi xử lý dữ liệu từ server. Vui lòng thử lại.',
          };
        }
      } else {
        return {'success': false, 'message': 'Không thể kết nối đến server'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Có lỗi xảy ra: $e'};
    }
  }

  /// Đăng nhập bằng Facebook
  /// CHỈ lấy: facebook_id, name, avatar
  /// KHÔNG lấy: email, mobile, ngày sinh, địa chỉ - để user tự điền sau
  Future<Map<String, dynamic>> loginWithFacebook({
    required String facebookId,
    required String accessToken,
    String? email, // ✅ KHÔNG dùng - chỉ để backward compatibility
    String? name,
    String? pictureUrl,
  }) async {
    try {
      final response = await _apiService.post(
        '/login_facebook',
        body: {
          'facebook_id': facebookId,
          'access_token': accessToken,
          // ✅ KHÔNG gửi email - để backend tạo user mới với email = null/empty
          if (name != null) 'name': name,
          if (pictureUrl != null) 'picture_url': pictureUrl,
        },
      );

      if (response != null) {
        try {
          final data = jsonDecode(response.body);

          if (data['success'] == true && data['data'] != null) {
            // Đăng nhập thành công
            final userData = data['data'] as Map<String, dynamic>;

             final user = User.fromJson(userData);

             await _saveUser(user);
             // ✅ Kiểm tra và tặng bonus lần đầu tải app
            final bonusService = FirstTimeBonusService();
            final bonusInfo = await bonusService.checkAndGrantBonus(
              user.userId,
            );

            // Lưu thông tin bonus vào SharedPreferences để hiển thị UI
            if (bonusInfo != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'first_time_bonus_info',
                jsonEncode(bonusInfo),
              );

              // Nếu là bonus mới, lưu flag để hiển thị dialog
              if (bonusInfo['is_new_bonus'] == true) {
                await prefs.setBool('show_bonus_dialog', true);
              }
            }

            // Register FCM token sau khi login thành công
            _registerPushToken();

            return {
              'success': true,
              'message': data['message'] ?? 'Đăng nhập thành công',
              'user': user,
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Đăng nhập thất bại',
            };
          }
        } catch (jsonError) {
          return {'success': false, 'message': 'Lỗi xử lý dữ liệu từ server'};
        }
      } else {
        return {'success': false, 'message': 'Không thể kết nối đến server'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Có lỗi xảy ra: $e'};
    }
  }
}
