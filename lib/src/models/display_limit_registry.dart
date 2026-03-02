import 'package:talker_dio_logger_plus/src/models/response_display_limit.dart';

import 'http_log_data.dart';

/// Registry for display limits per HTTP content type.
///
/// Maps each content type (JSON, image, text, HTML, XML, file, binary, unknown) to its
/// display limit configuration. Provides sensible defaults and allows overrides.
///
/// ## Usage
///
/// ```dart
/// // Use defaults
/// final registry = DisplayLimitRegistry();
///
/// // Override specific types
/// final customRegistry = DisplayLimitRegistry(
///   overrides: {
///     HttpContentType.json: ResponseDisplayLimit(maxBytes: 500 * 1024),
///     HttpContentType.image: ResponseDisplayLimit(
///       maxBytes: 2 * 1024 * 1024,
///     ),
///   },
/// );
///
/// // Get limit for a type
/// final jsonLimit = registry.get(HttpContentType.json);
/// ```
final class DisplayLimitRegistry {
  final Map<HttpContentType, ResponseDisplayLimit> _limits;

  /// Default registry with standard limits for all response types.
  static final DisplayLimitRegistry defaults = DisplayLimitRegistry();

  /// Create registry with optional per-type overrides.
  DisplayLimitRegistry({Map<HttpContentType, ResponseDisplayLimit>? overrides})
    : _limits = {
        HttpContentType.json: ResponseDisplayLimit(),
        HttpContentType.image: ResponseDisplayLimit(
          maxBytes: 5 * ResponseDisplayLimit.recommendedMinBytes, //500 KB
        ),
        HttpContentType.text: ResponseDisplayLimit(),
        HttpContentType.html: ResponseDisplayLimit(),
        HttpContentType.xml: ResponseDisplayLimit(),
        HttpContentType.file: ResponseDisplayLimit(),
        HttpContentType.binary: ResponseDisplayLimit(),
        HttpContentType.unknown: ResponseDisplayLimit(),
        ...?overrides,
      };

  /// Get display limit for a content type.
  ///
  /// Returns the configured limit for this type, or the 'unknown' limit
  /// if this type is not explicitly configured.
  ResponseDisplayLimit get(HttpContentType type) =>
      _limits[type] ?? _limits[HttpContentType.unknown]!;

  /// Create a copy with selective limit overrides.
  ///
  /// Useful for temporarily adjusting limits without modifying the original.
  DisplayLimitRegistry copyWith({
    Map<HttpContentType, ResponseDisplayLimit>? overrides,
  }) {
    return DisplayLimitRegistry(overrides: {..._limits, ...?overrides});
  }

  @override
  String toString() => 'DisplayLimitRegistry($_limits)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayLimitRegistry &&
          runtimeType == other.runtimeType &&
          _limits == other._limits;

  @override
  int get hashCode => _limits.hashCode;
}
