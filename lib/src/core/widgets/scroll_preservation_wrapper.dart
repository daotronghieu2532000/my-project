import 'package:flutter/material.dart';
import '../../core/services/app_lifecycle_manager.dart';

/// Widget wrapper để lưu trữ và khôi phục vị trí scroll
class ScrollPreservationWrapper extends StatefulWidget {
  final Widget child;
  final int tabIndex;
  final ScrollController? scrollController;

  const ScrollPreservationWrapper({
    super.key,
    required this.child,
    required this.tabIndex,
    this.scrollController,
  });

  @override
  State<ScrollPreservationWrapper> createState() => _ScrollPreservationWrapperState();
}

class _ScrollPreservationWrapperState extends State<ScrollPreservationWrapper> {
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager();
  ScrollController? _scrollController;
  bool _hasRestoredScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _restoreScrollPosition();
  }

  @override
  void dispose() {
    // Lưu vị trí scroll trước khi dispose
    _saveScrollPosition();
    super.dispose();
  }

  /// Khôi phục vị trí scroll đã lưu
  Future<void> _restoreScrollPosition() async {
    if (_hasRestoredScroll) {
      return;
    }
    
    try {
      final savedPosition = await _lifecycleManager.getSavedScrollPosition(widget.tabIndex);
      if (savedPosition != null && savedPosition > 0) {
        // Đợi một chút để đảm bảo widget đã được build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController!.hasClients) {
            _scrollController!.animateTo(
              savedPosition,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
          }
        });
      } else {
      }
      _hasRestoredScroll = true;
    } catch (e) {
    }
  }

  /// Lưu vị trí scroll hiện tại
  void _saveScrollPosition() {
    if (_scrollController!.hasClients) {
      final position = _scrollController!.offset;
      if (position > 0) {
        _lifecycleManager.saveScrollPosition(widget.tabIndex, position);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Lưu vị trí scroll khi người dùng scroll
        if (notification is ScrollUpdateNotification) {
          _saveScrollPosition();
        }
        return false;
      },
      child: widget.child,
    );
  }
}
