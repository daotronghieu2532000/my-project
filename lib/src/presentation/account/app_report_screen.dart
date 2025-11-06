import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

class AppReportScreen extends StatefulWidget {
  const AppReportScreen({super.key});

  @override
  State<AppReportScreen> createState() => _AppReportScreenState();
}

class _AppReportScreenState extends State<AppReportScreen> {
  final _apiService = ApiService();
  final _authService = AuthService();
  final _descriptionController = TextEditingController();
  
  final List<File> _selectedImages = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1200,
      imageQuality: 85,
    );
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    List<String> uploadedUrls = [];
    
    try {
      final token = await _apiService.getValidToken();
      if (token == null) {
        print('❌ Không có token');
        return [];
      }

      for (var image in _selectedImages) {
        try {
          final url = Uri.parse('https://api.socdo.vn/v1/app_report');
          final request = http.MultipartRequest('POST', url);
          request.headers['Authorization'] = 'Bearer $token';
          request.fields['action'] = 'upload_image';
          
          // Get filename from path
          final filename = image.path.split('/').last;
          final extension = filename.split('.').last.toLowerCase();
          final contentType = 'image/${extension == 'jpg' ? 'jpeg' : extension}';
          
          final file = await http.MultipartFile.fromPath(
            'image',
            image.path,
            filename: 'report_${DateTime.now().millisecondsSinceEpoch}.$extension',
            contentType: MediaType.parse(contentType),
          );
          request.files.add(file);

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true && data['data'] != null) {
              final imageUrl = data['data']['image_url'] as String?;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                uploadedUrls.add(imageUrl);
                print('✅ Upload success: $imageUrl');
              }
            }
          } else {
            print('❌ Upload failed: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('❌ Lỗi upload image: $e');
        }
      }
    } catch (e) {
      print('❌ Lỗi: $e');
    }

    print('📤 Total uploaded: ${uploadedUrls.length}/${_selectedImages.length} images');
    return uploadedUrls;
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mô tả lỗi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = await _authService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload images
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages();
      }

      // Get device info
      String? deviceInfo;
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        if (Theme.of(context).platform == TargetPlatform.android) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceInfo = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Theme.of(context).platform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceInfo = '${iosInfo.name} ${iosInfo.model}';
        }
      } catch (e) {
        deviceInfo = 'Unknown device';
      }

      // Get app version
      String? appVersion;
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (e) {
        appVersion = 'Unknown';
      }

      final result = await _apiService.submitAppReport(
        userId: user.userId,
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
        deviceInfo: deviceInfo,
        appVersion: appVersion,
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cảm ơn bạn! Chúng tôi đã nhận được báo lỗi và sẽ xem xét sớm nhất.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['message'] ?? 'Gửi báo lỗi thất bại'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Báo lỗi cho chúng tôi',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              
              // Title
              const Text(
                'Báo lỗi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mô tả chi tiết để chúng tôi khắc phục',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Description
              const Text(
                'Mô tả lỗi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Lỗi xảy ra khi thanh toán...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2196F3)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Images section
              const Text(
                'Ảnh minh họa (tùy chọn)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              
              // Image grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Show selected images
                  ...List.generate(_selectedImages.length, (index) {
                    return SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Add button (max 9 images)
                  if (_selectedImages.length < 9)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF2196F3), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, size: 32, color: Color(0xFF2196F3)),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Gửi báo lỗi',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
