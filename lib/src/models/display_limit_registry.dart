import 'package:talker_dio_logger_plus/src/models/display_limit.dart';

import 'http_body_type.dart';

/// Registry for display limits per HTTP content type.
///
/// Maps each content type (JSON, image, text, HTML, XML, unknown) to its
/// display limit configuration. Provides sensible defaults and allows overrides.
///
/// The internal map is unmodifiable — the registry is effectively immutable after
/// construction; use [copyWith] to create updated versions.
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
///     HttpBodyType.json: DisplayLimit(maxBytes: 500 * 1024),
///     HttpBodyType.image: DisplayLimit(maxBytes: 2 * 1024 * 1024),
///   },
/// );
///
/// // Get limit for a type
/// final jsonLimit = registry.get(HttpBodyType.json);
/// ```
final class DisplayLimitRegistry {
  final Map<HttpBodyType, DisplayLimit> _limits;

  /// Canonical default registry. Created once and never mutated.
  static final DisplayLimitRegistry defaults = DisplayLimitRegistry();

  /// Create registry with optional per-type overrides.
  ///
  /// The resulting registry is immutable; the supplied [overrides] map is
  /// copied into an unmodifiable internal map.
  DisplayLimitRegistry({Map<HttpBodyType, DisplayLimit>? overrides})
    : _limits = Map.unmodifiable({
        HttpBodyType.json: DisplayLimit(),
        HttpBodyType.image: DisplayLimit(
          maxBytes: 5 * 1024, // 5 KB inline image cap
        ),
        HttpBodyType.text: DisplayLimit(),
        HttpBodyType.html: DisplayLimit(),
        HttpBodyType.xml: DisplayLimit(),
        HttpBodyType.unknown: DisplayLimit(),
        ...?overrides,
      });

  /// Get display limit for a content type.
  ///
  /// Returns the configured limit for this type, or the 'unknown' limit
  /// if this type is not explicitly configured.
  DisplayLimit get(HttpBodyType type) =>
      _limits[type] ?? _limits[HttpBodyType.unknown]!;

  /// Create a copy with selective limit overrides.
  ///
  /// Useful for adjusting limits without modifying the original.
  DisplayLimitRegistry copyWith({Map<HttpBodyType, DisplayLimit>? overrides}) {
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
