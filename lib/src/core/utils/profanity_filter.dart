/// Bộ lọc từ ngữ thô tục/phản cảm
/// Client-side filter để lọc nội dung UGC
class ProfanityFilter {
  // Danh sách từ ngữ cần lọc (có thể mở rộng)
  static final List<String> _profanityWords = [
    // Từ ngữ thô tục tiếng Việt (ví dụ)
    'địt', 'đụ', 'lồn', 'buồi', 'cặc', 'đéo', 'mẹ', 'má', 'đm', 'dm',
    // Từ ngữ thô tục tiếng Anh
    'fuck', 'shit', 'damn', 'bitch', 'asshole', 'bastard',
    // Có thể thêm nhiều hơn
  ];

  /// Kiểm tra xem text có chứa từ ngữ thô tục không
  static bool containsProfanity(String text) {
    final lowerText = text.toLowerCase();
    for (final word in _profanityWords) {
      if (lowerText.contains(word.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Lọc và thay thế từ ngữ thô tục bằng dấu *
  static String filterProfanity(String text) {
    String filtered = text;
    for (final word in _profanityWords) {
      final regex = RegExp(word, caseSensitive: false);
      filtered = filtered.replaceAll(regex, '*' * word.length);
    }
    return filtered;
  }

  /// Kiểm tra và lọc nội dung, trả về text đã lọc và có chứa profanity không
  static Map<String, dynamic> checkAndFilter(String text) {
    final contains = containsProfanity(text);
    final filtered = contains ? filterProfanity(text) : text;
    
    return {
      'containsProfanity': contains,
      'filteredText': filtered,
      'originalText': text,
    };
  }
}

