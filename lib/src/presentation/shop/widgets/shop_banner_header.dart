import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/shop_detail.dart';
import '../shop_search_results_screen.dart';

class ShopBannerHeader extends StatefulWidget {
  final ShopInfo shopInfo;
  final VoidCallback? onBack;
  final VoidCallback? onCart;
  final VoidCallback? onChat;
  final Function(String)? onSearch;

  const ShopBannerHeader({
    super.key,
    required this.shopInfo,
    this.onBack,
    this.onCart,
    this.onChat,
    this.onSearch,
  });

  @override
  State<ShopBannerHeader> createState() => _ShopBannerHeaderState();
}

class _ShopBannerHeaderState extends State<ShopBannerHeader> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchInput = false;
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {}); // Rebuild để update suffixIcon
  }

  void _toggleSearch() {
    setState(() {
      _showSearchInput = !_showSearchInput;
      if (_showSearchInput) {
        // Focus vào input khi hiển thị
        Future.delayed(const Duration(milliseconds: 100), () {
          _searchFocusNode.requestFocus();
        });
      } else {
        // Clear search khi ẩn
        _debounceTimer?.cancel();
        _searchController.clear();
        if (widget.onSearch != null) {
          widget.onSearch!('');
        }
      }
    });
  }

  void _onSearchChanged(String value) {
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Debounce: chỉ search sau 500ms khi user ngừng gõ
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Nếu có từ khóa, điều hướng đến màn hình kết quả tìm kiếm
      if (value.trim().isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShopSearchResultsScreen(
              shopId: widget.shopInfo.shopId,
              shopName: widget.shopInfo.name,
              searchKeyword: value.trim(),
            ),
          ),
        );
      }
      
      // Vẫn gọi callback nếu có (để tương thích với code cũ)
      if (widget.onSearch != null) {
        widget.onSearch!(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Banner image - dính lên đỉnh trang, giữ tỷ lệ ảnh 480x160
        // Height tự động điều chỉnh khi search input hiển thị
        Container(
          // height: _showSearchInput ? 260 : 200,
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/banner-shop2.png'),
              fit: BoxFit.fitWidth, // Giữ tỷ lệ ảnh, không phóng to
              alignment: Alignment.topCenter, // Căn lên trên
            ),
          ),
        ),
        // Gradient overlay để text dễ đọc
        Container(
          height: _showSearchInput ? 260 : 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),
        // Nút back và icon giỏ hàng màu trắng ở trên cùng
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              children: [
                // Row 1: Back button và action buttons
                Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                      onPressed: widget.onBack ?? () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  iconSize: 24,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon search với border và chữ
                    _buildActionButton(
                      icon: _showSearchInput ? Icons.close : Icons.search,
                      label: 'Tìm kiếm',
                      onPressed: _toggleSearch,
                    ),
                    const SizedBox(width: 8),
                    // Icon chat với border và chữ
                    if (widget.onChat != null) ...[
                      _buildActionButton(
                        icon: Icons.chat,
                        label: 'Chat',
                        onPressed: widget.onChat!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Icon giỏ hàng với border và chữ
                    _buildActionButton(
                      icon: Icons.shopping_cart,
                      label: 'Giỏ hàng',
                      onPressed: widget.onCart ?? () {},
                    ),
                  ],
                ),
                  ],
                ),
                // Row 2: Search input (hiển thị khi _showSearchInput = true)
                if (_showSearchInput)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        onSubmitted: (value) {
                          // Khi nhấn Enter, điều hướng ngay lập tức
                          _debounceTimer?.cancel();
                          if (value.trim().isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShopSearchResultsScreen(
                                  shopId: widget.shopInfo.shopId,
                                  shopName: widget.shopInfo.name,
                                  searchKeyword: value.trim(),
                                ),
                              ),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm sản phẩm trong shop ${widget.shopInfo.name}',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                ),
              ],
            ),
          ),
        ),
        // Shop info overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: widget.shopInfo.avatarUrl.isNotEmpty
                        ? Image.network(
                            widget.shopInfo.avatarUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/shop.jpg',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/images/shop.jpg',
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Shop Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.shopInfo.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '4.9',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${widget.shopInfo.totalProducts} Sản phẩm',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.shopInfo.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.shopInfo.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
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
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

