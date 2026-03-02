import 'dart:convert';

import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';

/// Utility class for truncating large data
class DataTruncator {
  /// Truncate data if it exceeds threshold.
  /// Returns null if truncation is not needed.
  static TruncationResult? truncate(
    dynamic data, {
    required int threshold,
    int? maxLines,
  }) {
    final size = SizeCalculator.calculateSize(data);

    if (size <= threshold) {
      return null;
    }

    // Truncate based on data type
    if (data is String) {
      return _truncateString(data, threshold, size);
    }

    if (data is Map) {
      return _truncateMap(data, threshold, size, maxLines);
    }

    if (data is List) {
      return _truncateList(data, threshold, size, maxLines);
    }

    // Default: convert to string and truncate
    return _truncateString(data.toString(), threshold, size);
  }

  /// Truncate string data
  static TruncationResult _truncateString(
    String data,
    int threshold,
    int originalSize,
  ) {
    // Calculate character count (approximate based on UTF-8 encoding)
    final charLimit = threshold;
    if (data.length <= charLimit) {
      return TruncationResult(
        data: data,
        originalSize: originalSize,
        truncatedSize: originalSize,
      );
    }

    final truncated = data.substring(0, charLimit);
    return TruncationResult(
      data:
          '$truncated\n\n... [TRUNCATED - ${SizeCalculator.formatBytes(originalSize)} total]',
      originalSize: originalSize,
      truncatedSize: SizeCalculator.calculateSize(truncated),
    );
  }

  /// Truncate Map data by limiting depth and keys
  static TruncationResult _truncateMap(
    Map data,
    int threshold,
    int originalSize,
    int? maxLines,
  ) {
    final effectiveMaxLines = maxLines ?? 50;
    final truncated = <String, dynamic>{};
    var lineCount = 0;

    for (final entry in data.entries) {
      if (lineCount >= effectiveMaxLines) {
        truncated['... truncated'] = '${data.length - lineCount} more entries';
        break;
      }

      final key = entry.key.toString();
      final value = entry.value;

      if (value is Map && value.length > 5) {
        truncated[key] = _simplifyMap(value, 5);
        lineCount += 5;
      } else if (value is List && value.length > 5) {
        truncated[key] = _simplifyList(value, 5);
        lineCount += 5;
      } else if (value is String && value.length > 200) {
        truncated[key] = '${value.substring(0, 200)}... [truncated]';
        lineCount++;
      } else {
        truncated[key] = value;
        lineCount++;
      }
    }

    return TruncationResult(
      data: truncated,
      originalSize: originalSize,
      truncatedSize: SizeCalculator.calculateSize(truncated),
    );
  }

  /// Truncate List data by limiting items
  static TruncationResult _truncateList(
    List data,
    int threshold,
    int originalSize,
    int? maxLines,
  ) {
    final effectiveMaxLines = maxLines ?? 50;
    final truncated = <dynamic>[];
    var lineCount = 0;

    for (final item in data) {
      if (lineCount >= effectiveMaxLines) {
        truncated.add(
          '... and ${data.length - lineCount} more items [truncated]',
        );
        break;
      }

      if (item is Map && item.length > 5) {
        truncated.add(_simplifyMap(item, 5));
        lineCount += 5;
      } else if (item is List && item.length > 5) {
        truncated.add(_simplifyList(item, 5));
        lineCount += 5;
      } else if (item is String && item.length > 200) {
        truncated.add('${item.substring(0, 200)}... [truncated]');
        lineCount++;
      } else {
        truncated.add(item);
        lineCount++;
      }
    }

    return TruncationResult(
      data: truncated,
      originalSize: originalSize,
      truncatedSize: SizeCalculator.calculateSize(truncated),
    );
  }

  /// Simplify a map by keeping only first n entries
  static Map<String, dynamic> _simplifyMap(Map map, int maxEntries) {
    final result = <String, dynamic>{};
    var count = 0;
    for (final entry in map.entries) {
      if (count >= maxEntries) {
        result['...'] = '${map.length - count} more entries';
        break;
      }
      result[entry.key.toString()] = _simplifyValue(entry.value);
      count++;
    }
    return result;
  }

  /// Simplify a list by keeping only first n items
  static List _simplifyList(List list, int maxItems) {
    final result = <dynamic>[];
    for (var i = 0; i < list.length && i < maxItems; i++) {
      result.add(_simplifyValue(list[i]));
    }
    if (list.length > maxItems) {
      result.add('... ${list.length - maxItems} more items');
    }
    return result;
  }

  /// Simplify a value for display
  static dynamic _simplifyValue(dynamic value) {
    if (value is String && value.length > 100) {
      return '${value.substring(0, 100)}...';
    }
    if (value is Map) return '{...}';
    if (value is List) return '[${value.length} items]';
    return value;
  }

  /// Convert data to formatted JSON string
  static String toJsonString(dynamic data, {int indent = 2}) {
    try {
      return JsonEncoder.withIndent(' ' * indent).convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

/// Result of truncation operation
class TruncationResult {
  const TruncationResult({
    required this.data,
    required this.originalSize,
    required this.truncatedSize,
  });

  final dynamic data;
  final int originalSize;
  final int truncatedSize;

  String get sizeInfo =>
      '${SizeCalculator.formatBytes(truncatedSize)} / ${SizeCalculator.formatBytes(originalSize)}';
}
