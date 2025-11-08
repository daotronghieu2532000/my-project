import 'package:flutter/material.dart';

class ProductCarousel extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final double height;
  final double itemWidth;
  final double spacing;

  const ProductCarousel({
    super.key,
    required this.title,
    required this.children,
    this.height = 160,
    this.itemWidth = 280,
    this.spacing = 12,
  });

  @override
  State<ProductCarousel> createState() => _ProductCarouselState();
}

class _ProductCarouselState extends State<ProductCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  int _itemsPerPage = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _calculateItemsPerPage();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _calculateItemsPerPage() {
    // Hiển thị 2 sản phẩm mỗi màn hình ngang
    _itemsPerPage = 2;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalPages = (widget.children.length / _itemsPerPage).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header với title và navigation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (totalPages > 1) ...[
              Row(
                children: [
                  // Previous button
                  GestureDetector(
                    onTap: _currentPage > 0 ? _previousPage : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _currentPage > 0 ? Colors.grey[200] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentPage > 0 ? Colors.grey[300]! : Colors.grey[200]!,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: _currentPage > 0 ? Colors.grey[700] : Colors.grey[400],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Page indicator
                  Text(
                    '${_currentPage + 1}/$totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Next button
                  GestureDetector(
                    onTap: _currentPage < totalPages - 1 ? _nextPage : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _currentPage < totalPages - 1 ? Colors.grey[200] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentPage < totalPages - 1 ? Colors.grey[300]! : Colors.grey[200]!,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: _currentPage < totalPages - 1 ? Colors.grey[700] : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Carousel content
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: totalPages,
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * _itemsPerPage;
              final endIndex = (startIndex + _itemsPerPage).clamp(0, widget.children.length);
              final pageItems = widget.children.sublist(startIndex, endIndex);

              if (pageItems.isEmpty) {
                return const SizedBox.shrink();
              }

              // Hiển thị 2 sản phẩm cạnh nhau
              // Sử dụng LayoutBuilder để lấy width thực tế từ PageView
              return LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  // Padding: 4px mỗi bên = 8px tổng
                  // Spacing giữa 2 cards: 8px
                  // cardWidth = (availableWidth - 8 - 8) / 2 = (availableWidth - 16) / 2
                  final cardWidth = (availableWidth - 16) / 2;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Căn trên cùng để cards cùng height
                      mainAxisSize: MainAxisSize.min, // Quan trọng: không expand
                      children: pageItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Container(
                          width: cardWidth, // Width cố định - đảm bảo cả 2 cards cùng width
                          margin: EdgeInsets.only(right: index < pageItems.length - 1 ? 8 : 0),
                          child: item,
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _nextPage() {
    if (_currentPage < (widget.children.length / _itemsPerPage).ceil() - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}