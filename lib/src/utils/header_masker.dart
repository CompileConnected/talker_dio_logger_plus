import 'package:talker_dio_logger_plus/src/advanced_dio_logger_settings.dart';

const _hiddenValue = '*****';

/// Utility for masking sensitive headers in HTTP logs.
///
/// Handles:
/// - Hiding headers listed in [hiddenHeaders]
/// - Special handling for authorization-type headers (Bearer token masking)
class HeaderMasker {
  /// Mask sensitive headers in a map (modifies in-place).
  ///
  /// [hiddenHeaders] — header names whose values are fully replaced with `*****`.
  /// [hideAuthorizationValue] — when true, `authorization` and `x-auth-token`
  /// headers are masked (Bearer tokens show `Bearer *****`).
  static void mask(
    Map<dynamic, dynamic> headers, {
    required Set<String> hiddenHeaders,
    required bool hideAuthorizationValue,
  }) {
    final lowerCaseHeaders = <String, String>{};
    headers.forEach((key, value) {
      lowerCaseHeaders[key.toLowerCase()] = key as String;
    });

    // Mask explicitly listed hidden headers
    for (final hiddenHeader in hiddenHeaders) {
      final lower = hiddenHeader.toLowerCase();
      if (lowerCaseHeaders.containsKey(lower)) {
        headers[lowerCaseHeaders[lower]!] = _hiddenValue;
      }
    }

    // Special handling for authorization headers
    if (hideAuthorizationValue) {
      const authKeys = ['authorization', 'x-auth-token'];
      for (final authKey in authKeys) {
        if (lowerCaseHeaders.containsKey(authKey)) {
          final originalKey = lowerCaseHeaders[authKey]!;
          final value = headers[originalKey]?.toString() ?? '';
          headers[originalKey] =
              value.toLowerCase().startsWith('bearer ')
                  ? 'Bearer $_hiddenValue'
                  : _hiddenValue;
        }
      }
    }
  }

  /// Convenience wrapper that reads masking config from [AdvancedDioLoggerSettings].
  static void maskFromSettings(
    Map<dynamic, dynamic> headers,
    AdvancedDioLoggerSettings settings,
  ) {
    mask(
      headers,
      hiddenHeaders: settings.hiddenHeaders,
      hideAuthorizationValue: settings.hideAuthorizationValue,
    );
  }
}
