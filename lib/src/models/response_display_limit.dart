/// Display limit configuration for response types.
///
/// Provides unified control over how responses are displayed based on their type.
///
/// Fields:
/// - [minBytes]: Minimum bytes to display (rarely used, reserved for future)
/// - [maxBytes]: Maximum bytes to show inline before truncation
/// - [maxLines]: Maximum lines to display (for text/json/xml)
/// - [enablePreview]: Whether to show inline preview (for image/html)
///
/// This is used by [DisplayLimitRegistry] to map response types to display rules.
final class ResponseDisplayLimit {
  final int minBytes;
  final int maxBytes;
  final int maxLines;
  final bool enablePreview;

  static const recommendedMinBytes = 1024;
  static const recommendedMaxBytes = 1024 * 1024;
  static const recommendedMaxLines = 20;

  static const clampMinBytes = recommendedMinBytes;
  static const clampMaxLines = 1000;
  static const clampMaxBytes = recommendedMaxBytes * 100;

  /// Create a display limit with validated values.
  ///
  /// All byte values are clamped to safe ranges (1KB - 100MB).
  /// Line counts are clamped to 1-1000 range.
  factory ResponseDisplayLimit({
    int minBytes = recommendedMinBytes,
    int maxBytes = recommendedMaxBytes,
    int maxLines = recommendedMaxLines,
    bool enablePreview = true,
  }) {
    return ResponseDisplayLimit._internal(
      minBytes.clamp(clampMinBytes, clampMaxBytes),
      maxBytes.clamp(clampMinBytes, clampMaxBytes),
      maxLines.clamp(1, clampMaxLines),
      enablePreview,
    );
  }

  const ResponseDisplayLimit._internal(
    this.minBytes,
    this.maxBytes,
    this.maxLines,
    this.enablePreview,
  );

  /// Create a copy with selective field updates.
  ResponseDisplayLimit copyWith({
    int? minBytes,
    int? maxBytes,
    int? maxLines,
    bool? enablePreview,
  }) {
    return ResponseDisplayLimit(
      minBytes: minBytes ?? this.minBytes,
      maxBytes: maxBytes ?? this.maxBytes,
      maxLines: maxLines ?? this.maxLines,
      enablePreview: enablePreview ?? this.enablePreview,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResponseDisplayLimit &&
          runtimeType == other.runtimeType &&
          minBytes == other.minBytes &&
          maxBytes == other.maxBytes &&
          maxLines == other.maxLines &&
          enablePreview == other.enablePreview;

  @override
  int get hashCode => Object.hash(minBytes, maxBytes, maxLines, enablePreview);

  @override
  String toString() =>
      'ResponseDisplayLimit(minBytes: $minBytes, maxBytes: $maxBytes, maxLines: $maxLines, enablePreview: $enablePreview)';
}
