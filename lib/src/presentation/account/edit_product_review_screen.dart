import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

class EditProductReviewScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> review;
  final int reviewId;
  final Function()? onReviewUpdated;

  const EditProductReviewScreen({
    super.key,
    required this.product,
    required this.review,
    required this.reviewId,
    this.onReviewUpdated,
  });

  @override
  State<EditProductReviewScreen> createState() => _EditProductReviewScreenState();
}

class _EditProductReviewScreenState extends State<EditProductReviewScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  late TextEditingController _contentController;
  int _rating = 5;
  int? _deliveryRating;
  int? _shopRating;
  List<String> _images = [];
  bool _loading = false;
  bool? _matchesDescription;
  bool? _isSatisfied;
  String? _willBuyAgain;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.review['content'] ?? '');
    _rating = widget.review['rating'] as int? ?? 5;
    _deliveryRating = widget.review['delivery_rating'] as int?;
    _shopRating = widget.review['shop_rating'] as int?;
    _matchesDescription = widget.review['matches_description'] as bool?;
    _isSatisfied = widget.review['is_satisfied'] as bool?;
    _willBuyAgain = widget.review['will_buy_again'] as String?;
    
    // Load existing images
    final reviewImages = widget.review['images'] as List?;
    if (reviewImages != null && reviewImages.isNotEmpty) {
      _images = reviewImages.map((img) => img.toString()).toList();
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        final List<String> newImages = [];
        for (var image in images) {
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final mimeType = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
          final dataUri = 'data:image/$mimeType;base64,$base64Image';
          newImages.add(dataUri);
        }
        
        setState(() {
          final remainingSlots = 5 - _images.length;
          if (remainingSlots > 0) {
            _images.addAll(newImages.take(remainingSlots));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _updateReview() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chia sẻ trải nghiệm')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await _auth.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng đăng nhập')),
          );
          setState(() => _loading = false);
        }
        return;
      }

      final result = await _api.updateProductReview(
        commentId: widget.reviewId,
        userId: user.userId,
        content: _contentController.text.trim(),
        rating: _rating,
        deliveryRating: _deliveryRating,
        shopRating: _shopRating,
        matchesDescription: _matchesDescription,
        isSatisfied: _isSatisfied,
        willBuyAgain: _willBuyAgain,
        images: _images.isNotEmpty ? _images : null,
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Cập nhật đánh giá thành công'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onReviewUpdated?.call();
        Navigator.pop(context);
      } else {
        final errorMessage = result?['message'] ?? 'Có lỗi xảy ra';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['name'] ?? '';
    final productImage = widget.product['image'] ?? '';
    final color = widget.product['color'] ?? '';
    final size = widget.product['size'] ?? '';
    final variantName = widget.product['variant_name'] ?? '';
    final shopName = widget.product['shop_name'] ?? '';
    final fixedImage = productImage.startsWith('http')
        ? productImage
        : (productImage.isEmpty ? '' : 'https://socdo.vn$productImage');
    
    // Tạo text phân loại: ưu tiên variant_name, sau đó từ color/size
    final variantDisplay = variantName.isNotEmpty 
        ? variantName 
        : [color, size].where((e) => e.toString().isNotEmpty).join(' • ');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sửa đánh giá',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      fixedImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[100],
                        child: Icon(Icons.image_not_supported, size: 24, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (variantDisplay.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text(
                                'Phân loại: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                variantDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (shopName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.store, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  shopName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Rating stars
              Row(
                children: [
                  const Text(
                    'Đánh giá',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ...List.generate(5, (index) {
                    final starRating = index + 1;
                    final isSelected = _rating >= starRating;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _rating = starRating;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: isSelected ? Colors.amber[700] : Colors.grey[300],
                          size: 24,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              
              // Đánh giá tốc độ giao hàng
              if (widget.review['delivery_rating'] != null)
                Row(
                  children: [
                    const Text(
                      'Tốc độ giao hàng',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...List.generate(5, (index) {
                      final starRating = index + 1;
                      final isSelected = (_deliveryRating ?? 0) >= starRating;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _deliveryRating = starRating;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            isSelected ? Icons.star : Icons.star_border,
                            color: isSelected ? Colors.amber[700] : Colors.grey[300],
                            size: 20,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              if (widget.review['delivery_rating'] != null) const SizedBox(height: 16),
              
              // Đánh giá shop
              if (widget.review['shop_rating'] != null)
                Row(
                  children: [
                    const Text(
                      'Đánh giá shop',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...List.generate(5, (index) {
                      final starRating = index + 1;
                      final isSelected = (_shopRating ?? 0) >= starRating;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _shopRating = starRating;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            isSelected ? Icons.star : Icons.star_border,
                            color: isSelected ? Colors.amber[700] : Colors.grey[300],
                            size: 20,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              if (widget.review['shop_rating'] != null) const SizedBox(height: 16),
              
              // Checkbox: Đúng với mô tả
              if (widget.review['matches_description'] != null) ...[
                Row(
                  children: [
                    const Text(
                      'Đúng với mô tả',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildCheckboxOption(
                      'matches',
                      true,
                      'Đúng',
                      _matchesDescription == true,
                    ),
                    const SizedBox(width: 12),
                    _buildCheckboxOption(
                      'matches',
                      false,
                      'Không đúng',
                      _matchesDescription == false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              // Checkbox: Hài lòng sản phẩm
              if (widget.review['is_satisfied'] != null) ...[
                Row(
                  children: [
                    const Text(
                      'Hài lòng sản phẩm',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildCheckboxOption(
                      'satisfied',
                      true,
                      'Hài lòng',
                      _isSatisfied == true,
                    ),
                    const SizedBox(width: 12),
                    _buildCheckboxOption(
                      'satisfied',
                      false,
                      'Chưa hài lòng',
                      _isSatisfied == false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              // Checkbox: Sẽ quay lại mua
              if (widget.review['will_buy_again'] != null) ...[
                Row(
                  children: [
                    const Text(
                      'Sẽ quay lại mua',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildCheckboxOption(
                      'will_buy',
                      'yes',
                      'Có',
                      _willBuyAgain == 'yes',
                    ),
                    const SizedBox(width: 12),
                    _buildCheckboxOption(
                      'will_buy',
                      'no',
                      'Không',
                      _willBuyAgain == 'no',
                    ),
                    const SizedBox(width: 12),
                    _buildCheckboxOption(
                      'will_buy',
                      'maybe',
                      'Sẽ cân nhắc',
                      _willBuyAgain == 'maybe',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              
              // Review text input
              const Text(
                'Vui lòng chia sẻ trải nghiệm',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                maxLines: 4,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Chia sẻ trải nghiệm của bạn...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              
              // Images
              if (_images.isNotEmpty || _images.length < 5)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._images.asMap().entries.map((entry) {
                      final index = entry.key;
                      final image = entry.value;
                      return Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: image.startsWith('data:image/')
                                  ? Image.memory(
                                      base64Decode(image.split(',')[1]),
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      image.startsWith('http') ? image : 'https://socdo.vn$image',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image_not_supported, size: 24),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    if (_images.length < 5)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                            color: Colors.grey[50],
                          ),
                          child: Icon(
                            Icons.add_photo_alternate,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              
              // Update button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _loading ? null : _updateReview,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Cập nhật đánh giá',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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

  Widget _buildCheckboxOption(
    String type,
    dynamic value,
    String label,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (type == 'matches') {
            _matchesDescription = isSelected ? null : (value as bool);
          } else if (type == 'satisfied') {
            _isSatisfied = isSelected ? null : (value as bool);
          } else if (type == 'will_buy') {
            _willBuyAgain = isSelected ? null : (value as String);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.grey[300]!,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

