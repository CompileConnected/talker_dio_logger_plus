import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:talker_dio_logger_plus/src/utils/header_masker.dart';

/// Generates cURL commands from Dio requests
class CurlGenerator {
  /// Generate cURL command from RequestOptions
  static String generate(
    RequestOptions options, {
    Set<String> hiddenHeaders = const {},
    bool hideAuthorizationValue = false,
  }) {
    final buffer = StringBuffer();
    buffer.write('curl');

    // Method
    if (options.method.toUpperCase() != 'GET') {
      buffer.write(' -X ${options.method.toUpperCase()}');
    }

    // URL
    buffer.write(" '${options.uri}'");

    // Headers
    final headers = Map<String, dynamic>.from(options.headers);
    _processHeaders(headers, hiddenHeaders, hideAuthorizationValue);

    for (final entry in headers.entries) {
      final value = entry.value;
      if (value != null) {
        buffer.write(" \\\n  -H '${entry.key}: $value'");
      }
    }

    // Data/Body
    final data = options.data;
    if (data != null) {
      final bodyString = _formatBody(data, options.contentType);
      if (bodyString != null && bodyString.isNotEmpty) {
        // Escape single quotes in the body
        final escapedBody = bodyString.replaceAll("'", "'\\''");
        buffer.write(" \\\n  -d '$escapedBody'");
      }
    }

    return buffer.toString();
  }

  /// Generate cURL command with full options (not hidden)
  static String generateFull(RequestOptions options) {
    return generate(options, hiddenHeaders: {}, hideAuthorizationValue: false);
  }

  /// Generate cURL command with hidden sensitive data
  static String generateSafe(
    RequestOptions options, {
    Set<String> hiddenHeaders = const {'authorization', 'x-api-key', 'api-key'},
    bool hideAuthorizationValue = true,
  }) {
    return generate(
      options,
      hiddenHeaders: hiddenHeaders,
      hideAuthorizationValue: hideAuthorizationValue,
    );
  }

  /// Process headers to hide sensitive values.
  ///
  /// Delegates to [HeaderMasker.mask] with the raw params — no need to
  /// construct a full [AdvancedDioLoggerSettings] object.
  static void _processHeaders(
    Map<String, dynamic> headers,
    Set<String> hiddenHeaders,
    bool hideAuthorizationValue,
  ) {
    HeaderMasker.mask(
      headers,
      hiddenHeaders: hiddenHeaders,
      hideAuthorizationValue: hideAuthorizationValue,
    );
  }

  /// Format request body for cURL
  static String? _formatBody(dynamic data, String? contentType) {
    if (data == null) return null;

    if (data is String) {
      return data;
    }

    if (data is Map || data is List) {
      try {
        return const JsonEncoder().convert(data);
      } catch (_) {
        return data.toString();
      }
    }

    if (data is FormData) {
      // For FormData, we'll convert to a simpler representation
      final parts = <String>[];
      for (final field in data.fields) {
        parts.add('${field.key}=${Uri.encodeQueryComponent(field.value)}');
      }
      for (final file in data.files) {
        final fileLength = file.value.length;
        final sizeInfo = '$fileLength bytes';
        parts.add(
          '${file.key}=@${file.value.filename ?? "file"} (binary, $sizeInfo)',
        );
      }
      return parts.join('&');
    }

    return data.toString();
  }
}
