import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/models/banner.dart';
import '../../../core/services/api_service.dart';

class MobileBannerSection extends StatefulWidget {
  const MobileBannerSection({super.key});

  @override
  State<MobileBannerSection> createState() => _MobileBannerSectionState();
}

class _MobileBannerSectionState extends State<MobileBannerSection> {
  final ApiService _apiService = ApiService();
  List<BannerModel> _banners = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await _apiService.getBanners(
        position: 'banner_index_mobile',
        limit: 10,
      );
      
      if (mounted && banners != null) {
        setState(() {
          _banners = banners;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
     
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 295,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 295,
      width: double.infinity,
      child: Stack(
        children: [
          CarouselSlider.builder(
            itemCount: _banners.length,
            itemBuilder: (context, index, realIndex) {
              final banner = _banners[index];
              return GestureDetector(
                onTap: () {
                  if (banner.link.isNotEmpty) {
                    // TODO: Navigate to link
                  
                  }
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                  ),
                  child: Image.network(
                    banner.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: 295,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 3),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              enlargeCenterPage: false,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
          // Pagination dots
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _banners.asMap().entries.map((entry) {
                return Container(
                  width: _currentIndex == entry.key ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == entry.key
                        ? Colors.red
                        : Colors.white.withOpacity(0.6),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

