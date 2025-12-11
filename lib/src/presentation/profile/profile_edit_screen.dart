import 'package:flutter/material.dart';
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
      _nameCtrl.text = user['name']?.toString() ?? current.name;
      _emailCtrl.text = user['email']?.toString() ?? current.email;
      _mobileCtrl.text = user['mobile']?.toString() ?? current.mobile;
      _ngaysinhCtrl.text = user['ngaysinh']?.toString() ?? '';
      _gioiTinhCtrl.text = user['gioi_tinh']?.toString() ?? '';
      _diaChiCtrl.text = user['dia_chi']?.toString() ?? '';
      
    
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
    final ok = await _api.updateUserProfile(
      userId: _user!.userId,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      ngaysinh: _ngaysinhCtrl.text.trim(),
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

  // Widget mới: Thẻ Avatar nhỏ gọn, hiện đại (thu hẹp)
  Widget _buildAvatarSection() {
    final avatarUrl = _user?.avatar;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0), // Giảm chiều cao khu vực
        child: Stack(
          children: [
            CircleAvatar(
              radius: 32, // Giảm kích thước
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
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _uploadingAvatar
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt, color: Colors.white, size: 14), // Giảm kích thước icon
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
                child: _buildLabeledField('Ngày sinh', _ngaysinhCtrl, hint: 'dd/mm/yyyy'),
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
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null || _user == null) return;
      setState(() { _uploadingAvatar = true; });
      final bytes = await picked.readAsBytes();
      final String filename = picked.name;
      final String contentType = filename.toLowerCase().endsWith('.png') ? 'image/png' : (filename.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      final uploadedPath = await _api.uploadAvatar(userId: _user!.userId, bytes: bytes, filename: filename, contentType: contentType);
      if (!mounted) return;
      setState(() { _uploadingAvatar = false; });
      if (uploadedPath != null && uploadedPath.isNotEmpty) {
        final updated = _user!.copyWith(avatar: uploadedPath);
        await _auth.updateUser(updated);
        setState(() { _user = updated; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật avatar thành công'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật avatar thất bại'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _uploadingAvatar = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
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