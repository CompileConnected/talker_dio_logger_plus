import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Utility class for HTTP status color determination.
class StatusColorUtil {
  StatusColorUtil._();

  /// Returns a color based on the HTTP status code.
  ///
  /// - 2xx: Green (success)
  /// - 3xx: Orange (redirect)
  /// - 4xx: Red (client error)
  /// - 5xx: Dark red (server error)
  /// - null/other: Grey
  static Color getStatusColor(int? statusCode, [TalkerScreenTheme? theme]) {
    final logColors = theme?.logColors;

    if (statusCode == null) return Colors.grey;

    if (statusCode >= 200 && statusCode < 300) {
      return logColors?['http-response'] ?? Colors.green;
    }
    if (statusCode >= 300 && statusCode < 400) {
      return Colors.orange;
    }
    if (statusCode >= 400 && statusCode < 500) {
      return logColors?['http-error'] ?? Colors.red;
    }
    if (statusCode >= 500) {
      return logColors?['http-error'] ?? Colors.red[900]!;
    }

    return Colors.grey;
  }

  /// Returns a color based on the log type (request, response, or error).
  ///
  /// - Request: Pink/Magenta
  /// - Response: Uses [getStatusColor] based on status code
  /// - Error: Red
  static Color getLogTypeColor({
    required bool isRequest,
    required bool isError,
    int? statusCode,
    TalkerScreenTheme? theme,
  }) {
    final logColors = theme?.logColors;

    if (isRequest) {
      return logColors?['http-request'] ?? const Color(0xFFF602C1);
    }

    if (isError) {
      return logColors?['http-error'] ?? Colors.red;
    }

    return getStatusColor(statusCode, theme);
  }
}
