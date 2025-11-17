import 'package:flutter/material.dart';
import '../../../core/models/banner.dart';
import '../../../core/services/api_service.dart';

class PartnerBannerSection extends StatefulWidget {
  const PartnerBannerSection({super.key});

  @override
  State<PartnerBannerSection> createState() => _PartnerBannerSectionState();
}

class _PartnerBannerSectionState extends State<PartnerBannerSection> {
  final ApiService _apiService = ApiService();
  List<BannerModel> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await _apiService.getBanners(
        position: 'banner_doitac',
        limit: 5,
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Đối tác',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return GestureDetector(
                  onTap: () {
                    if (banner.link.isNotEmpty) {
                    }
                  },
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        banner.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

