import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user.dart';
import 'package:image_picker/image_picker.dart';

// Định nghĩa màu sắc và kiểu chữ cho giao diện hiện đại, sang trọng
class AppColors {
  static const Color primary = Color(0xFF007AFF); // Màu xanh dương hiện đại
  static const Color background = Color(0xFFF9F9F9); // Nền siêu nhẹ
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE0E0E0); // Viền mỏng, tinh tế
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _ngaysinhCtrl = TextEditingController();
  final _gioiTinhCtrl = TextEditingController();
  final _diaChiCtrl = TextEditingController();

  final _api = ApiService();
  final _auth = AuthService();

  User? _user;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = await _auth.getCurrentUser();
    if (current == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    
    setState(() { _user = current; });
    final data = await _api.getUserProfile(userId: current.userId);
    
    if (data != null && data['user'] != null) {
      final user = data['user'] as Map<String, dynamic>;

      
      // ✅ CRITICAL: Verify user_id matches before using data
      final apiUserId = user['user_id'];
      if (apiUserId != null) {
        final apiUserIdInt = apiUserId is int ? apiUserId : int.tryParse(apiUserId.toString());
        if (apiUserIdInt != null && apiUserIdInt != current.userId) {
        
          // DON'T USE API DATA - Use current user data instead
          _nameCtrl.text = current.name;
          _emailCtrl.text = current.email;
          _mobileCtrl.text = current.mobile;
          if (mounted) setState(() { _loading = false; });
          return;
        }
      }
      
      // ✅ User ID matches - use API data
      // ✅ Cập nhật _user state với avatar từ API để hiển thị đúng
      final updatedUser = current.copyWith(
        name: user['name']?.toString() ?? current.name,
        email: user['email']?.toString() ?? current.email,
        mobile: user['mobile']?.toString() ?? current.mobile,
        avatar: (user['avatar']?.toString().isNotEmpty == true ? user['avatar'].toString() : current.avatar),
      );
      
      _nameCtrl.text = user['name']?.toString() ?? current.name;
      _emailCtrl.text = user['email']?.toString() ?? current.email;
      _mobileCtrl.text = user['mobile']?.toString() ?? current.mobile;
      
      // ✅ Parse ngày sinh từ API (có thể là yyyy-mm-dd, timestamp, hoặc dd/MM/yyyy)
      final ngaysinhStr = user['ngaysinh']?.toString() ?? '';
      if (ngaysinhStr.isNotEmpty) {
        try {
          DateTime? parsedDate;
          // Thử parse timestamp (nếu là số)
          if (RegExp(r'^\d+$').hasMatch(ngaysinhStr)) {
            final timestamp = int.tryParse(ngaysinhStr);
            if (timestamp != null) {
              parsedDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
          } else {
            // Thử parse các định dạng ngày thường gặp
            final formats = ['yyyy-MM-dd', 'dd/MM/yyyy', 'dd-MM-yyyy', 'yyyy/MM/dd'];
            for (var format in formats) {
              try {
                parsedDate = DateFormat(format).parse(ngaysinhStr);
                break;
              } catch (e) {
                continue;
              }
            }
          }
          
          if (parsedDate != null) {
            _ngaysinhCtrl.text = DateFormat('dd/MM/yyyy').format(parsedDate);
          } else {
            _ngaysinhCtrl.text = ngaysinhStr; // Giữ nguyên nếu không parse được
          }
        } catch (e) {
          _ngaysinhCtrl.text = ngaysinhStr; // Giữ nguyên nếu có lỗi
        }
      } else {
        _ngaysinhCtrl.text = '';
      }
      
      _gioiTinhCtrl.text = user['gioi_tinh']?.toString() ?? '';
      _diaChiCtrl.text = user['dia_chi']?.toString() ?? '';
      
      // ✅ Cập nhật _user state với avatar mới
      if (mounted) setState(() { 
        _user = updatedUser;
        _loading = false; 
      });
      return;
    
    } else {
      // Fallback to current user data if API fails
    
      _nameCtrl.text = current.name;
      _emailCtrl.text = current.email;
      _mobileCtrl.text = current.mobile;
    }
    
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _user == null) return;
    setState(() { _saving = true; });
    
    // ✅ Format ngày sinh từ dd/MM/yyyy sang yyyy-MM-dd để gửi lên API
    String? ngaysinhFormatted;
    if (_ngaysinhCtrl.text.trim().isNotEmpty) {
      try {
        // Parse từ dd/MM/yyyy
        final parsedDate = DateFormat('dd/MM/yyyy').parse(_ngaysinhCtrl.text.trim());
        // Format thành yyyy-MM-dd (format chuẩn cho database)
        ngaysinhFormatted = DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        // Nếu không parse được, giữ nguyên (có thể đã là yyyy-MM-dd)
        ngaysinhFormatted = _ngaysinhCtrl.text.trim();
      }
    }
    
    final ok = await _api.updateUserProfile(
      userId: _user!.userId,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      ngaysinh: ngaysinhFormatted,
      gioiTinh: _gioiTinhCtrl.text.trim(),
      diaChi: _diaChiCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() { _saving = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Cập nhật thành công' : 'Cập nhật thất bại'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _ngaysinhCtrl.dispose();
    _gioiTinhCtrl.dispose();
    _diaChiCtrl.dispose();
    super.dispose();
  }

  // Widget mới: Thẻ Avatar lớn hơn, dễ click
  Widget _buildAvatarSection() {
    final avatarUrl = _user?.avatar;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 50, // Tăng kích thước từ 32 lên 50
              backgroundColor: AppColors.border,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(_auth.getAvatarUrl(avatarUrl))
                  : const AssetImage('lib/src/core/assets/images/user_default.png') as ImageProvider,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                // Tăng diện tích click bằng cách thêm padding và hitTestBehavior
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8), // Tăng padding từ 4 lên 8
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _uploadingAvatar
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt, color: Colors.white, size: 20), // Tăng kích thước icon từ 14 lên 20
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget mới: Thẻ thông tin tổng hợp, loại bỏ các card riêng lẻ
  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin cơ bản',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 24, thickness: 0.5, color: AppColors.border),
          _buildLabeledField('Họ và tên', _nameCtrl, requiredField: true, hint: 'Nhập họ và tên'),
          const SizedBox(height: 12), // Giảm khoảng cách
          _buildLabeledField('Email', _emailCtrl, keyboard: TextInputType.emailAddress, hint: 'example@mail.com'),
          const SizedBox(height: 12),
          _buildLabeledField('Số điện thoại', _mobileCtrl, keyboard: TextInputType.phone, hint: '098xxxxxxx'),
          const SizedBox(height: 12),
          // Gộp Ngày sinh và Giới tính vào cùng một hàng
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField('Ngày sinh', _ngaysinhCtrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledField('Giới tính', _gioiTinhCtrl, hint: 'nam/nữ'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLabeledField('Địa chỉ', _diaChiCtrl, maxLines: 3, hint: 'Số nhà, đường, phường/xã, quận/huyện, tỉnh/thành'),
        ],
      ),
    );
  }

  // Widget mới: Nút Quản lý sổ địa chỉ (giữ lại theo yêu cầu)
  Widget _buildAddressAction() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pushNamed('/profile/address'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: AppColors.border, width: 1),
          foregroundColor: AppColors.textPrimary,
        ),
        child: const Text('Quản lý sổ địa chỉ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      print('[ProfileEditScreen] _pickAndUploadAvatar START');
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null || _user == null) {
        print('[ProfileEditScreen] _pickAndUploadAvatar - No image picked or user is null');
        return;
      }
      print('[ProfileEditScreen] _pickAndUploadAvatar - Image picked: ${picked.name}, path: ${picked.path}');
      
      setState(() { _uploadingAvatar = true; });
      final bytes = await picked.readAsBytes();
      print('[ProfileEditScreen] _pickAndUploadAvatar - Image bytes loaded: ${bytes.length} bytes');
      
      final String filename = picked.name;
      final String contentType = filename.toLowerCase().endsWith('.png') ? 'image/png' : (filename.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      print('[ProfileEditScreen] _pickAndUploadAvatar - Calling API: userId=${_user!.userId}, filename=$filename, contentType=$contentType');
      
      final uploadedPath = await _api.uploadAvatar(userId: _user!.userId, bytes: bytes, filename: filename, contentType: contentType);
      print('[ProfileEditScreen] _pickAndUploadAvatar - API response: uploadedPath=$uploadedPath');
      
      if (!mounted) {
        print('[ProfileEditScreen] _pickAndUploadAvatar - Widget not mounted, returning');
        return;
      }
      
      setState(() { _uploadingAvatar = false; });
      
      if (uploadedPath != null && uploadedPath.isNotEmpty) {
        print('[ProfileEditScreen] _pickAndUploadAvatar SUCCESS - Updating user with avatar: $uploadedPath');
        final updated = _user!.copyWith(avatar: uploadedPath);
        await _auth.updateUser(updated);
        setState(() { _user = updated; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật avatar thành công'), backgroundColor: Colors.green));
      } else {
        print('[ProfileEditScreen] _pickAndUploadAvatar FAILED - uploadedPath is null or empty');
        // Hiển thị thông báo lỗi chi tiết hơn
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật avatar thất bại. Vui lòng thử sau hoặc báo lỗi với chúng tôi ngay nhé'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('[ProfileEditScreen] _pickAndUploadAvatar EXCEPTION: $e');
      print('[ProfileEditScreen] _pickAndUploadAvatar STACKTRACE: $stackTrace');
      if (!mounted) return;
      setState(() { _uploadingAvatar = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }

  // Widget DatePicker cho ngày sinh
  Widget _buildDatePickerField(String label, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            // Parse ngày hiện tại từ controller nếu có
            DateTime? initialDate;
            if (c.text.isNotEmpty) {
              try {
                // Thử parse các định dạng phổ biến
                final formats = [
                  'dd/MM/yyyy',
                  'yyyy-MM-dd',
                  'dd-MM-yyyy',
                  'yyyy/MM/dd',
                ];
                
                for (var format in formats) {
                  try {
                    initialDate = DateFormat(format).parse(c.text);
                    break;
                  } catch (e) {
                    continue;
                  }
                }
              } catch (e) {
                // Nếu không parse được, dùng ngày hiện tại
              }
            }
            
            // Nếu không có ngày, dùng ngày hiện tại trừ 18 năm (giả sử user 18 tuổi)
            initialDate ??= DateTime.now().subtract(const Duration(days: 365 * 18));
            
            // Giới hạn: không được chọn ngày trong tương lai, và không quá 100 năm trước
            final firstDate = DateTime.now().subtract(const Duration(days: 365 * 100));
            final lastDate = DateTime.now();
            
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
              // ✅ Sử dụng locale tiếng Việt nếu có
              locale: const Locale('vi', 'VN'),
              // ✅ Cải thiện UI DatePicker với các tham số được hỗ trợ
              helpText: 'Chọn ngày sinh',
              cancelText: 'Hủy',
              confirmText: 'Xác nhận',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            
            if (pickedDate != null) {
              // Format ngày theo dd/MM/yyyy
              c.text = DateFormat('dd/MM/yyyy').format(pickedDate);
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: c,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Chọn ngày sinh',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: AppColors.background,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
                suffixIcon: const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              readOnly: true,
            ),
          ),
        ),
      ],
    );
  }

  // Widget trường nhập liệu được tinh chỉnh
  Widget _buildLabeledField(String label, TextEditingController c, {String? hint, TextInputType? keyboard, bool requiredField = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4), // Giảm khoảng cách
        TextFormField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: AppColors.background, // Màu nền nhẹ hơn
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), // Bo góc nhẹ nhàng hơn
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5), // Viền focus nổi bật
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          validator: (v) {
            if (requiredField && (v == null || v.trim().isEmpty)) return 'Vui lòng nhập $label';
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Đặt màu nền chung
      appBar: AppBar(
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            fontSize: 18, // Tăng kích thước chữ AppBar
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.card, // AppBar màu trắng
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5, // Thêm một chút bóng nhẹ
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check, color: AppColors.primary, size: 20),
            label: const Text('Lưu', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarSection(), // Avatar mới, thu gọn
                    _buildInfoSection(), // Thông tin mới, gộp Ngày sinh/Giới tính
                    _buildAddressAction(), // Nút Quản lý sổ địa chỉ
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}