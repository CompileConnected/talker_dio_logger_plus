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

/// JSON encoder with 2-space indentation, shared across this file.
const _encoder = JsonEncoder.withIndent('  ');

/// The kind of HTTP log entry.
enum AdvancedDioLogType { request, response, error }

/// A single HTTP log entry displayed in the Talker console and UI.
///
/// Each instance is created by [AdvancedDioLogger] and carries all the
/// information needed to render the log (method, URL, headers, body, etc.).
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

  /// cURL command with sensitive header values masked.
  String? get curlCommandSafe {
    final options = httpLogData.requestOptions;
    if (options == null) return null;
    return CurlGenerator.generateSafe(
      options,
      hiddenHeaders: settings.hiddenHeaders,
      hideAuthorizationValue: settings.hideAuthorizationValue,
    );
  }

  /// cURL command with all values visible (for debugging).
  String? get curlCommandFull {
    final options = httpLogData.requestOptions;
    if (options == null) return null;
    return CurlGenerator.generateFull(options);
  }

  /// Cached result so we don't re-encode large bodies on every render.
  String? _cachedTextMessage;

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) {
    if (_cachedTextMessage != null) return _cachedTextMessage!;

    final buffer = StringBuffer('[$title] [${httpLogData.method}] $message');

    switch (type) {
      case AdvancedDioLogType.request:
        _writeRequestDetails(buffer);
        break;
      case AdvancedDioLogType.response:
        _writeResponseDetails(buffer);
        break;
      case AdvancedDioLogType.error:
        _writeErrorDetails(buffer);
        break;
    }

    _writeRequestHeaders(buffer);
    _writeRequestExtra(buffer);

    _cachedTextMessage = buffer.toString();
    return _cachedTextMessage!;
  }

  void _writeRequestDetails(StringBuffer buffer) {
    if (settings.printRequestData) {
      _writeBody(
        buffer,
        label: 'Data',
        data: httpLogData.requestBody,
        contentType: HttpBodyType.unknown,
      );
    }
  }

  void _writeResponseDetails(StringBuffer buffer) {
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
      _writeBody(
        buffer,
        label: 'Data',
        data: httpLogData.responseBody,
        contentType: httpLogData.contentType,
        response: httpLogData.response,
        alreadyTruncated: true,
      );
    }

    if (settings.printResponseHeaders) {
      _writeMap(buffer, 'Headers', httpLogData.responseHeaders);
    }
  }

  void _writeErrorDetails(StringBuffer buffer) {
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
      _writeBody(
        buffer,
        label: 'Data',
        data: httpLogData.responseBody,
        contentType: httpLogData.contentType,
        alreadyTruncated: true,
      );
    }

    if (settings.printErrorHeaders) {
      _writeMap(buffer, 'Headers', httpLogData.responseHeaders);
    }
  }

  /// Writes a body (request or response) into [buffer].
  ///
  /// [alreadyTruncated] means the data was already capped at storage time
  /// so we can skip the expensive truncation step.
  void _writeBody(
    StringBuffer buffer, {
    required String label,
    required dynamic data,
    required HttpBodyType contentType,
    Response? response,
    bool alreadyTruncated = false,
  }) {
    final limit = settings.getDisplayLimit(contentType);

    // Each content type has its own simple helper.
    if (contentType == HttpBodyType.image) {
      _writeImagePlaceholder(buffer, label, limit);
      return;
    }

    if (contentType == HttpBodyType.html) {
      buffer.write('\n[$label: HTML Content - tap to preview]');
      return;
    }

    if (data == null) return;

    if (data is FormData) {
      buffer.write('\n$label: ${_formatFormData(data)}');
      return;
    }

    // Text-based content (JSON, XML, plain text, etc.)
    _writeTextBody(
      buffer,
      label: label,
      data: data,
      response: response,
      alreadyTruncated: alreadyTruncated,
      limit: limit,
    );
  }

  /// Writes a size hint for image responses.
  void _writeImagePlaceholder(
    StringBuffer buffer,
    String label,
    DisplayLimit limit,
  ) {
    final size = httpLogData.approximateResponseSize;
    buffer.write(
      '\n[$label: Image Data - ${SizeCalculator.formatBytes(size)}]',
    );
    if (size > limit.maxBytes) {
      buffer.write('\n[Too large for preview - tap to view]');
    }
  }

  /// Writes text-based body data (JSON, XML, plain text).
  void _writeTextBody(
    StringBuffer buffer, {
    required String label,
    required dynamic data,
    required DisplayLimit limit,
    Response? response,
    bool alreadyTruncated = false,
  }) {
    // Optionally truncate data that hasn't been capped yet.
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

    // Use custom converter if provided; otherwise JSON-encode.
    String formatted;
    if (response != null && settings.responseDataConverter != null) {
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

  void _writeRequestHeaders(StringBuffer buffer) {
    if (!settings.printRequestHeaders) return;
    final headers = httpLogData.requestHeaders;
    if (headers == null || headers.isEmpty) return;

    final label =
        type == AdvancedDioLogType.request ? 'Headers' : 'Request Headers';
    _writeMap(buffer, label, headers);
  }

  void _writeRequestExtra(StringBuffer buffer) {
    if (!settings.printRequestExtra) return;
    final options = httpLogData.requestOptions;
    if (options == null || options.extra.isEmpty) return;

    final extra = Map<String, dynamic>.from(options.extra)
      ..remove('_talker_dio_logger_ts_');

    if (extra.isEmpty) return;

    final label =
        type == AdvancedDioLogType.request ? 'Extra' : 'Request Extra';
    _writeMap(buffer, label, extra);
  }

  void _writeMap(
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

/// Creates [HttpLogData] instances from Dio's request/response/error objects.
///
/// All methods are static so they can be called without instantiation.
/// This class groups the factory logic in one place for discoverability.
class HttpLogDataFactory {
  // Private constructor — this class is not meant to be instantiated.
  HttpLogDataFactory._();

  /// Build log data from a [RequestOptions] (outgoing request).
  static HttpLogData fromRequest(
    RequestOptions options,
    AdvancedDioLoggerSettings settings,
  ) {
    return _buildBase(options, settings);
  }

  /// Build log data from a successful [Response].
  static HttpLogData fromResponse(
    Response response,
    AdvancedDioLoggerSettings settings,
  ) {
    final contentType = ContentTypeDetector.detectFromResponse(response);
    final contentLength = _readContentLength(response);
    final body = _PreparedBody.fromData(response.data, contentType, settings);

    return _buildBase(response.requestOptions, settings).copyWith(
      responseHeaders: response.headers.map,
      responseBody: body.responseBody,
      htmlContent: body.htmlContent,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      responseTime: _calculateResponseTime(response.requestOptions),
      contentType: contentType,
      contentLength: contentLength,
      imageData: _extractImageBytes(response.data, contentType),
      response: response,
    );
  }

  /// Build log data from a [DioException].
  static HttpLogData fromError(
    DioException error,
    AdvancedDioLoggerSettings settings,
  ) {
    final response = error.response;

    // When there's no response (e.g. network error), most fields stay null.
    if (response == null) {
      return _buildBase(error.requestOptions, settings).copyWith(
        responseTime: _calculateResponseTime(error.requestOptions),
        error: error.message,
        dioException: error,
      );
    }

    final contentType = ContentTypeDetector.detectFromResponse(response);
    final contentLength = _readContentLength(response);
    final body = _PreparedBody.fromData(response.data, contentType, settings);

    return _buildBase(error.requestOptions, settings).copyWith(
      responseHeaders: response.headers.map,
      responseBody: body.responseBody,
      htmlContent: body.htmlContent,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      responseTime: _calculateResponseTime(error.requestOptions),
      error: error.message,
      contentType: contentType,
      contentLength: contentLength,
      imageData: _extractImageBytes(response.data, contentType),
      response: response,
      dioException: error,
    );
  }

  /// Shared logic for every log entry: masks headers, captures query params.
  static HttpLogData _buildBase(
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

  /// Reads the `content-length` header from a [Response].
  static int? _readContentLength(Response response) {
    final header = response.headers.value('content-length');
    return header != null ? int.tryParse(header) : null;
  }

  /// Calculates how many milliseconds elapsed since the request was sent.
  static int? _calculateResponseTime(RequestOptions options) {
    final startMs = options.extra['_talker_dio_logger_ts_'];
    if (startMs is! int) return null;
    return DateTime.now().millisecondsSinceEpoch - startMs;
  }

  /// Extracts raw image bytes when the response is an image.
  static Uint8List? _extractImageBytes(dynamic data, HttpBodyType type) {
    if (type == HttpBodyType.image && data is List<int>) {
      return Uint8List.fromList(data);
    }
    return null;
  }
}

/// Holds the processed response body ready for storage in [HttpLogData].
///
/// Only one of [responseBody] or [htmlContent] is set at a time:
/// - **JSON / XML / text**: stored in [responseBody] (truncated to fit).
/// - **HTML**: stored in [htmlContent] for WebView rendering.
/// - **Image**: both are null (raw bytes go into `HttpLogData.imageData`).
/// - **Binary**: [responseBody] contains a small placeholder string.
class _PreparedBody {
  const _PreparedBody({this.responseBody, this.htmlContent});

  /// The body to store in `HttpLogData.responseBody`.
  final dynamic responseBody;

  /// Raw HTML string to store in `HttpLogData.htmlContent`.
  final String? htmlContent;

  /// Pick the right preparation strategy based on [contentType].
  factory _PreparedBody.fromData(
    dynamic data,
    HttpBodyType contentType,
    AdvancedDioLoggerSettings settings,
  ) {
    if (data == null) return const _PreparedBody();

    return switch (contentType) {
      HttpBodyType.image => const _PreparedBody(),
      HttpBodyType.html => _prepareHtml(data, settings),
      HttpBodyType.unknown => _prepareBinary(data),
      _ => _prepareText(data, contentType, settings),
    };
  }

  /// HTML: cap to maxBytes, store in [htmlContent] for WebView.
  static _PreparedBody _prepareHtml(
    dynamic data,
    AdvancedDioLoggerSettings settings,
  ) {
    final limit = settings.getDisplayLimit(HttpBodyType.html);
    final raw = data.toString();
    final html =
        raw.length > limit.maxBytes ? raw.substring(0, limit.maxBytes) : raw;
    return _PreparedBody(htmlContent: html);
  }

  /// Binary / unknown: replace with a small human-readable placeholder.
  static _PreparedBody _prepareBinary(dynamic data) {
    final size = SizeCalculator.calculateSize(data);
    if (size <= 0) return const _PreparedBody();
    return _PreparedBody(
      responseBody: '[Binary data — ${SizeCalculator.formatBytes(size)}]',
    );
  }

  /// Text-based (JSON, XML, plain text, file): truncate to [DisplayLimit].
  static _PreparedBody _prepareText(
    dynamic data,
    HttpBodyType contentType,
    AdvancedDioLoggerSettings settings,
  ) {
    final limit = settings.getDisplayLimit(contentType);
    final result = DataTruncator.truncate(
      data,
      threshold: limit.maxBytes,
      maxLines: limit.maxLines,
    );
    return _PreparedBody(responseBody: result?.data ?? data);
  }
}
