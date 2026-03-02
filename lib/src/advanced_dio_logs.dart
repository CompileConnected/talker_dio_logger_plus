import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:talker_dio_logger_plus/src/models/content_type_detector.dart';
import 'package:talker_dio_logger_plus/src/models/curl_generator.dart';
import 'package:talker_dio_logger_plus/src/models/http_log_data.dart';
import 'package:talker_dio_logger_plus/src/utils/data_truncator.dart';
import 'package:talker_dio_logger_plus/src/utils/header_masker.dart';
import 'package:talker_dio_logger_plus/src/utils/size_calculator.dart';
import 'package:talker_dio_logger_plus/src/utils/talker_compat.dart';

import '../talker_dio_logger_plus.dart';

const _encoder = JsonEncoder.withIndent('  ');

/// Type of HTTP log
enum AdvancedDioLogType { request, response, error }

/// Advanced HTTP Log that handles requests, responses, and errors in a single class.
class AdvancedDioLog extends TalkerLog {
  AdvancedDioLog(
    super.message, {
    required this.type,
    required this.settings,
    required this.httpLogData,
  });

  final AdvancedDioLogType type;
  final AdvancedDioLoggerSettings settings;
  final HttpLogData httpLogData;

  @override
  AnsiPen get pen {
    return switch (type) {
      AdvancedDioLogType.request =>
        settings.requestPen ?? TalkerHttpPens.request,
      AdvancedDioLogType.response =>
        settings.responsePen ?? TalkerHttpPens.response,
      AdvancedDioLogType.error => settings.errorPen ?? TalkerHttpPens.error,
    };
  }

  @override
  String get key {
    return switch (type) {
      AdvancedDioLogType.request => TalkerHttpKeys.httpRequest,
      AdvancedDioLogType.response => TalkerHttpKeys.httpResponse,
      AdvancedDioLogType.error => TalkerHttpKeys.httpError,
    };
  }

  @override
  LogLevel get logLevel {
    return type == AdvancedDioLogType.error
        ? LogLevel.error
        : settings.logLevel;
  }

  /// Get cURL command with hidden sensitive values
  String? get curlCommandSafe {
    final options = httpLogData.requestOptions;
    if (options == null) return null;
    return CurlGenerator.generateSafe(
      options,
      hiddenHeaders: settings.hiddenHeaders,
      hideAuthorizationValue: settings.hideAuthorizationValue,
    );
  }

  /// Get full cURL command (with all values visible)
  String? get curlCommandFull {
    final options = httpLogData.requestOptions;
    if (options == null) return null;
    return CurlGenerator.generateFull(options);
  }

  // Cache the generated text message — data is immutable after construction
  // so there is no risk of stale content, and we avoid re-encoding large
  // response bodies (potentially MBs of JSON) on every Talker history render.
  String? _cachedTextMessage;

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) {
    if (_cachedTextMessage != null) return _cachedTextMessage!;
    final buffer = StringBuffer('[$title] [${httpLogData.method}] $message');

    switch (type) {
      case AdvancedDioLogType.request:
        _appendRequestDetails(buffer);
        break;
      case AdvancedDioLogType.response:
        _appendResponseDetails(buffer);
        break;
      case AdvancedDioLogType.error:
        _appendErrorDetails(buffer);
        break;
    }

    _appendRequestHeaders(buffer);
    _appendRequestExtra(buffer);

    _cachedTextMessage = buffer.toString();
    return _cachedTextMessage!;
  }

  void _appendRequestDetails(StringBuffer buffer) {
    if (settings.printRequestData) {
      _appendData(
        buffer,
        label: 'Data',
        data: httpLogData.requestBody,
        contentType: HttpContentType.unknown,
      );
    }
  }

  void _appendResponseDetails(StringBuffer buffer) {
    buffer.write('\nStatus: ${httpLogData.statusCode}');

    if (settings.printResponseTime && httpLogData.responseTime != null) {
      buffer.write('\nTime: ${httpLogData.responseTime} ms');
    }

    if (settings.printResponseMessage && httpLogData.statusMessage != null) {
      buffer.write('\nMessage: ${httpLogData.statusMessage}');
    }

    buffer.write('\nContent-Type: ${httpLogData.contentType.name}');
    if (httpLogData.contentLength != null) {
      buffer.write(
        '\nSize: ${SizeCalculator.formatBytes(httpLogData.contentLength!)}',
      );
    }

    if (settings.printResponseData) {
      _appendData(
        buffer,
        label: 'Data',
        data: httpLogData.responseBody,
        contentType: httpLogData.contentType,
        response: httpLogData.response,
        alreadyTruncated: true,
      );
    }

    if (settings.printResponseHeaders) {
      _appendMap(buffer, 'Headers', httpLogData.responseHeaders);
    }
  }

  void _appendErrorDetails(StringBuffer buffer) {
    if (httpLogData.statusCode != null) {
      buffer.write('\nStatus: ${httpLogData.statusCode}');
    }

    if (settings.printResponseTime && httpLogData.responseTime != null) {
      buffer.write('\nTime: ${httpLogData.responseTime} ms');
    }

    if (settings.printErrorMessage && httpLogData.error != null) {
      buffer.write('\nMessage: ${httpLogData.error}');
    }

    if (httpLogData.dioException != null) {
      buffer.write('\nError Type: ${httpLogData.dioException!.type.name}');
    }

    if (settings.printErrorData) {
      _appendData(
        buffer,
        label: 'Data',
        data: httpLogData.responseBody,
        contentType: httpLogData.contentType,
        alreadyTruncated: true,
      );
    }

    if (settings.printErrorHeaders) {
      _appendMap(buffer, 'Headers', httpLogData.responseHeaders);
    }
  }

  void _appendData(
    StringBuffer buffer, {
    required String label,
    required dynamic data,
    required HttpContentType contentType,
    Response? response,

    /// When true the caller guarantees [data] has already been truncated to
    /// [DisplayLimit.maxBytes] at storage time, so we skip a second
    /// [DataTruncator] pass (and the expensive [SizeCalculator] call it needs).
    bool alreadyTruncated = false,
  }) {
    final limit = settings.getDisplayLimit(contentType);
    if (!limit.enablePreview) return;

    // Image: body is null (stored in imageData), show size hint.
    if (contentType == HttpContentType.image) {
      buffer.write(
        '\n[$label: Image Data - ${SizeCalculator.formatBytes(httpLogData.approximateResponseSize)}]',
      );
      if (httpLogData.approximateResponseSize > limit.maxBytes) {
        buffer.write('\n[Too large for preview - tap to view]');
      }
      return;
    }

    // HTML: body is null (rendered by WebView), show hint.
    if (contentType == HttpContentType.html) {
      buffer.write('\n[$label: HTML Content - tap to preview]');
      return;
    }

    // Binary/unknown: body is a sentinel placeholder string or null.
    if (data == null) return;

    // For already-truncated data (response/error body) skip the second
    // DataTruncator pass — the stored copy is already within maxBytes.
    TruncationResult? truncationResult;
    final dynamic displayData;
    if (alreadyTruncated) {
      displayData = data;
    } else {
      truncationResult = DataTruncator.truncate(
        data,
        threshold: limit.maxBytes,
        maxLines: limit.maxLines,
      );
      displayData = truncationResult?.data ?? data;
    }

    String formatted;
    if (displayData is FormData) {
      formatted = _formatFormData(displayData);
    } else if (response != null && settings.responseDataConverter != null) {
      formatted = settings.responseDataConverter!(response);
    } else {
      try {
        formatted = _encoder.convert(displayData);
      } catch (_) {
        formatted = displayData.toString();
      }
    }

    buffer.write('\n$label: $formatted');
    if (truncationResult != null) {
      buffer.write(
        '\n[Truncated: ${SizeCalculator.formatBytes(truncationResult.originalSize)} - tap for full content]',
      );
    }
  }

  void _appendRequestHeaders(StringBuffer buffer) {
    if (!settings.printRequestHeaders) return;
    final headers = httpLogData.requestHeaders;
    if (headers == null || headers.isEmpty) return;

    final label =
        type == AdvancedDioLogType.request ? 'Headers' : 'Request Headers';
    _appendMap(buffer, label, headers);
  }

  void _appendRequestExtra(StringBuffer buffer) {
    if (!settings.printRequestExtra) return;
    final options = httpLogData.requestOptions;
    if (options == null || options.extra.isEmpty) return;

    final extra = Map<String, dynamic>.from(options.extra)
      ..remove('_talker_dio_logger_ts_');

    if (extra.isEmpty) return;

    final label =
        type == AdvancedDioLogType.request ? 'Extra' : 'Request Extra';
    _appendMap(buffer, label, extra);
  }

  void _appendMap(
    StringBuffer buffer,
    String label,
    Map<dynamic, dynamic>? map,
  ) {
    if (map == null || map.isEmpty) return;
    try {
      buffer.write('\n$label: ${_encoder.convert(map)}');
    } catch (_) {
      // Ignore conversion errors in logs
    }
  }

  String _formatFormData(FormData data) => _encoder.convert({
    for (final field in data.fields) field.key: field.value,
    for (final file in data.files)
      file.key: {
        'filename': file.value.filename,
        'contentType': file.value.contentType.toString(),
        'bytes': file.value.length,
      },
  });
}

/// Get response time from request options
int? _getResponseTime(RequestOptions options) {
  final triggerTime = options.extra['_talker_dio_logger_ts_'];
  return triggerTime is int
      ? DateTime.now().millisecondsSinceEpoch - triggerTime
      : null;
}

/// Create base HttpLogData with common fields
HttpLogData _createBaseLogData(
  RequestOptions options,
  AdvancedDioLoggerSettings settings,
) {
  final headers = Map<String, dynamic>.from(options.headers);
  HeaderMasker.maskFromSettings(headers, settings);

  return HttpLogData(
    method: options.method,
    uri: options.uri,
    timestamp: DateTime.now(),
    requestHeaders: headers,
    requestBody: options.data,
    requestQueryParams:
        options.uri.queryParameters.isNotEmpty
            ? options.uri.queryParameters
            : null,
    requestOptions: options,
  );
}

/// Create HttpLogData from request options
HttpLogData createRequestLogData(
  RequestOptions options,
  AdvancedDioLoggerSettings settings,
) => _createBaseLogData(options, settings);

/// Create HttpLogData from response
HttpLogData createResponseLogData(
  Response response,
  AdvancedDioLoggerSettings settings,
) {
  final contentType = ContentTypeDetector.detectFromResponse(response);
  final contentLength = _getContentLength(response);
  final prepared = _prepareResponseBody(response.data, contentType, settings);

  return _createBaseLogData(response.requestOptions, settings).copyWith(
    responseHeaders: response.headers.map,
    responseBody: prepared.responseBody,
    htmlContent: prepared.htmlContent,
    statusCode: response.statusCode,
    statusMessage: response.statusMessage,
    responseTime: _getResponseTime(response.requestOptions),
    contentType: contentType,
    contentLength: contentLength,
    imageData:
        (contentType == HttpContentType.image && response.data is List<int>)
            ? Uint8List.fromList(response.data as List<int>)
            : null,
    response: response,
  );
}

/// Create HttpLogData from error
HttpLogData createErrorLogData(
  DioException error,
  AdvancedDioLoggerSettings settings,
) {
  final response = error.response;
  HttpContentType contentType = HttpContentType.unknown;
  int? contentLength;
  Uint8List? imageData;
  _PreparedBody prepared = (responseBody: null, htmlContent: null);

  if (response != null) {
    contentType = ContentTypeDetector.detectFromResponse(response);
    contentLength = _getContentLength(response);
    prepared = _prepareResponseBody(response.data, contentType, settings);

    if (contentType == HttpContentType.image && response.data is List<int>) {
      imageData = Uint8List.fromList(response.data as List<int>);
    }
  }

  return _createBaseLogData(error.requestOptions, settings).copyWith(
    responseHeaders: response?.headers.map,
    responseBody: prepared.responseBody,
    htmlContent: prepared.htmlContent,
    statusCode: response?.statusCode,
    statusMessage: response?.statusMessage,
    responseTime: _getResponseTime(error.requestOptions),
    error: error.message,
    contentType: contentType,
    contentLength: contentLength,
    imageData: imageData,
    response: response,
    dioException: error,
  );
}

/// Get content length from response
int? _getContentLength(Response response) {
  final header = response.headers.value('content-length');
  return header != null ? int.tryParse(header) : null;
}

/// Result of [_prepareResponseBody] — holds what should be stored in each
/// dedicated field of [HttpLogData].
typedef _PreparedBody = ({dynamic responseBody, String? htmlContent});

/// Prepare the response body for storage in [HttpLogData] at intercept time.
///
/// ### Why this matters for memory
/// Dio may return a 20 MB+ response body (a large `Map` or `String`). Without
/// this step, every `HttpLogData` in Talker's history would hold the full
/// payload indefinitely — potentially multiplied by the number of retained log
/// entries. By capping the stored copy here we ensure:
///
/// - `HttpLogData.responseBody` is already at most `DisplayLimit.maxBytes` in
///   size, so both the console formatter (`generateTextMessage`) and the UI
///   preview work on a small, already-truncated object.
/// - `generateTextMessage()` no longer needs to re-encode the full body on
///   every call — the cached string is built from the truncated data.
///
/// ### How each content type is handled
/// - **Image** — raw bytes are kept in `imageData` (Uint8List); `responseBody`
///   is set to null to avoid a duplicate copy.
/// - **HTML** — the raw string is stored in `htmlContent` (capped to
///   `DisplayLimit.maxBytes`) so [WebViewPreview] can render it; `responseBody`
///   is null.
/// - **Binary / unknown** — replaced with a small human-readable sentinel
///   string (e.g. `"[Binary data — 4.20 MB]"`) in `responseBody`.
/// - **Text-based (json, xml, text, file)** — truncated via [DataTruncator]
///   to `DisplayLimit.maxBytes` / `maxLines` and stored in `responseBody`.
_PreparedBody _prepareResponseBody(
  dynamic data,
  HttpContentType contentType,
  AdvancedDioLoggerSettings settings,
) {
  if (data == null) return (responseBody: null, htmlContent: null);

  // Images are stored separately as imageData (Uint8List); no duplicate copy.
  if (contentType == HttpContentType.image) {
    return (responseBody: null, htmlContent: null);
  }

  // HTML is rendered by WebView — store in htmlContent, not responseBody,
  // so the two in-memory copies don't coexist.
  if (contentType == HttpContentType.html) {
    final limit = settings.getDisplayLimit(contentType);
    final raw = data.toString();
    final html =
        raw.length > limit.maxBytes ? raw.substring(0, limit.maxBytes) : raw;
    return (responseBody: null, htmlContent: html);
  }

  // Binary / unknown: replace with a small placeholder sentinel.
  if (contentType == HttpContentType.binary ||
      contentType == HttpContentType.unknown) {
    final size = SizeCalculator.calculateSize(data);
    final sentinel =
        size > 0 ? '[Binary data — ${SizeCalculator.formatBytes(size)}]' : null;
    return (responseBody: sentinel, htmlContent: null);
  }

  // Text-based types (json, xml, text, file): truncate to DisplayLimit.
  final limit = settings.getDisplayLimit(contentType);
  final result = DataTruncator.truncate(
    data,
    threshold: limit.maxBytes,
    maxLines: limit.maxLines,
  );

  return (responseBody: result?.data ?? data, htmlContent: null);
}
