import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Service để track và lưu affiliate ID từ deep links
class AffiliateTrackingService {
  static const String _keyAffiliateId = 'affiliate_id';
  static const String _keyAffiliateTimestamp = 'affiliate_timestamp';
  static const String _keyAffiliateProductId = 'affiliate_product_id';
  
  // Cookie tracking duration: 30 days (in milliseconds)
  static const int _affiliateCookieDuration = 30 * 24 * 60 * 60 * 1000;

  /// Lưu affiliate ID khi user click vào affiliate link
  /// [affiliateId]: User ID của người chia sẻ affiliate link
  /// [productId]: Product ID (optional, để track xem user xem sản phẩm nào)
  Future<void> trackAffiliateClick({
    required String affiliateId,
    int? productId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(_keyAffiliateId, affiliateId);
      await prefs.setInt(_keyAffiliateTimestamp, now);
      
      if (productId != null) {
        await prefs.setInt(_keyAffiliateProductId, productId);
      }
    } catch (e) {
      print('❌ [AffiliateTracking] Lỗi lưu affiliate: $e');
    }
  }

  /// Lấy affiliate ID hiện tại (nếu còn valid trong 30 ngày)
  Future<String?> getAffiliateId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final affiliateId = prefs.getString(_keyAffiliateId);
      final timestamp = prefs.getInt(_keyAffiliateTimestamp);
      
      if (affiliateId == null || timestamp == null) {
        return null;
      }
      
      // Check if affiliate tracking is still valid (30 days)
      final now = DateTime.now().millisecondsSinceEpoch;
      final isValid = (now - timestamp) < _affiliateCookieDuration;
      
      if (!isValid) {
        // Clear expired affiliate tracking
        await clearAffiliateTracking();
        return null;
      }
      
      return affiliateId;
    } catch (e) {
      print('❌ [AffiliateTracking] Lỗi lấy affiliate_id: $e');
      return null;
    }
  }

  /// Check xem affiliate tracking có còn valid không
  Future<bool> hasValidAffiliateTracking() async {
    final affiliateId = await getAffiliateId();
    return affiliateId != null;
  }

  /// Lấy product ID đã track (nếu có)
  Future<int?> getTrackedProductId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyAffiliateProductId);
    } catch (e) {
      return null;
    }
  }

  /// Clear affiliate tracking (sau khi đã tạo order thành công)
  Future<void> clearAffiliateTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAffiliateId);
      await prefs.remove(_keyAffiliateTimestamp);
      await prefs.remove(_keyAffiliateProductId);
      
    } catch (e) {
      print('❌ [AffiliateTracking] Lỗi clear affiliate: $e');
    }
  }

  /// Track affiliate view (khi user xem sản phẩm từ affiliate link)
  /// Nếu có affiliate_id đã lưu, sẽ track lại để update timestamp
  Future<void> trackAffiliateView({int? productId}) async {
    try {
      final affiliateId = await getAffiliateId();
      if (affiliateId != null && productId != null) {
        // Update product_id và refresh timestamp
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyAffiliateProductId, productId);
        await prefs.setInt(_keyAffiliateTimestamp, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      print('❌ [AffiliateTracking] Lỗi track view: $e');
    }
  }
}

