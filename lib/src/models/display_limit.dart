/// Display limit configuration for response types.
///
/// Provides unified control over how responses are displayed based on their type.
///
/// Fields:
/// - [maxBytes]: Maximum bytes to show inline before truncation
/// - [maxLines]: Maximum lines to display (for text/json/xml)
/// - [enablePreview]: Whether to show inline preview (for image/html)
///
/// This is used by [DisplayLimitRegistry] to map response types to display rules.
class DisplayLimit {
  final int maxBytes;
  final int maxLines;
  final bool enablePreview;

  static const recommendedMaxBytes = 1024 * 1024;
  static const recommendedMaxLines = 20;

  static const clampMinBytes = 1024;
  static const clampMaxLines = 1000;
  static const clampMaxBytes = recommendedMaxBytes * 100;

  /// Create a display limit with validated values.
  ///
  /// All byte values are clamped to safe ranges (1KB - 100MB).
  /// Line counts are clamped to 1-1000 range.
  factory DisplayLimit({
    int maxBytes = recommendedMaxBytes,
    int maxLines = recommendedMaxLines,
    bool enablePreview = true,
  }) {
    return DisplayLimit._internal(
      maxBytes.clamp(clampMinBytes, clampMaxBytes),
      maxLines.clamp(1, clampMaxLines),
      enablePreview,
    );
  }

  const DisplayLimit._internal(
    this.maxBytes,
    this.maxLines,
    this.enablePreview,
  );

  /// Create a copy with selective field updates.
  DisplayLimit copyWith({int? maxBytes, int? maxLines, bool? enablePreview}) {
    return DisplayLimit(
      maxBytes: maxBytes ?? this.maxBytes,
      maxLines: maxLines ?? this.maxLines,
      enablePreview: enablePreview ?? this.enablePreview,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayLimit &&
          runtimeType == other.runtimeType &&
          maxBytes == other.maxBytes &&
          maxLines == other.maxLines &&
          enablePreview == other.enablePreview;

  @override
  int get hashCode => Object.hash(maxBytes, maxLines, enablePreview);

  @override
  String toString() =>
      'DisplayLimit(maxBytes: $maxBytes, maxLines: $maxLines, enablePreview: $enablePreview)';
}
