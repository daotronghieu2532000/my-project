import 'dart:convert';
import 'package:flutter/material.dart';

class ReviewImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ReviewImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ReviewImageViewer> createState() => _ReviewImageViewerState();
}

class _ReviewImageViewerState extends State<ReviewImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // PageView để swipe giữa các ảnh
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final imageUrl = widget.images[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                child: Center(
                  child: imageUrl.startsWith('data:image/')
                      ? Image.memory(
                          base64Decode(imageUrl.split(',')[1]),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Không thể tải ảnh',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Không thể tải ảnh',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              );
            },
          ),
          // Nút đóng
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Hiển thị số ảnh (ví dụ: 1/5)
          if (widget.images.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

