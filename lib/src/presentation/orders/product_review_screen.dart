import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

class ProductReviewScreen extends StatefulWidget {
  final int orderId;
  final List<Map<String, dynamic>> products;
  final Function()? onReviewSubmitted;

  const ProductReviewScreen({
    super.key,
    required this.orderId,
    required this.products,
    this.onReviewSubmitted,
  });

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, int> _ratings = {};
  final Map<int, List<String>> _images = {};
  final Map<int, bool> _loading = {};
  final Map<int, bool?> _matchesDescription = {};
  final Map<int, bool?> _isSatisfied = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    for (var product in widget.products) {
      final productId = product['id'] as int;
      _controllers[productId] = TextEditingController();
      _ratings[productId] = 5;
      _images[productId] = [];
      _loading[productId] = false;
      _matchesDescription[productId] = null;
      _isSatisfied[productId] = null;
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(int productId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final mimeType = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final dataUri = 'data:image/$mimeType;base64,$base64Image';
        
        setState(() {
          _images[productId]?.add(dataUri);
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

  void _removeImage(int productId, int index) {
    setState(() {
      _images[productId]?.removeAt(index);
    });
  }

  Future<void> _submitReview(int productId, Map<String, dynamic> product) async {
    final controller = _controllers[productId];
    final rating = _ratings[productId] ?? 5;
    final content = controller?.text.trim() ?? '';

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chia sẻ trải nghiệm')),
      );
      return;
    }

    setState(() {
      _loading[productId] = true;
    });

    try {
      final user = await _auth.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng đăng nhập')),
          );
        }
        return;
      }

      // Get shop_id from product data - try both 'shop' and 'shop_id' fields
      final shopId = (product['shop_id'] as int?) ?? 
                     (product['shop'] as int?) ?? 
                     0;
      
      // Get variant_id from product data
      final variantId = product['variant_id'] as int?;
      
      final result = await _api.submitProductReview(
        userId: user.userId,
        productId: productId,
        shopId: shopId,
        content: content,
        rating: rating,
        variantId: variantId != null && variantId > 0 ? variantId : null,
        orderId: widget.orderId,
        images: _images[productId]?.isNotEmpty == true ? _images[productId] : null,
        matchesDescription: _matchesDescription[productId],
        isSatisfied: _isSatisfied[productId],
      );

      if (!mounted) return;

      if (result?['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đánh giá thành công')),
        );
        widget.onReviewSubmitted?.call();
        Navigator.pop(context);
      } else {
        // Log debug info nếu có
        if (result?['debug'] != null) {
          print('❌ Review Error Debug Info:');
          print('   ${jsonEncode(result?['debug'])}');
        }
        
        final errorMessage = result?['message'] ?? 'Có lỗi xảy ra';
        final debugInfo = result?['debug'] != null 
            ? '\n\nDebug: ${jsonEncode(result?['debug'])}' 
            : '';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage$debugInfo'),
            duration: const Duration(seconds: 5),
          ),
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
        setState(() {
          _loading[productId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Đánh giá sản phẩm',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
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
        children: widget.products.map((product) {
          final productId = product['id'] as int;
          final productName = product['name'] ?? '';
          final productImage = product['image'] ?? '';
          final color = product['color'] ?? '';
          final size = product['size'] ?? '';
          final fixedImage = productImage.startsWith('http')
              ? productImage
              : (productImage.isEmpty ? '' : 'https://socdo.vn$productImage');

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product info - tên và biến thể riêng biệt
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
                          if (color.isNotEmpty || size.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              [color, size].where((e) => e.toString().isNotEmpty).join(' • '),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Rating stars - compact
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
                      final isSelected = (_ratings[productId] ?? 5) >= starRating;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _ratings[productId] = starRating;
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
                
                // Checkbox: Đúng với mô tả
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
                      productId,
                      'matches',
                      true,
                      'Đúng',
                      _matchesDescription[productId] == true,
                    ),
                    const SizedBox(width: 12),
                    _buildCheckboxOption(
                      productId,
                      'matches',
                      false,
                      'Không đúng',
                      _matchesDescription[productId] == false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Checkbox: Hài lòng sản phẩm
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
                      productId,
                      'satisfied',
                      true,
                      'Hài lòng',
                      _isSatisfied[productId] == true,
                    ),
                    const SizedBox(width: 12),
                    _buildCheckboxOption(
                      productId,
                      'satisfied',
                      false,
                      'Chưa hài lòng',
                      _isSatisfied[productId] == false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
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
                  controller: _controllers[productId],
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
                
                // Images - compact
                if ((_images[productId]?.length ?? 0) > 0 || (_images[productId]?.length ?? 0) < 5)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...(_images[productId] ?? []).asMap().entries.map((entry) {
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
                                        image,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: GestureDetector(
                                onTap: () => _removeImage(productId, index),
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
                      if ((_images[productId]?.length ?? 0) < 5)
                        GestureDetector(
                          onTap: () => _pickImage(productId),
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
                
                // Submit button - simple
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: (_loading[productId] == true)
                        ? null
                        : () => _submitReview(productId, product),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _loading[productId] == true
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Gửi đánh giá',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCheckboxOption(
    int productId,
    String type,
    bool value,
    String label,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (type == 'matches') {
            _matchesDescription[productId] = isSelected ? null : value;
          } else if (type == 'satisfied') {
            _isSatisfied[productId] = isSelected ? null : value;
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
