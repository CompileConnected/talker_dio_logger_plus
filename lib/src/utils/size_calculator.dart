import 'dart:convert';

/// Size calculation and formatting utilities
class SizeCalculator {
  /// Default threshold for truncation (100KB)
  ///
  /// Why 100KB: This is a balance between showing enough data for debugging
  /// while preventing UI lag from rendering very large payloads. Most API
  /// responses that need inspection are under this threshold.
  static const int defaultTruncateThreshold = 100 * 1024;

  /// Default maximum size for display (1MB)
  ///
  /// Why 1MB: Responses larger than this typically indicate binary data,
  /// file downloads, or malformed responses. Displaying them would cause
  /// significant memory and rendering issues.
  static const int defaultMaxDisplaySize = 1024 * 1024;

  /// Default image preview threshold (500KB)
  ///
  /// Why 500KB: Images under this size can be decoded and displayed in-line
  /// without noticeable lag. Larger images should be viewed in a separate
  /// screen with proper memory management.
  static const int defaultImagePreviewThreshold = 500 * 1024;

  /// Calculate size of data in bytes
  static int calculateSize(dynamic data) {
    if (data == null) return 0;

    if (data is String) {
      return utf8.encode(data).length;
    }

    if (data is List<int>) {
      return data.length;
    }

    if (data is Map || data is List) {
      try {
        final jsonString = const JsonEncoder().convert(data);
        return utf8.encode(jsonString).length;
      } catch (_) {
        return data.toString().length;
      }
    }

    return data.toString().length;
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Check if data should be truncated
  static bool shouldTruncate(dynamic data, {int? threshold}) {
    final actualThreshold = threshold ?? defaultTruncateThreshold;
    return calculateSize(data) > actualThreshold;
  }

  /// Check if data is too large for display
  static bool isTooLargeForDisplay(dynamic data, {int? maxSize}) {
    final actualMaxSize = maxSize ?? defaultMaxDisplaySize;
    return calculateSize(data) > actualMaxSize;
  }

  /// Check if image is small enough for inline preview
  static bool canShowImageInline(int imageSize, {int? threshold}) {
    final actualThreshold = threshold ?? defaultImagePreviewThreshold;
    return imageSize <= actualThreshold;
  }

  /// Get data size info message
  static String getSizeInfo(dynamic data) {
    final size = calculateSize(data);
    return 'Size: ${formatBytes(size)}';
  }

  /// Get truncation message
  static String getTruncationMessage(dynamic data, {int? threshold}) {
    final actualThreshold = threshold ?? defaultTruncateThreshold;
    final size = calculateSize(data);
    return 'Data truncated (${formatBytes(size)} > ${formatBytes(actualThreshold)}). Tap to view full content.';
  }
}

