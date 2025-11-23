import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChipItem extends StatefulWidget {
  final String label;
  final String? imageUrl;
  final VoidCallback? onTap;
  const ChipItem({
    super.key, 
    required this.label,
    this.imageUrl,
    this.onTap,
  });

  @override
  State<ChipItem> createState() => _ChipItemState();
}

class _ChipItemState extends State<ChipItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _animationController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered 
                        ? primaryColor.withOpacity(0.08)
                        : Colors.black.withOpacity(0.03),
                      blurRadius: _elevationAnimation.value * 0.5,
                      offset: Offset(0, _elevationAnimation.value * 0.3),
                    ),
                  ],
                  border: Border.all(
                    color: _isHovered 
                      ? primaryColor.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.08),
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: _isHovered 
                            ? LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.08),
                                  primaryColor.withOpacity(0.03),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildCategoryImage(),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                          color: _isHovered ? primaryColor : Colors.grey[700],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryImage() {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      // Build URL đầy đủ với domain socdo.vn
      String fullImageUrl = widget.imageUrl!;
      if (!fullImageUrl.startsWith('http')) {
        if (fullImageUrl.startsWith('/')) {
          fullImageUrl = 'https://socdo.vn$fullImageUrl';
        } else {
          fullImageUrl = 'https://socdo.vn/$fullImageUrl';
        }
      }
      
      return CachedNetworkImage(
        imageUrl: fullImageUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey[100]!,
                Colors.grey[50]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[100]!,
                  Colors.grey[50]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.category_outlined, 
              color: Colors.grey[400],
              size: 32,
            ),
          );
        },
      );
    }
    
    // Fallback icon
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[100]!,
            Colors.grey[50]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.category_outlined, 
        color: Colors.grey[400],
        size: 32,
      ),
    );
  }
}
