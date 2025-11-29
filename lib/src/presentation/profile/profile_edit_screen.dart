import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user.dart';
import 'package:image_picker/image_picker.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
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
                    _buildAvatarCard(),
                    const SizedBox(height: 12),
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarRow() {
    final avatarUrl = _user?.avatar;
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(_auth.getAvatarUrl(avatarUrl))
              : const AssetImage('lib/src/core/assets/images/user_default.png') as ImageProvider,
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _uploadingAvatar ? null : _pickAndUploadAvatar,
          icon: _uploadingAvatar
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.edit, size: 16),
          label: const Text('Đổi ảnh đại diện'),
        )
      ],
    );
  }

  Widget _buildAvatarCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildAvatarRow(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thông tin cơ bản', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildLabeledField('Họ và tên', _nameCtrl, requiredField: true, hint: 'Nhập họ và tên'),
          const SizedBox(height: 10),
          _buildLabeledField('Email', _emailCtrl, keyboard: TextInputType.emailAddress, hint: 'example@mail.com'),
          const SizedBox(height: 10),
          _buildLabeledField('Số điện thoại', _mobileCtrl, keyboard: TextInputType.phone, hint: '098xxxxxxx'),
          const SizedBox(height: 10),
          _buildLabeledField('Ngày sinh', _ngaysinhCtrl, hint: 'dd/mm/yyyy'),
          const SizedBox(height: 10),
          _buildLabeledField('Giới tính', _gioiTinhCtrl, hint: 'nam/nữ'),
          const SizedBox(height: 10),
          _buildLabeledField('Địa chỉ', _diaChiCtrl, maxLines: 3, hint: 'Số nhà, đường, phường/xã, quận/huyện, tỉnh/thành'),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed('/profile/address'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFEAEAEA)),
            ),
            child: const Text('Quản lý sổ địa chỉ', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
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

  Widget _buildLabeledField(String label, TextEditingController c, {String? hint, TextInputType? keyboard, bool requiredField = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D))),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1890FF)),
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
}


