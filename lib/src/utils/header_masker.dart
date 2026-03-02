import 'package:talker_dio_logger_plus/src/advanced_dio_logger_settings.dart';

const _hiddenValue = '*****';

/// Utility for masking sensitive headers in HTTP logs.
///
/// Handles:
/// - Hiding headers listed in [AdvancedDioLoggerSettings.hiddenHeaders]
/// - Special handling for authorization-type headers (Bearer token masking)
class HeaderMasker {
  /// Mask sensitive headers in a map (modifies in-place).
  ///
  /// Replaces values of headers in [settings.hiddenHeaders] with masked values.
  /// Also handles authorization headers specially when [settings.hideAuthorizationValue] is true.
  static void mask(
    Map<dynamic, dynamic> headers,
    AdvancedDioLoggerSettings settings,
  ) {
    final lowerCaseHeaders = <String, String>{};
    headers.forEach((key, value) {
      lowerCaseHeaders[key.toLowerCase()] = key;
    });

    // Mask hidden headers
    for (final hiddenHeader in settings.hiddenHeaders) {
      final lowerCaseHiddenHeader = hiddenHeader.toLowerCase();
      if (lowerCaseHeaders.containsKey(lowerCaseHiddenHeader)) {
        final originalHeader = lowerCaseHeaders[lowerCaseHiddenHeader]!;
        headers[originalHeader] = _hiddenValue;
      }
    }

    // Special handling for authorization headers
    if (settings.hideAuthorizationValue) {
      const authKeys = ['authorization', 'x-auth-token'];
      for (final authKey in authKeys) {
        if (lowerCaseHeaders.containsKey(authKey)) {
          final originalKey = lowerCaseHeaders[authKey]!;
          final value = headers[originalKey]?.toString() ?? '';
          if (value.toLowerCase().startsWith('bearer ')) {
            headers[originalKey] = 'Bearer $_hiddenValue';
          } else {
            headers[originalKey] = _hiddenValue;
          }
        }
      }
    }
  }
}
