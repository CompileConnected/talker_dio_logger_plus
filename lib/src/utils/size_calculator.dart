import 'dart:convert';

/// Size calculation and formatting utilities
class SizeCalculator {
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
}
